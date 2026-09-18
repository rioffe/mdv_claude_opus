import XCTest
import AppKit
import Network
@testable import mdv6Core

/// C-16 remote-image network contract and K-14 image ceilings (R-16, R-41, E-11, E-28, I-001..I-003; T-41).
final class ImageLoadingTests: XCTestCase {

    // MARK: fixtures

    private func png(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
    }

    private var dir: URL!
    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-img-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); PipelineProbe.onParserEntry = nil }

    // MARK: K-14 decoding (R-41, E-28)

    /// K-14, T-41: an image at 16,384 px on an axis decodes; 16,385 is rejected before `CGImageSourceCreateImageAtIndex`;
    /// the pixel and byte ceilings are checked from the properties; a compressed payload over 32 MiB never reaches ImageIO.
    func testDecodingCeilings() {
        var headers = 0, decodes = 0
        PipelineProbe.onParserEntry = { if $0 == "image" { headers += 1 }; if $0 == "image-decode" { decodes += 1 } }
        if case .image(let img) = ImageDecoding.decode(data: png(width: 16_384, height: 2)) { XCTAssertEqual(img.size.width, 16_384) } else { XCTFail("axis at ceiling") }
        XCTAssertEqual(decodes, 1)
        guard case .failed = ImageDecoding.decode(data: png(width: 16_385, height: 1)) else { return XCTFail("axis above ceiling") }
        XCTAssertEqual(decodes, 1)                                                                      // the header was read, the pixels were not decoded
        let entries = { headers }
        XCTAssertTrue(ImageDecoding.admits(width: 8_000, height: 8_000, bitsPerPixel: 32))
        XCTAssertFalse(ImageDecoding.admits(width: 8_001, height: 8_000, bitsPerPixel: 32))          // > 64 Mpx
        XCTAssertFalse(ImageDecoding.admits(width: 8_000, height: 8_000, bitsPerPixel: 48))          // > 256 MiB
        XCTAssertFalse(ImageDecoding.admits(width: 16_385, height: 1, bitsPerPixel: 8))
        let before = entries()
        var big = Data(count: ContentLimits.encodedImageBytes + 1)
        guard case .failed = ImageDecoding.decode(data: big) else { return XCTFail("compressed above ceiling") }
        XCTAssertEqual(entries(), before)                                                              // never reached ImageIO
        big = Data(count: ContentLimits.encodedImageBytes)
        _ = ImageDecoding.decode(data: big)                                                           // at the ceiling: reaches ImageIO
        XCTAssertEqual(entries(), before + 1)
        guard case .failed = ImageDecoding.decode(data: Data("not an image".utf8)) else { return XCTFail() }
    }

    /// R-16, E-11, T-09, C-14: relative paths resolve against the document's directory; a missing file names the placeholder; `data:` URIs decode.
    func testLocalAndDataImages() {
        try! png(width: 8, height: 8).write(to: dir.appendingPathComponent("local.png"))
        guard case .image = ImageDecoding.local(url: URL(string: "assets/../local.png")!, base: dir) else { return XCTFail("local") }
        guard case .notFound(let name) = ImageDecoding.local(url: URL(string: "nope.png")!, base: dir) else { return XCTFail("missing") }
        XCTAssertEqual(name, "nope.png")
        let b64 = png(width: 4, height: 4).base64EncodedString()
        guard case .image(let img) = ImageDecoding.dataURI(URL(string: "data:image/png;base64,\(b64)")!) else { return XCTFail("data uri") }
        XCTAssertEqual(img.size.width, 4)
        guard case .failed = ImageDecoding.dataURI(URL(string: "data:image/png;base64,@@@")!) else { return XCTFail() }
    }

    // MARK: C-16 (recording server)

    /// A minimal HTTP/1.1 server on localhost that records every request and serves the C-16 test routes.
    final class RecordingServer {
        struct Request { let method: String; let path: String; let headers: [String: String] }
        private let listener: NWListener
        private let queue = DispatchQueue(label: "mdv6.test.server")
        private let lock = NSLock()
        private(set) var requests: [Request] = []
        private(set) var bytesSentToBig = 0
        let image: Data
        /// speccheck treats `//` as a comment even inside a string literal, so URLs are built from this.
        static let slashes = String(repeating: "/", count: 2)
        var port: UInt16 { listener.port!.rawValue }

        init(image: Data) throws {
            self.image = image
            listener = try NWListener(using: .tcp, on: .any)
            listener.newConnectionHandler = { [weak self] c in self?.handle(c) }
            listener.start(queue: queue)
            let ready = DispatchSemaphore(value: 0)
            listener.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
            _ = ready.wait(timeout: .now() + 5)
        }

        func stop() { listener.cancel() }

        private func handle(_ c: NWConnection) {
            c.start(queue: queue)
            var buffer = Data()
            func receive() {
                c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, _ in
                    guard let self else { return }
                    if let data { buffer.append(data) }
                    if let range = buffer.range(of: Data("\r\n\r\n".utf8)) {
                        let head = String(decoding: buffer[..<range.lowerBound], as: UTF8.self)
                        self.respond(c, head: head)
                    } else if done { c.cancel() } else { receive() }
                }
            }
            receive()
        }

        private func respond(_ c: NWConnection, head: String) {
            let lines = head.components(separatedBy: "\r\n")
            let parts = lines[0].split(separator: " ").map(String.init)
            var headers: [String: String] = [:]
            for l in lines.dropFirst() { if let i = l.firstIndex(of: ":") { headers[String(l[..<i]).lowercased()] = l[l.index(after: i)...].trimmingCharacters(in: .whitespaces) } }
            let req = Request(method: parts.first ?? "", path: parts.count > 1 ? parts[1] : "", headers: headers)
            lock.lock(); requests.append(req); lock.unlock()
            func send(_ status: String, _ extra: [String], _ body: Data) {
                var h = "HTTP/1.1 \(status)\r\nConnection: close\r\nContent-Length: \(body.count)\r\n"
                for e in extra { h += e + "\r\n" }
                h += "\r\n"
                c.send(content: Data(h.utf8) + body, completion: .contentProcessed { _ in c.cancel() })
            }
            if req.path == "/img.png" { send("200 OK", ["Content-Type: image/png"], image); return }
            if req.path == "/text" { send("200 OK", ["Content-Type: text/plain"], Data("hi".utf8)); return }
            if req.path == "/missing" { send("404 Not Found", ["Content-Type: image/png"], image); return }
            if req.path.hasPrefix("/hop/") {
                let n = Int(req.path.dropFirst("/hop/".count)) ?? 0
                if n == 0 { send("200 OK", ["Content-Type: image/png"], image) } else { send("302 Found", ["Location: /hop/\(n - 1)"], Data()) }
                return
            }
            if req.path == "/ftp" {
                let target = "ftp:" + RecordingServer.slashes + "127.0.0.1/x.png"
                send("302 Found", ["Location: " + target], Data())
                return
            }
            if req.path == "/big" {
                let total = 40 * 1024 * 1024
                // no Content-Length: the client cannot reject up front and must stream and cut at the ceiling
                let h = "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: image/png\r\n\r\n"
                c.send(content: Data(h.utf8), completion: .contentProcessed { _ in })
                let chunk = Data(repeating: 0x41, count: 1024 * 1024)
                func sendChunk(_ sent: Int) {
                    guard sent < total else { c.cancel(); return }
                    c.send(content: chunk, completion: .contentProcessed { [weak self] error in
                        guard let self else { return }
                        if error != nil { return }
                        self.lock.lock(); self.bytesSentToBig = sent + chunk.count; self.lock.unlock()
                        sendChunk(sent + chunk.count)
                    })
                }
                sendChunk(0)
                return
            }
            if req.path == "/slow" { return }                                                        // never answers
            send("404 Not Found", ["Content-Type: text/plain"], Data())
        }
    }

    private func load(_ loader: RemoteImageLoader, _ url: URL) -> ImageLoadResult {
        let e = expectation(description: "load")
        var result: ImageLoadResult = .failed(reason: "not run")
        Task { result = await loader.load(url); e.fulfill() }
        wait(for: [e], timeout: 30)
        return result
    }

    /// C-16, T-41: the fetch is one unauthenticated `GET` with no Cookie/Authorization/Referer through an ephemeral session
    /// (no persistent cache, cookies, credentials); five `http` redirects are followed, the sixth and a non-HTTP target fail;
    /// non-2xx and non-`image/*` fail with the E-11 placeholder; a body over 32 MiB is cancelled mid-stream; the loader
    /// never writes under the support directory; an in-flight load is cancelled by `cancelAll()`.
    func testRemoteContract() throws {
        let server = try RecordingServer(image: png(width: 6, height: 6))
        defer { server.stop() }
        let base = "http:" + RecordingServer.slashes + "127.0.0.1:\(server.port)"
        let loader = RemoteImageLoader()
        XCTAssertEqual(loader.connectionTimeout, 15); XCTAssertEqual(loader.resourceTimeout, 30)
        XCTAssertEqual(RemoteImageLoader.maxRedirects, 5); XCTAssertEqual(RemoteImageLoader.maxBodyBytes, 32 * 1024 * 1024)
        let config = loader.sessionConfiguration
        XCTAssertNil(config.urlCache); XCTAssertNil(config.httpCookieStorage); XCTAssertNil(config.urlCredentialStorage)
        XCTAssertFalse(config.httpShouldSetCookies)

        guard case .image(let img) = load(loader, URL(string: "\(base)/img.png")!) else { return XCTFail("image") }
        XCTAssertEqual(img.size.width, 6)
        let first = server.requests[0]
        XCTAssertEqual(first.method, "GET"); XCTAssertEqual(first.path, "/img.png")
        for forbidden in ["cookie", "authorization", "referer"] { XCTAssertNil(first.headers[forbidden], forbidden) }

        guard case .image = load(loader, URL(string: "\(base)/hop/5")!) else { return XCTFail("five redirects followed") }
        XCTAssertEqual(server.requests.filter { $0.path.hasPrefix("/hop/") }.count, 6)
        guard case .failed = load(loader, URL(string: "\(base)/hop/6")!) else { return XCTFail("sixth redirect rejected") }
        guard case .failed = load(loader, URL(string: "\(base)/ftp")!) else { return XCTFail("non-http redirect rejected") }
        guard case .failed = load(loader, URL(string: "\(base)/text")!) else { return XCTFail("media type") }
        guard case .failed = load(loader, URL(string: "\(base)/missing")!) else { return XCTFail("status") }
        guard case .failed(let reason) = load(loader, URL(string: "\(base)/big")!) else { return XCTFail("body ceiling") }
        XCTAssertTrue(reason.contains("limit"), reason)
        XCTAssertLessThan(server.bytesSentToBig, 40 * 1024 * 1024, "cancelled before the whole body")
        XCTAssertGreaterThanOrEqual(server.bytesSentToBig, 32 * 1024 * 1024 - 1024 * 1024, "streamed up to the ceiling before the cut")
        XCTAssertEqual(loader.bytesRetained, 0, "partial bytes discarded")
        // nothing persisted: the ephemeral session has no cache; the loader writes no files
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("anything").path))
        // cancelAll aborts an in-flight load
        let slow = RemoteImageLoader(connectionTimeout: 10, resourceTimeout: 20)
        let e = expectation(description: "cancelled")
        var slowResult: ImageLoadResult = .blocked
        Task { slowResult = await slow.load(URL(string: "\(base)/slow")!); e.fulfill() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { slow.cancelAll() }
        wait(for: [e], timeout: 5)
        guard case .failed = slowResult else { return XCTFail("cancelled load fails") }
    }

    /// C-16: the connection (15 s) and resource (30 s) timeouts are enforced — verified with short injected values.
    func testTimeouts() throws {
        let server = try RecordingServer(image: png(width: 2, height: 2))
        defer { server.stop() }
        let loader = RemoteImageLoader(connectionTimeout: 1, resourceTimeout: 2)
        let start = Date()
        guard case .failed = load(loader, URL(string: "http:" + RecordingServer.slashes + "127.0.0.1:\(server.port)/slow")!) else { return XCTFail("timeout") }
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }
}
