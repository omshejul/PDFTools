//
//  ImageInfo.swift
//  PDFTools
//
//  Created by Om Shejul on 03/11/25.
//

import Foundation
import UIKit

struct ImageInfo: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let url: URL
    let width: Int
    let height: Int
    let fileSize: Int64

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var dimensionsFormatted: String {
        "\(width) × \(height) px"
    }

    var aspectRatio: Double {
        return Double(width) / Double(height)
    }

    init?(url: URL) {
        // Get file size
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? Int64
        else {
            return nil
        }

        // Get image dimensions and orientation
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                as? [String: Any],
            let pixelWidth = imageProperties[kCGImagePropertyPixelWidth as String] as? Int,
            let pixelHeight = imageProperties[kCGImagePropertyPixelHeight as String] as? Int
        else {
            return nil
        }

        // Get EXIF orientation (defaults to 1 = normal)
        let orientation = (imageProperties[kCGImagePropertyOrientation as String] as? Int) ?? 1

        // Swap width/height for orientations 5, 6, 7, 8 (rotated 90° or 270°)
        let needsSwap = [5, 6, 7, 8].contains(orientation)
        let width = needsSwap ? pixelHeight : pixelWidth
        let height = needsSwap ? pixelWidth : pixelHeight

        self.name = url.lastPathComponent
        self.url = url
        self.width = width
        self.height = height
        self.fileSize = size
    }
}
