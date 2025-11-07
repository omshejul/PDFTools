//
//  SelectivePDFCompressor.swift
//  PDFTools
//
//  High-level Swift wrapper for selective PDF image compression
//  Uses MuPDF when available, falls back to smart compression
//

import Foundation
import PDFKit
import CoreGraphics
import UIKit

enum SelectivePDFCompressorError: LocalizedError {
    case invalidPDF
    case compressionFailed
    case mupdfNotAvailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Invalid PDF file"
        case .compressionFailed:
            return "Failed to compress PDF"
        case .mupdfNotAvailable:
            return "Advanced PDF processing library not available"
        case .saveFailed:
            return "Failed to save compressed PDF"
        }
    }
}

class SelectivePDFCompressor {

    // MARK: - Public API

    /// Compress PDF by selectively downscaling embedded images while preserving vector content
    /// - Parameters:
    ///   - url: Source PDF URL
    ///   - jpegQuality: JPEG compression quality (0.0 to 1.0)
    ///   - maxImageDimension: Maximum width/height for images in pixels
    ///   - dpi: Target DPI for rendering (used if selective compression unavailable)
    /// - Returns: URL of compressed PDF
    func compressPDF(
        at url: URL,
        jpegQuality: CGFloat = 0.7,
        maxImageDimension: Int = 2048,
        dpi: CGFloat = 150
    ) async throws -> URL {

        // Check if MuPDF is available for true selective compression
        if MuPDFBridge.isMuPDFAvailable() {
            return try await compressWithMuPDF(
                at: url,
                jpegQuality: jpegQuality,
                maxImageDimension: maxImageDimension
            )
        } else {
            // Fallback to smart page-based compression
            print("ℹ️ MuPDF not available - using fallback compression method")
            print("ℹ️ This will rasterize pages but optimize for quality/size balance")

            return try await compressWithFallback(
                at: url,
                jpegQuality: jpegQuality,
                dpi: dpi
            )
        }
    }

    // MARK: - MuPDF-based Compression

    private func compressWithMuPDF(
        at url: URL,
        jpegQuality: CGFloat,
        maxImageDimension: Int
    ) async throws -> URL {

        return try await Task.detached {
            let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: "_selective_compressed")

            var error: NSError?
            let success = MuPDFBridge.compressPDF(
                atPath: url.path,
                outputPath: outputURL.path,
                maxDimension: Int32(maxImageDimension),
                jpegQuality: Float(jpegQuality),
                error: &error
            )

            if !success {
                if let error = error {
                    throw error
                } else {
                    throw SelectivePDFCompressorError.compressionFailed
                }
            }

            return outputURL
        }.value
    }

    // MARK: - Fallback Compression

    /// Fallback compression when MuPDF is not available
    /// Uses intelligent page rendering to minimize quality loss
    private func compressWithFallback(
        at url: URL,
        jpegQuality: CGFloat,
        dpi: CGFloat
    ) async throws -> URL {

        guard let pdfDocument = PDFDocument(url: url) else {
            throw SelectivePDFCompressorError.invalidPDF
        }

        return try await Task.detached {
            let suffix = "_compressed"
            let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: suffix)

            var mediaBox = CGRect.zero

            guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
                throw SelectivePDFCompressorError.compressionFailed
            }

            let pageCount = pdfDocument.pageCount

            for pageIndex in 0..<pageCount {
                autoreleasepool {
                    guard let page = pdfDocument.page(at: pageIndex) else { return }

                    let pageBounds = page.bounds(for: .mediaBox)

                    // Render at specified DPI
                    let scale: CGFloat = dpi / 72.0
                    let imageWidth = Int(pageBounds.width * scale)
                    let imageHeight = Int(pageBounds.height * scale)

                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

                    guard let bitmapContext = CGContext(
                        data: nil,
                        width: imageWidth,
                        height: imageHeight,
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: bitmapInfo
                    ) else { return }

                    // White background
                    bitmapContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    bitmapContext.fill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

                    // High-quality rendering
                    bitmapContext.interpolationQuality = .high
                    bitmapContext.setShouldAntialias(true)
                    bitmapContext.setAllowsAntialiasing(true)

                    // Render PDF page
                    bitmapContext.scaleBy(x: scale, y: scale)
                    bitmapContext.drawPDFPage(page.pageRef!)

                    guard let cgImage = bitmapContext.makeImage() else { return }

                    // Compress to JPEG with specified quality
                    let jpegData = NSMutableData()
                    guard let destination = CGImageDestinationCreateWithData(
                        jpegData as CFMutableData,
                        "public.jpeg" as CFString,
                        1,
                        nil
                    ) else { return }

                    let options: [CFString: Any] = [
                        kCGImageDestinationLossyCompressionQuality: jpegQuality,
                        kCGImageDestinationOptimizeColorForSharing: true
                    ]

                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    CGImageDestinationFinalize(destination)

                    guard let imageSource = CGImageSourceCreateWithData(jpegData as CFData, nil),
                          let finalCGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
                    else { return }

                    var pageMediaBox = pageBounds
                    pdfContext.beginPage(mediaBox: &pageMediaBox)
                    pdfContext.draw(finalCGImage, in: pageBounds)
                    pdfContext.endPage()
                }
            }

            pdfContext.closePDF()
            return outputURL
        }.value
    }

    // MARK: - Image Extraction (for analysis)

    /// Extract images from PDF for preview/analysis
    /// Returns information about images found in the PDF
    func analyzeImages(in url: URL) async throws -> [ImageInfo] {
        guard MuPDFBridge.isMuPDFAvailable() else {
            throw SelectivePDFCompressorError.mupdfNotAvailable
        }

        return try await Task.detached {
            var error: NSError?
            guard let extractedImages = MuPDFBridge.extractImages(fromPDF: url.path, error: &error) else {
                if let error = error {
                    throw error
                } else {
                    throw SelectivePDFCompressorError.compressionFailed
                }
            }

            var imageInfos: [ImageInfo] = []

            for image in extractedImages {
                guard let mupdfImage = image as? MuPDFExtractedImage else { continue }

                let info = ImageInfo(
                    pageIndex: mupdfImage.pageNumber,
                    imageIndex: mupdfImage.imageIndex,
                    width: mupdfImage.width,
                    height: mupdfImage.height,
                    sizeInBytes: Int64(mupdfImage.imageData.count)
                )
                imageInfos.append(info)
            }

            return imageInfos
        }.value
    }

    // MARK: - Helper Methods

    private nonisolated func createTemporaryOutputURL(basedOn inputURL: URL, suffix: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let outputFileName = "\(fileName)\(suffix).pdf"
        let outputURL = tempDir.appendingPathComponent(outputFileName)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        return outputURL
    }

    /// Get file size for comparison
    func getFileSize(for url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }
}

// MARK: - Supporting Types

struct ImageInfo {
    let pageIndex: Int
    let imageIndex: Int
    let width: Int
    let height: Int
    let sizeInBytes: Int64

    var dimensionsString: String {
        return "\(width) × \(height)"
    }

    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }
}
