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
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        for i in stride(from: 0, to: buffer.count, by: 4) {
            let r = Double(buffer[i]), g = Double(buffer[i+1]), b = Double(buffer[i+2])
            if greenMarkers && r < 30 && g > 90 && g < 160 && b > 50 && b < 140 {
                // The 1441 renderer's own green marker ink needs a lighter shade on dark paper.
                buffer[i] = 107; buffer[i+1] = 211; buffer[i+2] = 161
            } else if max(r,g,b) - min(r,g,b) <= 25 {
                let coverage = 1 - (r+g+b)/765
                buffer[i] = UInt8(21 + 216 * coverage)
                buffer[i+1] = UInt8(24 + 209 * coverage)
                buffer[i+2] = UInt8(23 + 198 * coverage)
            }
        }
        guard let output = context.makeImage() else { return image }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
        }
    }
}
