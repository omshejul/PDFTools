//
//  PDFProcessor.swift
//  PDFTools
//
//  Created by Om Shejul on 02/11/25.
//

import CoreGraphics
import Foundation
import PDFKit
import UIKit

enum PDFProcessorError: LocalizedError {
    case invalidPDF
    case processingFailed
    case saveFailed
    case insufficientStorage

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Invalid PDF file"
        case .processingFailed:
            return "Failed to process PDF"
        case .saveFailed:
            return "Failed to save PDF"
        case .insufficientStorage:
            return "Insufficient storage space"
        }
    }
}

class PDFProcessor {

    // MARK: - Compress PDF

    /// Compress PDF by rendering pages to JPEG images (actual compression that works on iOS)
    func compressPDFWithFilter(at url: URL, quality: CompressionQuality) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFProcessorError.invalidPDF
        }

        // Extract quality settings before Task.detached
        let jpegQuality = quality.compressionValue
        let dpi = quality.resolutionDPI

        return try await Task.detached {
            let suffix = "_compressed"
            let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: suffix)

            var mediaBox = CGRect.zero

            guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
                throw PDFProcessorError.processingFailed
            }

            let pageCount = pdfDocument.pageCount

            for pageIndex in 0..<pageCount {
                autoreleasepool {
                    guard let page = pdfDocument.page(at: pageIndex) else { return }

                    let pageBounds = page.bounds(for: .mediaBox)

                    // Render at specified DPI based on quality
                    let scale: CGFloat = dpi / 72.0
                    let imageWidth = Int(pageBounds.width * scale)
                    let imageHeight = Int(pageBounds.height * scale)

                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

                    guard
                        let bitmapContext = CGContext(
                            data: nil,
                            width: imageWidth,
                            height: imageHeight,
                            bitsPerComponent: 8,
                            bytesPerRow: 0,
                            space: colorSpace,
                            bitmapInfo: bitmapInfo
                        )
                    else { return }

                    // White background
                    bitmapContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    bitmapContext.fill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

                    // Render PDF page
                    bitmapContext.scaleBy(x: scale, y: scale)
                    bitmapContext.drawPDFPage(page.pageRef!)

                    guard let cgImage = bitmapContext.makeImage() else { return }

                    // Compress to JPEG
                    let jpegData = NSMutableData()
                    guard
                        let destination = CGImageDestinationCreateWithData(
                            jpegData as CFMutableData,
                            "public.jpeg" as CFString,
                            1,
                            nil
                        )
                    else { return }

                    // JPEG quality based on selected quality level
                    let options: [CFString: Any] = [
                        kCGImageDestinationLossyCompressionQuality: jpegQuality
                    ]

                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    CGImageDestinationFinalize(destination)

                    // Load compressed JPEG directly as CGImage (avoiding MainActor-isolated UIImage)
                    guard let imageSource = CGImageSourceCreateWithData(jpegData as CFData, nil),
                        let finalCGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
                    else { return }

                    // Add to PDF
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

    /// Compress PDF with explicit JPEG quality and DPI
    func compressPDFWithFilter(at url: URL, jpegQuality: CGFloat, dpi: CGFloat) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFProcessorError.invalidPDF
        }

        return try await Task.detached {
            let suffix = "_compressed"
            let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: suffix)

            var mediaBox = CGRect.zero

            guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
                throw PDFProcessorError.processingFailed
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

                    guard
                        let bitmapContext = CGContext(
                            data: nil,
                            width: imageWidth,
                            height: imageHeight,
                            bitsPerComponent: 8,
                            bytesPerRow: 0,
                            space: colorSpace,
                            bitmapInfo: bitmapInfo
                        )
                    else { return }

                    // White background
                    bitmapContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    bitmapContext.fill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

                    // Render PDF page
                    bitmapContext.scaleBy(x: scale, y: scale)
                    bitmapContext.drawPDFPage(page.pageRef!)

                    guard let cgImage = bitmapContext.makeImage() else { return }

                    // Compress to JPEG
                    let jpegData = NSMutableData()
                    guard
                        let destination = CGImageDestinationCreateWithData(
                            jpegData as CFMutableData,
                            "public.jpeg" as CFString,
                            1,
                            nil
                        )
                    else { return }

                    let options: [CFString: Any] = [
                        kCGImageDestinationLossyCompressionQuality: jpegQuality
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

    // MARK: - Scale PDF

    /// Scale PDF by a percentage factor
    func scalePDF(at url: URL, scaleFactor: CGFloat) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFProcessorError.invalidPDF
        }

        return try await Task.detached {
            let suffix = "_scaled_\(Int(scaleFactor * 100))pct"
            let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: suffix)

            var mediaBox = CGRect.zero

            guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
                throw PDFProcessorError.processingFailed
            }

            pdfContext.interpolationQuality = .low

            let pageCount = pdfDocument.pageCount

            for pageIndex in 0..<pageCount {
                autoreleasepool {
                    guard let page = pdfDocument.page(at: pageIndex) else { return }

                    let originalBounds = page.bounds(for: .mediaBox)

                    let scaledWidth = originalBounds.width * scaleFactor
                    let scaledHeight = originalBounds.height * scaleFactor
                    var scaledMediaBox = CGRect(
                        x: 0, y: 0, width: scaledWidth, height: scaledHeight)

                    pdfContext.beginPage(mediaBox: &scaledMediaBox)
                    pdfContext.saveGState()
                    pdfContext.scaleBy(x: scaleFactor, y: scaleFactor)
                    pdfContext.drawPDFPage(page.pageRef!)
                    pdfContext.restoreGState()
                    pdfContext.endPage()
                }
            }

            pdfContext.closePDF()

            return outputURL
        }.value
    }

    // MARK: - Helper Methods

    private nonisolated func createTemporaryOutputURL(basedOn inputURL: URL, suffix: String)
        throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let outputFileName = "\(fileName)\(suffix).pdf"
        let outputURL = tempDir.appendingPathComponent(outputFileName)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        return outputURL
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

    // MARK: - Copy Without Compression

    /// Copy PDF without any compression (keeps original quality)
    func copyPDFWithoutCompression(at url: URL) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFProcessorError.invalidPDF
        }

        return try await Task.detached {
            let suffix = "_processed"
            let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: suffix)

            // Simply write the PDF as-is without any modifications
            guard pdfDocument.write(to: outputURL) else {
                throw PDFProcessorError.saveFailed
            }

            return outputURL
        }.value
    }

    // MARK: - Reorder Pages

    /// Reorder PDF pages based on the provided page order array
    /// - Parameters:
    ///   - url: The URL of the PDF to reorder
    ///   - pageOrder: Array of page indices in the desired order (0-based)
    /// - Returns: URL of the reordered PDF
    func reorderPages(at url: URL, pageOrder: [Int]) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFProcessorError.invalidPDF
        }

        let originalPageCount = pdfDocument.pageCount

        // Validate page order array
        guard pageOrder.count == originalPageCount else {
            throw PDFProcessorError.processingFailed
        }

        return try await Task.detached {
            let suffix = "_reordered"
            let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: suffix)

            // Create a new PDF document
            let newDocument = PDFDocument()

            // Add pages in the new order
            for (newIndex, originalIndex) in pageOrder.enumerated() {
                autoreleasepool {
                    guard let page = pdfDocument.page(at: originalIndex) else { return }
                    newDocument.insert(page, at: newIndex)
                }
            }

            // Save the reordered PDF
            guard newDocument.write(to: outputURL) else {
                throw PDFProcessorError.saveFailed
            }

            return outputURL
        }.value
    }

    // MARK: - Remove Password

    /// Remove password protection from a PDF by creating a new unencrypted PDF
    func removePassword(from url: URL, password: String) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFProcessorError.invalidPDF
        }

        // Check if PDF is locked
        guard pdfDocument.isLocked else {
            // PDF is not password-protected, just return a copy
            return try await Task.detached {
                let suffix = "_unlocked"
                let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: suffix)
                try FileManager.default.copyItem(at: url, to: outputURL)
                return outputURL
            }.value
        }

        // Try to unlock with provided password
        guard pdfDocument.unlock(withPassword: password) else {
            throw PDFProcessorError.processingFailed
        }

        // Create unlocked PDF by rendering pages to a new PDF (ensures no encryption)
        return try await Task.detached {
            let suffix = "_unlocked"
            let outputURL = try self.createTemporaryOutputURL(basedOn: url, suffix: suffix)

            var mediaBox = CGRect.zero
            guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
                throw PDFProcessorError.processingFailed
            }

            let pageCount = pdfDocument.pageCount

            for pageIndex in 0..<pageCount {
                autoreleasepool {
                    guard let page = pdfDocument.page(at: pageIndex) else { return }

                    let pageBounds = page.bounds(for: .mediaBox)
                    var pageMediaBox = pageBounds

                    // Add page to new PDF
                    pdfContext.beginPage(mediaBox: &pageMediaBox)
                    pdfContext.saveGState()

                    // Draw the PDF page content
                    pdfContext.drawPDFPage(page.pageRef!)

                    pdfContext.restoreGState()
                    pdfContext.endPage()
                }
            }

            pdfContext.closePDF()
            return outputURL
        }.value
    }
}
