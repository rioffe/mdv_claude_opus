// PDFImageScan — where a PDF page draws its images: each image XObject's placement (the current transformation
// applied to the unit square) and its pixel size, in draw order. C-21.4 finds its placeholder slots with it; the print
// tests and the harness's `--print-pdf` records (C-17) read image draws from the finished pages with it.
import CoreGraphics

public struct PDFImagePlacement: Equatable {
    public let rect: CGRect          // page space (points, y up)
    public let pixels: CGSize
}

public enum PDFImageScan {
    private final class State {
        var ctm = CGAffineTransform.identity
        var stack: [CGAffineTransform] = []
        var out: [PDFImagePlacement] = []
        let resources: CGPDFDictionaryRef?
        let stream: CGPDFContentStreamRef
        init(resources: CGPDFDictionaryRef?, stream: CGPDFContentStreamRef) { self.resources = resources; self.stream = stream }
    }

    public static func placements(in page: CGPDFPage) -> [PDFImagePlacement] {
        guard let pageDict = page.dictionary else { return [] }
        var res: CGPDFDictionaryRef?
        CGPDFDictionaryGetDictionary(pageDict, "Resources", &res)
        return scan(stream: CGPDFContentStreamCreateWithPage(page), resources: res, ctm: .identity)
    }

    private static func scan(stream: CGPDFContentStreamRef, resources: CGPDFDictionaryRef?, ctm: CGAffineTransform) -> [PDFImagePlacement] {
        let state = State(resources: resources, stream: stream)
        state.ctm = ctm
        let table = CGPDFOperatorTableCreate()!
        CGPDFOperatorTableSetCallback(table, "q") { _, info in
            let s = Unmanaged<State>.fromOpaque(info!).takeUnretainedValue(); s.stack.append(s.ctm)
        }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in
            let s = Unmanaged<State>.fromOpaque(info!).takeUnretainedValue(); if let t = s.stack.popLast() { s.ctm = t }
        }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
            let s = Unmanaged<State>.fromOpaque(info!).takeUnretainedValue()
            var v = [CGPDFReal](repeating: 0, count: 6)
            for i in (0 ..< 6).reversed() { CGPDFScannerPopNumber(scanner, &v[i]) }
            s.ctm = CGAffineTransform(a: v[0], b: v[1], c: v[2], d: v[3], tx: v[4], ty: v[5]).concatenating(s.ctm)
        }
        CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
            let s = Unmanaged<State>.fromOpaque(info!).takeUnretainedValue()
            var namePtr: UnsafePointer<CChar>?
            guard CGPDFScannerPopName(scanner, &namePtr), let namePtr, let res = s.resources else { return }
            var xobjects: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(res, "XObject", &xobjects), let xobjects else { return }
            var streamRef: CGPDFStreamRef?
            guard CGPDFDictionaryGetStream(xobjects, namePtr, &streamRef), let streamRef, let dict = CGPDFStreamGetDictionary(streamRef) else { return }
            var subtype: UnsafePointer<CChar>?
            CGPDFDictionaryGetName(dict, "Subtype", &subtype)
            guard let subtype else { return }
            let kind = String(cString: subtype)
            if kind == "Image" {
                var w: CGPDFInteger = 0, h: CGPDFInteger = 0
                CGPDFDictionaryGetInteger(dict, "Width", &w); CGPDFDictionaryGetInteger(dict, "Height", &h)
                let r = CGRect(x: 0, y: 0, width: 1, height: 1).applying(s.ctm)
                s.out.append(PDFImagePlacement(rect: r, pixels: CGSize(width: Int(w), height: Int(h))))
            } else if kind == "Form" {                                     // a form XObject: scan it with its own matrix
                var formRes: CGPDFDictionaryRef?
                CGPDFDictionaryGetDictionary(dict, "Resources", &formRes)
                var matrix = CGAffineTransform.identity
                var arr: CGPDFArrayRef?
                if CGPDFDictionaryGetArray(dict, "Matrix", &arr), let arr, CGPDFArrayGetCount(arr) == 6 {
                    var m = [CGPDFReal](repeating: 0, count: 6)
                    for i in 0 ..< 6 { CGPDFArrayGetNumber(arr, i, &m[i]) }
                    matrix = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5])
                }
                let inner = CGPDFContentStreamCreateWithStream(streamRef, formRes ?? res, s.stream)
                s.out += PDFImageScan.scan(stream: inner, resources: formRes ?? res, ctm: matrix.concatenating(s.ctm))
            }
        }
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(state).toOpaque())
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
        return state.out
    }
}
