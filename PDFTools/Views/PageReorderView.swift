//
//  PageReorderView.swift
//  PDFTools
//
//  Created by Om Shejul on 05/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct PageReorderView: View {
    @StateObject private var viewModel = PageReorderViewModel()
    @Environment(\.dismiss) private var dismiss

    let pdfInfo: PDFDocumentInfo
    let onSave: (URL) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoadingPages {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading pages...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.pages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No pages found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Instructions
                        HStack {
                            Image(systemName: "hand.draw.fill")
                                .foregroundColor(.blue)
                            Text("Drag to reorder pages")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))

                        // List view with native drag and drop
                        List {
                            ForEach(viewModel.pages) { page in
                                PageThumbnailRowView(page: page)
                            }
                            .onMove(perform: viewModel.movePages)
                        }
                        .listStyle(.plain)
                        .environment(\.editMode, .constant(.active))
                    }

                    // Save Button (Fixed at bottom)
                    VStack {
                        Spacer()

                        VStack(spacing: 12) {
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    Task {
                                        await viewModel.resetOrder(from: pdfInfo)
                                    }
                                } label: {
                                    Label("Reset", systemImage: "arrow.counterclockwise")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                                .disabled(viewModel.isProcessing)

                                Button {
                                    Task {
                                        if let reorderedURL = await viewModel.saveReorderedPDF() {
                                            onSave(reorderedURL)
                                            dismiss()
                                        }
                                    }
                                } label: {
                                    if viewModel.isProcessing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Label("Save Order", systemImage: "checkmark.circle.fill")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.isProcessing ? Color.gray : Color.green)
                                .cornerRadius(12)
                                .disabled(viewModel.isProcessing)
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                        .background(
                            Color(.systemBackground)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                        )
                    }
                }
            }
            .navigationTitle("Reorder Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadPages(from: pdfInfo)
            }
        }
    }
}

// MARK: - Page Thumbnail Row View (for List)

struct PageThumbnailRowView: View {
    let page: PDFPageInfo

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Image(uiImage: page.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 80)
                .background(Color(.systemGray6))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

            // Page Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Page \(page.pageNumber)")
                    .font(.headline)

                Text("Drag to reorder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
       let pdfInfo = PDFDocumentInfo(url: url) {
        PageReorderView(pdfInfo: pdfInfo) { _ in }
    } else {
        Text("Preview not available")
    }
}
