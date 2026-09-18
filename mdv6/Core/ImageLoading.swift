// ImageLoading — R-16 image sources behind the trust boundary: `ImageDecoding` enforces the K-14 ceilings before ImageIO
// (R-41, E-28) for local, data-URI and remote bytes; `RemoteImageLoader` is the C-16 network contract (the only network
// path in the application, I-001..I-003; E-11 failures).
import Foundation
import AppKit
import ImageIO

/// R-16 / E-11 outcomes; every non-image case becomes a placeholder in the block (C-14).
public enum ImageLoadResult {
    case image(NSImage)
    /// R-16: remote loading is off — "Remote image blocked".
    case blocked
    /// R-16: a missing local image, naming the file.
    case notFound(name: String)
    /// E-11 / E-28: an explicit failure placeholder.
    case failed(reason: String)
}

public enum ImageDecoding {
    /// K-14 from the image properties: both axes ≤ 16,384, ≤ 64 megapixels, decoded bytes ≤ 256 MiB.
    public static func admits(width: Int, height: Int, bitsPerPixel: Int) -> Bool {
        ContentLimits.admitsImage(width: width, height: height, bytesPerPixel: max(1, (bitsPerPixel + 7) / 8))
    }

    /// R-41: the encoded-size ceiling, then the properties, then — and only then — the decode.
    public static func decode(data: Data) -> ImageLoadResult {
        guard ContentLimits.admits(data.count, kind: .encodedImage) else { return .failed(reason: ContentLimits.exceededMessage) }
        PipelineProbe.enter("image")                                  // ImageIO reads the header/properties from here on
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int else {
            return .failed(reason: "not an image")
        }
        let depth = props[kCGImagePropertyDepth] as? Int ?? 8
        let hasAlpha = props[kCGImagePropertyHasAlpha] as? Bool ?? true
        let bitsPerPixel = depth * (hasAlpha ? 4 : 3)
        guard admits(width: width, height: height, bitsPerPixel: max(bitsPerPixel, 32)) else { return .failed(reason: ContentLimits.exceededMessage) }
        PipelineProbe.enter("image-decode")                           // the pixel decode itself (K-14 dimension ceilings before it)
        guard let cg = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return .failed(reason: "could not decode image")
        }
        return .image(NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
    }

    /// R-16: a relative path resolves against the document's directory; a missing file is `.notFound(name:)`.
    public static func local(url: URL, base: URL?) -> ImageLoadResult {
        let path: String
        if url.isFileURL { path = url.path }
        else if let base { path = base.appendingPathComponent(url.path).standardizedFileURL.path }
        else { path = url.path }
        guard let data = FileManager.default.contents(atPath: path) else { return .notFound(name: url.lastPathComponent) }
        return decode(data: data)
    }

    /// R-16: `data:[<mediatype>][;base64],<data>`.
    public static func dataURI(_ url: URL) -> ImageLoadResult {
        let s = url.absoluteString
        guard s.hasPrefix("data:"), let comma = s.firstIndex(of: ",") else { return .failed(reason: "malformed data URI") }
        let meta = s[s.index(s.startIndex, offsetBy: 5)..<comma]
        let payload = String(s[s.index(after: comma)...])
        let data: Data?
        if meta.hasSuffix(";base64") { data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]) }
        else { data = payload.removingPercentEncoding.map { Data($0.utf8) } }
        guard let data, !data.isEmpty else { return .failed(reason: "malformed data URI") }
        return decode(data: data)
    }
}

/// C-16: an ephemeral, header-free, redirect-bounded, size-bounded, time-bounded `GET` — the application's only network path.
public final class RemoteImageLoader: NSObject, URLSessionDataDelegate {
    public static let maxRedirects = 5
    public static let maxBodyBytes = 32 * 1024 * 1024

    public let connectionTimeout: TimeInterval
    public let resourceTimeout: TimeInterval
    public let sessionConfiguration: URLSessionConfiguration
    private var session: URLSession!
    private let lock = NSLock()
    private var states: [Int: TaskState] = [:]          // by task identifier
    private var tasks: [Int: URLSessionDataTask] = [:]

    private final class TaskState {
        var redirects = 0
        var buffer = Data()
        var failure: String? = nil
        var continuation: CheckedContinuation<ImageLoadResult, Never>?
    }

    /// C-16: 15 s connection, 30 s resource; ephemeral session with no cache, cookie storage, credential storage or shared state.
    public init(connectionTimeout: TimeInterval = 15, resourceTimeout: TimeInterval = 30) {
        self.connectionTimeout = connectionTimeout
        self.resourceTimeout = resourceTimeout
        let c = URLSessionConfiguration.ephemeral
        c.urlCache = nil
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.urlCredentialStorage = nil
        c.httpAdditionalHeaders = nil
        c.timeoutIntervalForRequest = connectionTimeout
        c.timeoutIntervalForResource = resourceTimeout
        c.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        sessionConfiguration = c
        super.init()
        session = URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    /// Bytes currently held for in-flight or finished loads (0 after a failure: partial bytes are discarded).
    public var bytesRetained: Int { lock.lock(); defer { lock.unlock() }; return states.values.reduce(0) { $0 + $1.buffer.count } }

    /// C-16: one unauthenticated GET; every violation is `.failed` (E-11).
    public func load(_ url: URL) async -> ImageLoadResult {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return .failed(reason: "not an http(s) URL") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(nil, forHTTPHeaderField: "Cookie")
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        request.setValue(nil, forHTTPHeaderField: "Referer")
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let task = session.dataTask(with: request)
        return await withCheckedContinuation { continuation in
            let state = TaskState()
            state.continuation = continuation
            lock.lock(); states[task.taskIdentifier] = state; tasks[task.taskIdentifier] = task; lock.unlock()
            task.resume()
        }
    }

    /// R-16: turning the preference off cancels in-flight remote-image requests.
    public func cancelAll() {
        lock.lock(); let all = Array(tasks.values); lock.unlock()
        for t in all { t.cancel() }
    }

    private func state(for task: URLSessionTask) -> TaskState? { lock.lock(); defer { lock.unlock() }; return states[task.taskIdentifier] }

    private func fail(_ task: URLSessionTask, _ reason: String) {
        guard let s = state(for: task) else { return }
        if s.failure == nil { s.failure = reason }
        s.buffer = Data()
        task.cancel()
    }

    // MARK: URLSessionDataDelegate

    /// C-16: at most five redirects, only while every target stays http(s).
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let s = state(for: task) else { completionHandler(nil); return }
        s.redirects += 1
        let scheme = request.url?.scheme?.lowercased() ?? ""
        guard s.redirects <= RemoteImageLoader.maxRedirects, scheme == "http" || scheme == "https" else {
            s.failure = s.redirects > RemoteImageLoader.maxRedirects ? "too many redirects" : "redirect to a non-http URL"
            completionHandler(nil)
            return
        }
        var next = request
        next.setValue(nil, forHTTPHeaderField: "Cookie")
        next.setValue(nil, forHTTPHeaderField: "Authorization")
        next.setValue(nil, forHTTPHeaderField: "Referer")
        completionHandler(next)
    }

    /// C-16: a 2xx status and an `image/*` media type, else cancel.
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else { fail(dataTask, "not an HTTP response"); completionHandler(.cancel); return }
        guard (200..<300).contains(http.statusCode) else { fail(dataTask, "HTTP \(http.statusCode)"); completionHandler(.cancel); return }
        let type = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        guard type.hasPrefix("image/") else { fail(dataTask, "not an image media type"); completionHandler(.cancel); return }
        if http.expectedContentLength > Int64(RemoteImageLoader.maxBodyBytes) { fail(dataTask, "body exceeds limit"); completionHandler(.cancel); return }
        completionHandler(.allow)
    }

    /// C-16: streamed and cancelled as soon as the body exceeds 32 MiB; partial bytes discarded.
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let s = state(for: dataTask) else { return }
        s.buffer.append(data)
        if s.buffer.count > RemoteImageLoader.maxBodyBytes { fail(dataTask, "body exceeds limit") }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let s = states.removeValue(forKey: task.taskIdentifier)
        tasks.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        guard let s, let continuation = s.continuation else { return }
        s.continuation = nil
        if let failure = s.failure { continuation.resume(returning: .failed(reason: failure)); return }
        if let error { continuation.resume(returning: .failed(reason: error.localizedDescription)); return }
        if let http = task.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            continuation.resume(returning: .failed(reason: "HTTP \(http.statusCode)")); return
        }
        let data = s.buffer
        s.buffer = Data()
        continuation.resume(returning: ImageDecoding.decode(data: data))          // K-14 on the decoded image, in memory only
    }

    /// No response body is ever written to disk (C-16): caching is disabled at the session level, and this declines any cache write.
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse,
                           completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(nil)
    }
}
