//
//  ImageToolView.swift
//  PDFTools
//
//  Created by Om Shejul on 03/11/25.
//

// QuickLook preview for images
// QuickLook preview wrapper
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct ImageToolView: View {
    @StateObject private var viewModel = ImageProcessorViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)

                    Text("Image Resizer")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Downscale images while preserving aspect ratio")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // Drop Zone or Select Image Button
                if viewModel.selectedImage == nil {
                    ImageDropZoneView(viewModel: viewModel)
                        .padding(.horizontal)
                }

                // Selected Image Info
                if let image = viewModel.selectedImage {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Selected Image")
                                .font(.headline)

                            Spacer()

                            Button {
                                viewModel.clearSelectedImage()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.purple)
                                Text(image.name)
                                    .lineLimit(1)
                            }

                            HStack {
                                Image(systemName: "aspectratio")
                                Text(image.dimensionsFormatted)
                            }

                            HStack {
                                Image(systemName: "externaldrive")
                                Text(image.fileSizeFormatted)
                            }

                            // Show original compression info for JPEGs
                            if let compressionInfo = viewModel.originalCompressionInfo {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text(compressionInfo)
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Dimension Controls
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(.purple)
                                .font(.title3)
                            Text("Target Dimensions")
                                .font(.headline)

                            Spacer()

                            // Show max dimensions
                            if let image = viewModel.selectedImage {
                                Text("Max: \(image.width)×\(image.height)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Width input
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Width (px)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let image = viewModel.selectedImage {
                                    Spacer()
                                    Text("max: \(image.width)")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }

                            TextField(
                                "Width",
                                text: Binding(
                                    get: { viewModel.targetWidthString },
                                    set: { viewModel.updateWidth($0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        }

                        // Height input
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Height (px)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let image = viewModel.selectedImage {
                                    Spacer()
                                    Text("max: \(image.height)")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }

                            TextField(
                                "Height",
                                text: Binding(
                                    get: { viewModel.targetHeightString },
                                    set: { viewModel.updateHeight($0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        }

                        // Aspect ratio info
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Aspect ratio preserved")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)

                        // Quick presets
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Presets (Max Dimension)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    PresetButton(
                                        title: "Original",
                                        action: {
                                            viewModel.resetToOriginalDimensions()
                                        })

                                    PresetButton(
                                        title: "1920px",
                                        action: {
                                            viewModel.setPresetByMaxDimension(1920)
                                        })

                                    PresetButton(
                                        title: "1280px",
                                        action: {
                                            viewModel.setPresetByMaxDimension(1280)
                                        })

                                    PresetButton(
                                        title: "800px",
                                        action: {
                                            viewModel.setPresetByMaxDimension(800)
                                        })

                                    PresetButton(
                                        title: "640px",
                                        action: {
                                            viewModel.setPresetByMaxDimension(640)
                                        })
                                }
                            }
                        }
                        .padding(.top, 8)

                        // Quality slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Output Quality")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(Int(viewModel.outputQuality * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                            }

                            Slider(value: $viewModel.outputQuality, in: 0.1...1.0, step: 0.1)
                                .accentColor(.purple)

                            // Format conversion indicator
                            if viewModel.outputQuality < 1.0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("Will convert to JPEG for compression")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Processing warning
                    if let warning = viewModel.processingWarning {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }

                    // Process Button
                    Button {
                        Task {
                            await viewModel.processImage()
                        }
                    } label: {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Label("Resize Image", systemImage: "arrow.down.circle.fill")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        viewModel.isValidDimensions && !viewModel.isProcessing
                            ? Color.purple : Color.gray
                    )
                    .cornerRadius(12)
                    .disabled(!viewModel.isValidDimensions || viewModel.isProcessing)
                    .padding(.horizontal)
                }

                // Processed Image Info
                if let processed = viewModel.processedImage {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Processed Image")
                                .font(.headline)

                            Spacer()

                            // QuickLook preview button
                            Button {
                                viewModel.showingQuickLook = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill")
                                    Text("Preview")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.green)
                                Text(processed.name)
                                    .lineLimit(1)
                            }

                            HStack {
                                Image(systemName: "aspectratio")
                                Text(processed.dimensionsFormatted)
                            }

                            HStack {
                                Image(systemName: "externaldrive")
                                Text(processed.fileSizeFormatted)

                                if let original = viewModel.selectedImage {
                                    let sizeDiff = original.fileSize - processed.fileSize
                                    let percentChange =
                                        Double(sizeDiff) / Double(original.fileSize) * 100

                                    HStack(spacing: 4) {
                                        if percentChange > 0 {
                                            Text("(\(Int(percentChange))% smaller)")
                                                .foregroundColor(.green)
                                        } else {
                                            Text("(+\(Int(abs(percentChange)))% larger)")
                                                .foregroundColor(.red)

                                            Button {
                                                viewModel.showingSizeIncreaseInfo = true
                                            } label: {
                                                Image(systemName: "info.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.caption)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Export Button
                    Button {
                        viewModel.showingShareSheet = true
                    } label: {
                        Label("Export Image", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Reset Button
                    Button {
                        viewModel.cleanup()
                    } label: {
                        Text("Process Another Image")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    .padding(.top, 8)
                }

                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .fileImporter(
            isPresented: $viewModel.showingFilePicker,
            allowedContentTypes: [.png, .jpeg, .heic, .gif, .bmp, .tiff],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.selectImage(from: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $viewModel.showingShareSheet) {
            if let url = viewModel.getShareURL() {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $viewModel.showingQuickLook) {
            if let url = viewModel.processedImage?.url {
                ImagePreviewSheet(url: url, isPresented: $viewModel.showingQuickLook)
                    .presentationDetents([.fraction(0.85), .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .alert("File Size Increased", isPresented: $viewModel.showingSizeIncreaseInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.getSizeIncreaseExplanation())
        }
        .onChange(of: appState.incomingImageURL) { oldValue, newValue in
            if let url = newValue {
                viewModel.selectImage(from: url)
                appState.incomingImageURL = nil
            }
        }
    }
}

// Drop Zone View for images
struct ImageDropZoneView: View {
    @ObservedObject var viewModel: ImageProcessorViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: isTargeted ? "arrow.up.circle.fill" : "photo.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(isTargeted ? .green : .purple)
                    .frame(width: 50, height: 50)
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)

                Text(isTargeted ? "Drop image here" : "Drop image here")
                    .font(.headline)
                    .foregroundColor(isTargeted ? .green : .primary)
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)

                Text("or")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    viewModel.showingFilePicker = true
                } label: {
                    Text("Browse Files")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isTargeted ? Color.green.opacity(0.1) : Color.purple.opacity(0.05))
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundColor(isTargeted ? .green : .purple.opacity(0.5))
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
            )
            .onDrop(
                of: [.png, .jpeg, .heic, .gif, .bmp, .tiff, .data, .item],
                delegate: ImageDropDelegate(viewModel: viewModel, isTargeted: $isTargeted)
            )
        }
    }
}

// DropDelegate implementation for images
struct ImageDropDelegate: DropDelegate {
    let viewModel: ImageProcessorViewModel
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.png, .jpeg, .heic, .gif, .bmp, .tiff, .data, .item])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false

        guard
            let itemProvider = info.itemProviders(for: [
                .png, .jpeg, .heic, .gif, .bmp, .tiff, .data, .item,
            ]).first
        else {
            return false
        }

        let viewModel = self.viewModel

        // Try different UTTypes for image loading
        let imageTypes: [UTType] = [.png, .jpeg, .heic, .gif, .bmp, .tiff]

        for imageType in imageTypes {
            if itemProvider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                itemProvider.loadFileRepresentation(forTypeIdentifier: imageType.identifier) {
                    url, error in
                    Self.handleDroppedFile(url: url, error: error, viewModel: viewModel)
                }
                return true
            }
        }

        // Fallback to generic file URL
        itemProvider.loadFileRepresentation(forTypeIdentifier: "public.file-url") { url, error in
            Self.handleDroppedFile(url: url, error: error, viewModel: viewModel)
        }

        return true
    }

    private static func handleDroppedFile(
        url: URL?, error: Error?, viewModel: ImageProcessorViewModel
    ) {
        guard let url = url else {
            if let error = error {
                DispatchQueue.main.async {
                    viewModel.errorMessage = "Error loading file: \(error.localizedDescription)"
                }
            }
            return
        }

        // Check if it's an image
        let validExtensions = ["png", "jpg", "jpeg", "heic", "heif", "gif", "bmp", "tiff", "tif"]
        guard validExtensions.contains(url.pathExtension.lowercased()) else {
            DispatchQueue.main.async {
                viewModel.errorMessage = "Please drop a valid image file"
            }
            return
        }

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let originalFilename = url.lastPathComponent
        let filenameWithoutExtension = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        var tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            originalFilename)

        var counter = 1
        while FileManager.default.fileExists(atPath: tempURL.path) {
            let newFilename = "\(filenameWithoutExtension)_\(counter).\(fileExtension)"
            tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(newFilename)
            counter += 1
        }

        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                DispatchQueue.main.async {
                    viewModel.errorMessage = "File not found at the specified location"
                }
                return
            }

            try FileManager.default.copyItem(at: url, to: tempURL)
            DispatchQueue.main.async {
                viewModel.selectImage(from: tempURL)
            }
        } catch {
            DispatchQueue.main.async {
                viewModel.errorMessage = "Failed to load image: \(error.localizedDescription)"
            }
        }
    }
}

// Preset button component
struct PresetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// Image preview sheet with close button and 75% height
struct ImagePreviewSheet: View {
    let url: URL
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            QuickLookView(url: url)
                .navigationTitle("Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
        }
    }
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int)
            -> QLPreviewItem
        {
            return url as QLPreviewItem
        }
    }
}

#Preview {
    ImageToolView()
        .environmentObject(AppState())
}
