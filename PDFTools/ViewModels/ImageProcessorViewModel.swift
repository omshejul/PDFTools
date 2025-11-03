//
//  ImageProcessorViewModel.swift
//  PDFTools
//
//  Created by Om Shejul on 03/11/25.
//

import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class ImageProcessorViewModel: ObservableObject {
    @Published var selectedImage: ImageInfo?
    @Published var processedImage: ImageInfo?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showingFilePicker = false
    @Published var showingShareSheet = false
    @Published var showingQuickLook = false

    // Dimension inputs
    @Published var targetWidthString: String = ""
    @Published var targetHeightString: String = ""
    @Published var outputQuality: CGFloat = 0.9

    // Track which field was last edited to preserve it during auto-calculation
    private var lastEditedField: DimensionField = .width
    private var isUpdatingFields = false

    private let processor = ImageProcessor()

    enum DimensionField {
        case width, height
    }

    // Computed properties for actual dimension values
    var targetWidth: Int? {
        Int(targetWidthString)
    }

    var targetHeight: Int? {
        Int(targetHeightString)
    }

    var isValidDimensions: Bool {
        guard let width = targetWidth, let height = targetHeight else {
            return false
        }
        return width > 0 && height > 0
    }

    // Check if processing will likely reduce file size
    var willLikelyReduceSize: Bool {
        guard let image = selectedImage else { return false }
        guard let width = targetWidth, let height = targetHeight else { return false }

        // If dimensions are reduced, size will reduce
        if width < image.width || height < image.height {
            return true
        }

        // If quality < 100%, will convert to JPEG and compress
        if outputQuality < 1.0 {
            return true
        }

        // Same dimensions + 100% quality = likely no reduction or increase
        return false
    }

    // Estimate original JPEG compression level
    var originalCompressionInfo: String? {
        guard let image = selectedImage else { return nil }
        let ext = image.url.pathExtension.lowercased()
        guard ext == "jpg" || ext == "jpeg" else { return nil }

        let pixels = image.width * image.height
        let bytesPerPixel = Double(image.fileSize) / Double(pixels)

        if bytesPerPixel < 0.3 {
            return "Very heavily compressed (quality ~30-50%)"
        } else if bytesPerPixel < 0.5 {
            return "Heavily compressed (quality ~50-70%)"
        } else if bytesPerPixel < 1.0 {
            return "Moderately compressed (quality ~70-85%)"
        } else {
            return "Lightly compressed (quality ~85-100%)"
        }
    }

    var processingWarning: String? {
        guard let image = selectedImage else { return nil }
        guard let width = targetWidth, let height = targetHeight else { return nil }

        // Same dimensions + 100% quality
        if width == image.width && height == image.height && outputQuality >= 1.0 {
            return "Same dimensions and 100% quality may not reduce file size"
        }

        // Check if original JPEG is heavily compressed
        let ext = image.url.pathExtension.lowercased()
        if ext == "jpg" || ext == "jpeg" {
            let originalPixels = image.width * image.height
            let bytesPerPixel = Double(image.fileSize) / Double(originalPixels)

            // If original is < 0.5 bytes/pixel, it's heavily compressed
            // Recompressing at high quality will likely increase size
            if bytesPerPixel < 0.5 && outputQuality > 0.8 {
                let targetPixels = width * height
                let dimensionReduction = Double(targetPixels) / Double(originalPixels)

                // If reducing by < 50% with high quality, warn about size increase
                if dimensionReduction > 0.5 {
                    return "Original is heavily compressed. Try lowering quality to 70% or less"
                }
            }
        }

        return nil
    }

    // MARK: - File Selection

    func selectImage(from url: URL) {
        // Check if URL is already in temp directory
        let isTempURL = url.path.hasPrefix(FileManager.default.temporaryDirectory.path)

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

        do {
            let tempURL: URL
            if isTempURL {
                tempURL = url
            } else {
                // Copy to temp directory
                tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)

                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }

                try FileManager.default.copyItem(at: url, to: tempURL)
            }

            // Create image info
            if let imageInfo = ImageInfo(url: tempURL) {
                selectedImage = imageInfo
                processedImage = nil
                errorMessage = nil

                // Initialize dimension inputs with original dimensions
                targetWidthString = String(imageInfo.width)
                targetHeightString = String(imageInfo.height)
            } else {
                errorMessage = "Invalid image file"
            }
        } catch {
            errorMessage = "Error loading image: \(error.localizedDescription)"
        }
    }

    // MARK: - Dimension Auto-Calculation

    func updateWidth(_ newWidth: String) {
        guard !isUpdatingFields else { return }

        targetWidthString = newWidth
        lastEditedField = .width

        // Auto-calculate height if we have a valid width and selected image
        if let width = Int(newWidth),
            width > 0,
            let image = selectedImage
        {
            // Clamp width to original dimensions (prevent upscaling)
            let clampedWidth = min(width, image.width)

            isUpdatingFields = true

            // Update width if it was clamped
            if clampedWidth != width {
                targetWidthString = String(clampedWidth)
            }

            let newHeight = processor.calculateHeight(
                fromWidth: clampedWidth, aspectRatio: image.aspectRatio)
            targetHeightString = String(newHeight)
            isUpdatingFields = false
        }
    }

    func updateHeight(_ newHeight: String) {
        guard !isUpdatingFields else { return }

        targetHeightString = newHeight
        lastEditedField = .height

        // Auto-calculate width if we have a valid height and selected image
        if let height = Int(newHeight),
            height > 0,
            let image = selectedImage
        {
            // Clamp height to original dimensions (prevent upscaling)
            let clampedHeight = min(height, image.height)

            isUpdatingFields = true

            // Update height if it was clamped
            if clampedHeight != height {
                targetHeightString = String(clampedHeight)
            }

            let newWidth = processor.calculateWidth(
                fromHeight: clampedHeight, aspectRatio: image.aspectRatio)
            targetWidthString = String(newWidth)
            isUpdatingFields = false
        }
    }

    func resetToOriginalDimensions() {
        guard let image = selectedImage else { return }
        targetWidthString = String(image.width)
        targetHeightString = String(image.height)
    }

    func setPresetByMaxDimension(_ maxDimension: Int) {
        guard let image = selectedImage else { return }

        // Calculate dimensions that fit within max dimension while preserving aspect ratio
        let (newWidth, newHeight) = processor.calculateDimensionsToFit(
            originalWidth: image.width,
            originalHeight: image.height,
            maxDimension: maxDimension
        )

        targetWidthString = String(newWidth)
        targetHeightString = String(newHeight)
    }

    // MARK: - Processing

    func processImage() async {
        guard let image = selectedImage else {
            errorMessage = "No image selected"
            return
        }

        guard let width = targetWidth, let height = targetHeight else {
            errorMessage = "Invalid dimensions"
            return
        }

        guard width > 0 && height > 0 else {
            errorMessage = "Dimensions must be greater than 0"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let outputURL = try await processor.resizeImage(
                at: image.url,
                targetWidth: width,
                targetHeight: height,
                quality: outputQuality
            )

            if let processedInfo = ImageInfo(url: outputURL) {
                processedImage = processedInfo
            } else {
                errorMessage = "Failed to load processed image"
            }
        } catch {
            errorMessage = "Processing failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    // MARK: - Export

    func getShareURL() -> URL? {
        return processedImage?.url
    }

    func cleanup() {
        // Clean up temporary files
        if let url = selectedImage?.url {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = processedImage?.url {
            try? FileManager.default.removeItem(at: url)
        }

        selectedImage = nil
        processedImage = nil
        targetWidthString = ""
        targetHeightString = ""
    }

    func clearSelectedImage() {
        if let url = selectedImage?.url {
            try? FileManager.default.removeItem(at: url)
        }
        selectedImage = nil
        errorMessage = nil
        targetWidthString = ""
        targetHeightString = ""
    }
}
