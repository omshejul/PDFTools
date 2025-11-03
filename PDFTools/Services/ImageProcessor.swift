//
//  ImageProcessor.swift
//  PDFTools
//
//  Created by Om Shejul on 03/11/25.
//

import CoreGraphics
import Foundation
import UIKit
import UniformTypeIdentifiers

enum ImageProcessorError: LocalizedError {
    case invalidImage
    case processingFailed
    case saveFailed
    case invalidDimensions

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image file"
        case .processingFailed:
            return "Failed to process image"
        case .saveFailed:
            return "Failed to save image"
        case .invalidDimensions:
            return "Invalid dimensions"
        }
    }
}

class ImageProcessor {

    // MARK: - Resize Image

    /// Resize image to specific dimensions while preserving aspect ratio
    func resizeImage(at url: URL, targetWidth: Int, targetHeight: Int, quality: CGFloat = 0.9)
        async throws -> URL
    {
        return try await Task.detached {
            // Load the image source
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                throw ImageProcessorError.invalidImage
            }

            // Get image properties including EXIF orientation
            guard
                let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                    as? [String: Any]
            else {
                throw ImageProcessorError.invalidImage
            }

            // Get orientation from EXIF data (defaults to 1 = normal)
            let orientation = (imageProperties[kCGImagePropertyOrientation as String] as? Int) ?? 1

            // Load the CGImage
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw ImageProcessorError.invalidImage
            }

            // Get dimensions - account for orientation
            // Orientations 5, 6, 7, 8 have width/height swapped
            let needsSwap = [5, 6, 7, 8].contains(orientation)
            let originalWidth = needsSwap ? cgImage.height : cgImage.width
            let originalHeight = needsSwap ? cgImage.width : cgImage.height

            // Validate dimensions
            guard targetWidth > 0 && targetHeight > 0 else {
                throw ImageProcessorError.invalidDimensions
            }

            // Don't upscale - only downscale
            let finalWidth = min(targetWidth, originalWidth)
            let finalHeight = min(targetHeight, originalHeight)

            // Determine output format based on quality setting
            // If quality < 1.0 (100%), convert to JPEG for lossy compression
            // Otherwise, keep original format
            let outputFormat: String
            let fileExtension: String

            if quality < 1.0 {
                // Convert to JPEG for compression
                outputFormat = UTType.jpeg.identifier
                fileExtension = "jpg"
            } else {
                // Keep original format
                outputFormat = self.getImageFormat(for: url)
                fileExtension = url.pathExtension
            }

            // Create output URL
            let outputURL = try self.createTemporaryOutputURL(
                basedOn: url,
                suffix: "_\(finalWidth)x\(finalHeight)",
                extension: fileExtension
            )

            // Create bitmap context for resizing with FINAL dimensions
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

            guard
                let context = CGContext(
                    data: nil,
                    width: finalWidth,
                    height: finalHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                )
            else {
                throw ImageProcessorError.processingFailed
            }

            // Set high quality interpolation
            context.interpolationQuality = .high

            // Apply transformation based on EXIF orientation
            self.applyOrientation(
                orientation, to: context, width: finalWidth, height: finalHeight)

            // Draw image with swapped dimensions for rotated images
            // The transformation will rotate it into the correct orientation
            let drawWidth = needsSwap ? finalHeight : finalWidth
            let drawHeight = needsSwap ? finalWidth : finalHeight
            let rect = CGRect(x: 0, y: 0, width: drawWidth, height: drawHeight)
            context.draw(cgImage, in: rect)

            // Get resized image
            guard let resizedCGImage = context.makeImage() else {
                throw ImageProcessorError.processingFailed
            }

            // Save to file
            guard
                let destination = CGImageDestinationCreateWithURL(
                    outputURL as CFURL,
                    outputFormat as CFString,
                    1,
                    nil
                )
            else {
                throw ImageProcessorError.saveFailed
            }

            // Set quality options based on format
            let options: [CFString: Any]
            if outputFormat == UTType.jpeg.identifier {
                options = [kCGImageDestinationLossyCompressionQuality: quality]
            } else {
                options = [:]
            }

            CGImageDestinationAddImage(destination, resizedCGImage, options as CFDictionary)

            guard CGImageDestinationFinalize(destination) else {
                throw ImageProcessorError.saveFailed
            }

            return outputURL
        }.value
    }

    // MARK: - Calculate Dimensions with Aspect Ratio

    /// Calculate height to preserve aspect ratio when width changes
    func calculateHeight(fromWidth width: Int, aspectRatio: Double) -> Int {
        return Int(Double(width) / aspectRatio)
    }

    /// Calculate width to preserve aspect ratio when height changes
    func calculateWidth(fromHeight height: Int, aspectRatio: Double) -> Int {
        return Int(Double(height) * aspectRatio)
    }

    /// Calculate dimensions to fit within max dimension while preserving aspect ratio
    func calculateDimensionsToFit(originalWidth: Int, originalHeight: Int, maxDimension: Int) -> (
        width: Int, height: Int
    ) {
        let aspectRatio = Double(originalWidth) / Double(originalHeight)

        if originalWidth > originalHeight {
            // Landscape - constrain width
            let newWidth = min(maxDimension, originalWidth)
            let newHeight = Int(Double(newWidth) / aspectRatio)
            return (newWidth, newHeight)
        } else {
            // Portrait or square - constrain height
            let newHeight = min(maxDimension, originalHeight)
            let newWidth = Int(Double(newHeight) * aspectRatio)
            return (newWidth, newHeight)
        }
    }

    // MARK: - Helper Methods

    private nonisolated func createTemporaryOutputURL(
        basedOn inputURL: URL, suffix: String, extension: String? = nil
    ) throws
        -> URL
    {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let fileExtension = `extension` ?? inputURL.pathExtension
        let outputFileName = "\(fileName)\(suffix).\(fileExtension)"
        let outputURL = tempDir.appendingPathComponent(outputFileName)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        return outputURL
    }

    /// Apply EXIF orientation transformation to context
    private nonisolated func applyOrientation(
        _ orientation: Int, to context: CGContext, width: Int, height: Int
    ) {
        // EXIF orientation values:
        // 1 = Normal
        // 2 = Mirrored horizontally
        // 3 = Rotated 180°
        // 4 = Mirrored vertically
        // 5 = Mirrored horizontally, rotated 90° CCW
        // 6 = Rotated 90° CW
        // 7 = Mirrored horizontally, rotated 90° CW
        // 8 = Rotated 90° CCW

        let w = CGFloat(width)
        let h = CGFloat(height)

        switch orientation {
        case 1:
            // Normal - no transformation needed
            break

        case 2:
            // Mirror horizontally
            context.translateBy(x: w, y: 0)
            context.scaleBy(x: -1, y: 1)

        case 3:
            // Rotate 180°
            context.translateBy(x: w, y: h)
            context.rotate(by: .pi)

        case 4:
            // Mirror vertically
            context.translateBy(x: 0, y: h)
            context.scaleBy(x: 1, y: -1)

        case 5:
            // Mirror horizontally, rotate 90° CCW
            context.translateBy(x: 0, y: h)
            context.rotate(by: -.pi / 2)
            context.scaleBy(x: -1, y: 1)

        case 6:
            // Rotate 90° CW
            context.translateBy(x: 0, y: h)
            context.rotate(by: -.pi / 2)

        case 7:
            // Mirror horizontally, rotate 90° CW
            context.translateBy(x: w, y: 0)
            context.rotate(by: .pi / 2)
            context.scaleBy(x: -1, y: 1)

        case 8:
            // Rotate 90° CCW
            context.translateBy(x: w, y: 0)
            context.rotate(by: .pi / 2)

        default:
            break
        }
    }

    /// Get image format identifier for a given URL
    private nonisolated func getImageFormat(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        switch pathExtension {
        case "jpg", "jpeg":
            return UTType.jpeg.identifier
        case "png":
            return UTType.png.identifier
        case "heic", "heif":
            return UTType.heic.identifier
        case "gif":
            return UTType.gif.identifier
        case "bmp":
            return UTType.bmp.identifier
        case "tiff", "tif":
            return UTType.tiff.identifier
        default:
            return UTType.jpeg.identifier  // Default to JPEG
        }
    }

    /// Get file size for a URL
    func getFileSize(for url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? Int64
        else {
            return nil
        }
        return size
    }

    /// Get image dimensions
    func getImageDimensions(for url: URL) -> (width: Int, height: Int)? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                as? [String: Any],
            let width = imageProperties[kCGImagePropertyPixelWidth as String] as? Int,
            let height = imageProperties[kCGImagePropertyPixelHeight as String] as? Int
        else {
            return nil
        }
        return (width, height)
    }
}
