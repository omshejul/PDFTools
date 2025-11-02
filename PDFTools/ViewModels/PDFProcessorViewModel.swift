//
//  PDFProcessorViewModel.swift
//  PDFTools
//
//  Created by Om Shejul on 02/11/25.
//

import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class PDFProcessorViewModel: ObservableObject {
    @Published var selectedPDF: PDFDocumentInfo?
    @Published var processedPDF: PDFDocumentInfo?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showingFilePicker = false
    @Published var showingShareSheet = false
    @Published var compressionQuality: CompressionQuality = .medium

    // Password-related properties
    @Published var showingPasswordPrompt = false
    @Published var passwordInput = ""
    @Published var unlockedPDF: PDFDocumentInfo?

    private let processor = PDFProcessor()

    // Estimated size based on compression settings with intelligent calculation
    var estimatedSizeString: String? {
        guard let originalSize = selectedPDF?.fileSize,
            let pdf = selectedPDF
        else { return nil }

        let estimatedSize = calculateCompressedSize(
            originalSize: originalSize,
            pageCount: pdf.pageCount,
            quality: compressionQuality
        )
        return ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file)
    }

    var estimatedReductionPercentage: Int? {
        guard let originalSize = selectedPDF?.fileSize,
            let pdf = selectedPDF
        else { return nil }

        let estimatedSize = calculateCompressedSize(
            originalSize: originalSize,
            pageCount: pdf.pageCount,
            quality: compressionQuality
        )
        let reduction = Double(originalSize - estimatedSize) / Double(originalSize) * 100
        return Int(reduction)
    }

    // MARK: - Smart Size Estimation

    private func calculateCompressedSize(
        originalSize: Int64,
        pageCount: Int,
        quality: CompressionQuality
    ) -> Int64 {
        // Estimate based on JPEG compression formula
        // File size ≈ (width × height × DPI² × bytes_per_pixel × JPEG_quality) + overhead

        let dpi = quality.resolutionDPI
        let jpegQuality = quality.compressionValue

        // Average PDF page size (A4 at 72 DPI ≈ 595 × 842 points)
        let avgWidth: CGFloat = 595.0
        let avgHeight: CGFloat = 842.0

        // Calculate render dimensions at specified DPI
        let scale = dpi / 72.0
        let renderWidth = avgWidth * scale
        let renderHeight = avgHeight * scale

        // Estimate bytes per pixel for JPEG (typically 0.5 to 3 bytes depending on quality)
        // Lower JPEG quality = fewer bytes per pixel
        let bytesPerPixel = 0.5 + (jpegQuality * 2.5)  // Range: 0.5 to 3.0

        // Calculate image size per page
        let pixelsPerPage = renderWidth * renderHeight
        let bytesPerPage = Int64(pixelsPerPage * bytesPerPixel)

        // Total image data
        let totalImageData = bytesPerPage * Int64(pageCount)

        // PDF overhead (structure, metadata) - roughly 10-20 KB + 2 KB per page
        let pdfOverhead = Int64(15000 + (2000 * pageCount))

        // Total estimated size
        let estimatedSize = totalImageData + pdfOverhead

        // Clamp to reasonable range (never estimate less than 10% or more than 95% of original)
        let minSize = Int64(Double(originalSize) * 0.10)
        let maxSize = Int64(Double(originalSize) * 0.95)

        return max(minSize, min(maxSize, estimatedSize))
    }

    // MARK: - File Selection

    func selectPDF(from url: URL) {
        // Check if URL is already in temp directory (no security-scoped access needed)
        let isTempURL = url.path.hasPrefix(FileManager.default.temporaryDirectory.path)

        // Only access security-scoped resource if not a temp URL
        var accessed = false
        if !isTempURL {
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access the file"
                return
            }
            accessed = true
        }

        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Create a copy in temp directory to work with
        do {
            let tempURL: URL
            if isTempURL {
                // Already in temp directory, use it directly
                tempURL = url
            } else {
                // Copy to temp directory
                tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)

                // Remove if exists
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }

                // Copy file
                try FileManager.default.copyItem(at: url, to: tempURL)
            }

            // Create PDF document info
            if let pdfInfo = PDFDocumentInfo(url: tempURL) {
                selectedPDF = pdfInfo
                processedPDF = nil  // Reset processed PDF
                unlockedPDF = nil  // Reset unlocked PDF
                errorMessage = nil

                // Check if PDF is password-protected
                if pdfInfo.isPasswordProtected {
                    showingPasswordPrompt = true
                }
            } else {
                errorMessage = "Invalid PDF file"
            }
        } catch {
            errorMessage = "Error loading PDF: \(error.localizedDescription)"
        }
    }

    // MARK: - Password Removal

    func unlockPDF(with password: String) async {
        guard let selectedPDF = selectedPDF else {
            errorMessage = "No PDF selected"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let outputURL = try await processor.removePassword(
                from: selectedPDF.url,
                password: password
            )

            if let unlockedInfo = PDFDocumentInfo(url: outputURL, isUnlockedVersion: true) {
                unlockedPDF = unlockedInfo
                showingPasswordPrompt = false
                passwordInput = ""
            } else {
                errorMessage = "Failed to unlock PDF"
            }
        } catch {
            errorMessage = "Failed to unlock PDF. Please check your password and try again."
        }

        isProcessing = false
    }

    // MARK: - Processing

    func processPDF() async {
        // Use unlocked PDF if available, otherwise use selected PDF
        let pdfToProcess = unlockedPDF ?? selectedPDF

        guard let pdf = pdfToProcess else {
            errorMessage = "No PDF selected"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            // Always use JPEG compression with selected quality
            let outputURL = try await processor.compressPDFWithFilter(
                at: pdf.url,
                quality: compressionQuality
            )

            if let processedInfo = PDFDocumentInfo(url: outputURL) {
                processedPDF = processedInfo
            } else {
                errorMessage = "Failed to load processed PDF"
            }
        } catch {
            errorMessage = "Processing failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    // MARK: - Export

    func getShareURL() -> URL? {
        // Priority: processed PDF > unlocked PDF
        if let processedURL = processedPDF?.url {
            return processedURL
        }
        return unlockedPDF?.url
    }

    func cleanup() {
        // Clean up temporary files
        if let url = selectedPDF?.url {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = unlockedPDF?.url {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = processedPDF?.url {
            try? FileManager.default.removeItem(at: url)
        }

        selectedPDF = nil
        unlockedPDF = nil
        processedPDF = nil
        passwordInput = ""
        showingPasswordPrompt = false
    }

    func clearSelectedPDF() {
        // Clean up only the selected PDF file (not processed or unlocked PDF)
        if let url = selectedPDF?.url {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = unlockedPDF?.url {
            try? FileManager.default.removeItem(at: url)
        }
        selectedPDF = nil
        unlockedPDF = nil
        errorMessage = nil
        passwordInput = ""
        showingPasswordPrompt = false
    }
}
