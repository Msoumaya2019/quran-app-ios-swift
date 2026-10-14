import UIKit

/// Changes only monochrome ink/paper pixels. Saturated edition colors are preserved.
/// No cropping, resampling, coordinate changes or mutation of downloaded originals.
enum MushafNightImage {
    static let paper = UIColor(red: 21/255, green: 24/255, blue: 23/255, alpha: 1)
    static func render(_ image: UIImage, greenMarkers: Bool = false) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        return pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: info) else { return image }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        for i in stride(from: 0, to: buffer.count, by: 4) {
            let alpha = Double(buffer[i+3]) / 255
            guard alpha > 0 else { continue }
            let r = Double(buffer[i]) / alpha, g = Double(buffer[i+1]) / alpha, b = Double(buffer[i+2]) / alpha
            if greenMarkers && r < 30 && g > 90 && g < 160 && b > 50 && b < 140 {
                // The 1441 renderer's own green marker ink needs a lighter shade on dark paper.
                buffer[i] = UInt8(107 * alpha); buffer[i+1] = UInt8(211 * alpha); buffer[i+2] = UInt8(161 * alpha)
            } else if max(r,max(g,b)) - min(r,min(g,b)) <= 25 {
                let coverage = 1 - (r+g+b)/765
                buffer[i] = UInt8(max(0,min(255,(21 + 216 * coverage) * alpha)))
                buffer[i+1] = UInt8(max(0,min(255,(24 + 209 * coverage) * alpha)))
                buffer[i+2] = UInt8(max(0,min(255,(23 + 198 * coverage) * alpha)))
            }
        }
        guard let output = context.makeImage() else { return image }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
        }
    }
}

/// Serializes raster conversion so preloading three pages does not allocate three
/// temporary pixel buffers at once. PageController retains only its own result.
actor MushafNightImageWorker {
    static let shared = MushafNightImageWorker()
    func render(_ image: UIImage, greenMarkers: Bool) -> UIImage {
        guard !Task.isCancelled else { return image }
        return MushafNightImage.render(image, greenMarkers: greenMarkers)
    }
}
