import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ProblemScreenshot {
    static func prepare(_ data: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
            guard CGImageDestinationFinalize(destination), output.length <= 5 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
            return output as Data
        }.value
    }
}
