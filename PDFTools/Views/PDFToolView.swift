//
//  PDFToolView.swift
//  PDFTools
//
//  Created by Om Shejul on 02/11/25.
//

import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct PDFToolView: View {
    @StateObject private var viewModel = PDFProcessorViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showIncreaseInfo = false
    @State private var showDPIInfo = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("PDF Scaling Tool")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Scale down your PDFs easily")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // Drop Zone or Select PDF Button
                    if viewModel.selectedPDF == nil {
                        DropZoneView(viewModel: viewModel)
                            .padding(.horizontal)
                    }

                    // Selected PDF Info
                    if let pdf = viewModel.selectedPDF {
                        // Use unlocked PDF for display if available
                        let displayPDF = viewModel.unlockedPDF ?? pdf
                        let isOriginalLocked = pdf.isPasswordProtected

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Selected PDF")
                                    .font(.headline)

                                Spacer()

                                // Show lock icon if originally password protected
                                if isOriginalLocked {
                                    if viewModel.unlockedPDF != nil {
                                        Image(systemName: "lock.open.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                    } else {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.orange)
                                            .font(.title3)
                                    }
                                }

                                Button {
                                    viewModel.clearSelectedPDF()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.blue)
                                    Text(displayPDF.name)
                                        .lineLimit(1)
                                }

                                HStack {
                                    Image(systemName: "doc.text")
                                    Text("\(displayPDF.pageCount) pages")
                                }

                                HStack {
                                    Image(systemName: "externaldrive")
                                    Text(displayPDF.fileSizeFormatted)
                                }

                                // Show password protection status
                                if isOriginalLocked {
                                    HStack {
                                        if viewModel.unlockedPDF != nil {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Unlocked - Ready to process")
                                                .foregroundColor(.green)
                                        } else {
                                            Image(systemName: "lock.fill")
                                            Text("Password Protected")
                                        }
                                    }
                                    .foregroundColor(viewModel.unlockedPDF != nil ? .green : .orange)
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

                        // Unlock PDF button if password protected and not yet unlocked
                        if pdf.isPasswordProtected && viewModel.unlockedPDF == nil {
                            Button {
                                viewModel.showingPasswordPrompt = true
                            } label: {
                                Label("Unlock PDF", systemImage: "lock.open.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }

                        // Reorder Pages Button
                        Button {
                            viewModel.showingPageReorder = true
                        } label: {
                            Label("Reorder Pages", systemImage: "square.grid.3x3.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        // Show reordered status
                        if viewModel.reorderedPDF != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Pages reordered")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal)
                        }

                        // Compression Settings
                        VStack(alignment: .leading, spacing: 16) {
                            // Compression Toggle
                            Toggle(isOn: $viewModel.isCompressionEnabled) {
                                HStack {
                                    Image(systemName: "zipper.page")
                                        .foregroundColor(viewModel.isCompressionEnabled ? .green : .secondary)
                                        .font(.title3)
                                    Text("Enable Compression")
                                        .font(.headline)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))

                            // Compression Quality Selector (only if compression is enabled)
                            if viewModel.isCompressionEnabled {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Compression Quality")
                                            .font(.subheadline)
                                    }

                                    // Full-width quality selector menu
                                    Menu {
                                        ForEach(CompressionQuality.allCases, id: \.self) { quality in
                                            Button {
                                                viewModel.compressionQuality = quality
                                            } label: {
                                                Label {
                                                    VStack(alignment: .leading) {
                                                        Text(quality.rawValue)
                                                        Text(quality.description)
                                                            .font(.caption)
                                                    }
                                                } icon: {
                                                    Image(systemName: qualityIcon(for: quality))
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            // Quality icon
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        qualityColor(for: viewModel.compressionQuality)
                                                            .opacity(0.15)
                                                    )
                                                    .frame(width: 44, height: 44)

                                                Image(
                                                    systemName: qualityIcon(
                                                        for: viewModel.compressionQuality)
                                                )
                                                .foregroundColor(
                                                    qualityColor(for: viewModel.compressionQuality)
                                                )
                                                .font(.title3)
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(viewModel.compressionQuality.rawValue)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)

                                                Text(viewModel.compressionQuality.description)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    qualityColor(for: viewModel.compressionQuality)
                                                        .opacity(0.3),
                                                    lineWidth: 1.5
                                                )
                                        )
                                    }

                                    // Custom slider when "Custom" is selected
                                    if viewModel.compressionQuality == .custom {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Quality (higher is less compression)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text("\(Int(viewModel.customQualityValue * 100))%")
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                            }
                                            Slider(
                                                value: Binding(
                                                    get: { Double(viewModel.customQualityValue) },
                                                    set: { viewModel.customQualityValue = CGFloat($0) }
                                                ),
                                                in: 0.0...1.0
                                            )
                                        }
                                        .padding(.horizontal, 4)

                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(spacing: 8) {
                                                Text("DPI")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Button {
                                                    showDPIInfo = true
                                                } label: {
                                                    Image(systemName: "info.circle")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Text("\(Int(viewModel.customDPI))")
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                            }
                                            Slider(
                                                value: Binding(
                                                    get: { Double(viewModel.customDPI) },
                                                    set: { viewModel.customDPI = CGFloat($0) }
                                                ),
                                                in: 50...300
                                            )
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Estimated output size - COMMENTED OUT FOR NOW
                        // if let estimatedSize = viewModel.estimatedSizeString,
                        //     let reduction = viewModel.estimatedReductionPercentage
                        // {
                        //     Divider()
                        //         .padding(.vertical, 4)
                        //
                        //     HStack {
                        //         VStack(alignment: .leading, spacing: 4) {
                        //             Text("Estimated Output Size")
                        //                 .font(.caption)
                        //                 .foregroundColor(.secondary)
                        //             Text(estimatedSize)
                        //                 .font(.subheadline)
                        //                 .fontWeight(.semibold)
                        //                 .foregroundColor(.blue)
                        //         }
                        //
                        //         Spacer()
                        //
                        //         VStack(alignment: .trailing, spacing: 4) {
                        //             Text("Reduction")
                        //                 .font(.caption)
                        //                 .foregroundColor(.secondary)
                        //             Text("~\(reduction)%")
                        //                 .font(.subheadline)
                        //                 .fontWeight(.semibold)
                        //                 .foregroundColor(.green)
                        //         }
                        //     }
                        //
                        //     Text("Note: Text PDFs compress less than image PDFs")
                        //         .font(.caption2)
                        //         .foregroundColor(.orange)
                        //         .padding(.top, 4)
                        // }

                        // Export unlocked PDF button (if unlocked but not compressed)
                        if let unlocked = viewModel.unlockedPDF, viewModel.processedPDF == nil {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Unlocked PDF")
                                        .font(.headline)

                                    Spacer()

                                    Image(systemName: "lock.open.fill")
                                        .foregroundColor(.green)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .foregroundColor(.green)
                                        Text(unlocked.name)
                                            .lineLimit(1)
                                    }

                                    HStack {
                                        Image(systemName: "externaldrive")
                                        Text(unlocked.fileSizeFormatted)
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

                            Button {
                                viewModel.showingShareSheet = true
                            } label: {
                                Label("Export Unlocked PDF", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }

                        // Process Button
                        Button {
                            Task {
                                await viewModel.processPDF()
                            }
                        } label: {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if viewModel.isCompressionEnabled {
                                Label("Compress PDF", systemImage: "arrow.down.circle.fill")
                                    .font(.headline)
                            } else {
                                Label("Process PDF", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isProcessing ? Color.gray : Color.green)
                        .cornerRadius(12)
                        .disabled(viewModel.isProcessing)
                        .padding(.horizontal)
                    }

                    // Processed PDF Info
                    if let processed = viewModel.processedPDF {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Processed PDF")
                                    .font(.headline)

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.green)
                                    Text(processed.name)
                                        .lineLimit(1)
                                }

                                HStack {
                                    Image(systemName: "externaldrive")
                                    Text(processed.fileSizeFormatted)

                                    if let original = viewModel.selectedPDF {
                                        let sizeDiff = original.fileSize - processed.fileSize
                                        let reduction = Double(sizeDiff) / Double(original.fileSize) * 100
                                        if reduction >= 0 {
                                            Text("(\(Int(reduction))% smaller)")
                                                .foregroundColor(.green)
                                        } else {
                                            HStack(spacing: 6) {
                                                Text("(\(Int(abs(reduction)))% larger)")
                                                    .foregroundColor(.red)
                                                Button {
                                                    showIncreaseInfo = true
                                                } label: {
                                                    Image(systemName: "info.circle")
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            // QuickLook Preview and Export Buttons
                            HStack(spacing: 12) {
                                // QuickLook preview button
                                Button {
                                    viewModel.showingQuickLook = true
                                } label: {
                                    Label("Preview", systemImage: "eye.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .cornerRadius(12)
                                }

                                // Export Button
                                Button {
                                    viewModel.showingShareSheet = true
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Reset Button
                        Button {
                            viewModel.cleanup()
                        } label: {
                            Text("Process Another PDF")
                                .font(.subheadline)
                                .foregroundColor(.blue)
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
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.selectPDF(from: url)
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
                if let url = viewModel.processedPDF?.url {
                    PDFPreviewSheet(url: url, isPresented: $viewModel.showingQuickLook)
                }
            }
            .sheet(isPresented: $viewModel.showingPageReorder) {
                // Use unlocked PDF if available, otherwise use selected PDF
                if let pdf = viewModel.unlockedPDF ?? viewModel.selectedPDF {
                    PageReorderView(pdfInfo: pdf) { reorderedURL in
                        viewModel.handleReorderedPDF(url: reorderedURL)
                    }
                }
            }
            .onChange(of: appState.incomingPDFURL) { _, newValue in
                if let url = newValue {
                    viewModel.selectPDF(from: url)
                    // Clear the incoming URL after handling
                    appState.incomingPDFURL = nil
                }
            }
            .alert("Enter PDF Password", isPresented: $viewModel.showingPasswordPrompt) {
                SecureField("Password", text: $viewModel.passwordInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Unlock") {
                    Task {
                        await viewModel.unlockPDF(with: viewModel.passwordInput)
                    }
                }

                Button("Cancel", role: .cancel) {
                    viewModel.passwordInput = ""
                }
            } message: {
                Text("This PDF is password protected. Please enter the password to unlock it.")
            }
        }
        .alert("File Size Increased", isPresented: $showIncreaseInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "The processed file is larger than the original. This can happen when:\n\n• The original PDF was already well-compressed\n• Text and vector graphics were converted to images\n• Black and white scans were saved as color JPEG\n• Metadata or color profile changes added overhead\n\nTo reduce size, try lowering the quality setting or keep the original file if it's already optimized."
            )
        }
        .alert("About DPI Settings", isPresented: $showDPIInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "DPI (Dots Per Inch) determines the resolution when converting PDF pages to images. Higher DPI creates sharper images but larger files, while lower DPI reduces file size but may blur fine details.\n\nRecommended settings:\n• 100-150 DPI: General sharing and viewing\n• 200-300 DPI: Print quality with readable text\n• 72-100 DPI: Maximum compression"
            )
        }
    }

    // MARK: - Helper Functions

    func qualityColor(for quality: CompressionQuality) -> Color {
        switch quality {
        case .best:
            return .green
        case .high:
            return .blue
        case .medium:
            return .orange
        case .low:
            return .red
        case .veryLow:
            return .purple
        case .minimum:
            return .pink
        case .custom:
            return .teal
        }
    }

    func qualityIcon(for quality: CompressionQuality) -> String {
        switch quality {
        case .best:
            return "star.fill"
        case .high:
            return "checkmark.seal.fill"
        case .medium:
            return "arrow.down.circle.fill"
        case .low:
            return "arrow.down.to.line"
        case .veryLow:
            return "arrow.down.to.line.compact"
        case .minimum:
            return "flame.fill"
        case .custom:
            return "slider.horizontal.3"
        }
    }
}

// Drop Zone View for drag and drop
struct DropZoneView: View {
    @ObservedObject var viewModel: PDFProcessorViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            // Drop zone area
            VStack(spacing: 12) {
                Image(systemName: isTargeted ? "arrow.up.circle.fill" : "doc.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(isTargeted ? .green : .blue)
                    .frame(width: 50, height: 50)  // Fixed size to prevent layout shifts
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)

                Text(isTargeted ? "Drop PDF here" : "Drop PDF here")
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
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isTargeted ? Color.green.opacity(0.1) : Color.blue.opacity(0.05))
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundColor(isTargeted ? .green : .blue.opacity(0.5))
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
            )
            .onDrop(
                of: [.pdf, .data, .item],
                delegate: PDFDropDelegate(viewModel: viewModel, isTargeted: $isTargeted))
        }
    }

}

// DropDelegate implementation for iOS 18 compatibility
struct PDFDropDelegate: DropDelegate {
    let viewModel: PDFProcessorViewModel
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.pdf, .data, .item])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false

        guard let itemProvider = info.itemProviders(for: [.pdf, .data, .item]).first else {
            return false
        }

        // Capture viewModel for use in closures
        let viewModel = self.viewModel

        // Try to load as PDF first, then fall back to file URL
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, error in
                Self.handleDroppedFile(url: url, error: error, viewModel: viewModel)
            }
        } else {
            // Fall back to loading as file URL
            itemProvider.loadFileRepresentation(forTypeIdentifier: "public.file-url") { url, error in
                Self.handleDroppedFile(url: url, error: error, viewModel: viewModel)
            }
        }

        return true
    }

    private static func handleDroppedFile(
        url: URL?, error: Error?, viewModel: PDFProcessorViewModel
    ) {
        guard let url = url else {
            if let error = error {
                DispatchQueue.main.async {
                    viewModel.errorMessage = "Error loading file: \(error.localizedDescription)"
                }
            }
            return
        }

        // Check if it's a PDF
        guard url.pathExtension.lowercased() == "pdf" else {
            DispatchQueue.main.async {
                viewModel.errorMessage = "Please drop a valid PDF file"
            }
            return
        }

        // Try to access security-scoped resource if needed (may not be required for all URLs)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Extract original filename
        let originalFilename = url.lastPathComponent
        let filenameWithoutExtension = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        // Create a safe filename (handle collisions by appending number if needed)
        var tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(originalFilename)

        // Handle filename collisions by appending a number
        var counter = 1
        while FileManager.default.fileExists(atPath: tempURL.path) {
            let newFilename = "\(filenameWithoutExtension)_\(counter).\(fileExtension)"
            tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(newFilename)
            counter += 1
        }

        do {
            // Ensure the file exists and is readable
            guard FileManager.default.fileExists(atPath: url.path) else {
                DispatchQueue.main.async {
                    viewModel.errorMessage = "File not found at the specified location"
                }
                return
            }

            try FileManager.default.copyItem(at: url, to: tempURL)
            DispatchQueue.main.async {
                viewModel.selectPDF(from: tempURL)
            }
        } catch {
            DispatchQueue.main.async {
                viewModel.errorMessage = "Failed to load PDF: \(error.localizedDescription)"
            }
        }
    }
}

// Share Sheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// PDF Preview Sheet with QuickLook
struct PDFPreviewSheet: View {
    let url: URL
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            PDFQuickLookView(url: url)
                .navigationTitle("PDF Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}

// QuickLook view for PDF preview
struct PDFQuickLookView: UIViewControllerRepresentable {
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
    PDFToolView()
        .environmentObject(AppState())
}
