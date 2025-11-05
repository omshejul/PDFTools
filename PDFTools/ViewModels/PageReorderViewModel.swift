//
//  PageReorderViewModel.swift
//  PDFTools
//
//  Created by Om Shejul on 05/11/25.
//

import Combine
import Foundation
import PDFKit
import SwiftUI

@MainActor
class PageReorderViewModel: ObservableObject {
    @Published var pages: [PDFPageInfo] = []
    @Published var isProcessing = false
    @Published var isLoadingPages = false
    @Published var errorMessage: String?

    private let processor = PDFProcessor()
    private var pdfURL: URL?

    // MARK: - Load Pages

    func loadPages(from pdfInfo: PDFDocumentInfo) async {
        isLoadingPages = true
        errorMessage = nil
        pdfURL = pdfInfo.url

        guard let pdfDocument = PDFDocument(url: pdfInfo.url) else {
            errorMessage = "Failed to load PDF"
            isLoadingPages = false
            return
        }

        let pageCount = pdfDocument.pageCount

        // Generate thumbnails (UIImage creation must be on MainActor in Swift 6)
        var pageArray: [PDFPageInfo] = []

        for pageIndex in 0..<pageCount {
            autoreleasepool {
                guard let page = pdfDocument.page(at: pageIndex) else { return }

                // Generate thumbnail at reasonable size
                let thumbnailSize = CGSize(width: 150, height: 200)
                let thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)

                let pageInfo = PDFPageInfo(
                    pageNumber: pageIndex + 1, // Display as 1-based
                    thumbnail: thumbnail
                )
                pageArray.append(pageInfo)
            }
        }

        pages = pageArray
        isLoadingPages = false
    }

    // MARK: - Reorder Pages

    func movePages(from source: IndexSet, to destination: Int) {
        pages.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Save Reordered PDF

    func saveReorderedPDF() async -> URL? {
        guard let url = pdfURL else {
            errorMessage = "No PDF loaded"
            return nil
        }

        isProcessing = true
        errorMessage = nil

        do {
            // Create page order array (convert back to 0-based indices)
            let pageOrder = pages.map { $0.pageNumber - 1 }

            // Process the PDF with new page order
            let outputURL = try await processor.reorderPages(at: url, pageOrder: pageOrder)

            isProcessing = false
            return outputURL
        } catch {
            errorMessage = "Failed to reorder pages: \(error.localizedDescription)"
            isProcessing = false
            return nil
        }
    }

    // MARK: - Reset

    func resetOrder(from pdfInfo: PDFDocumentInfo) async {
        await loadPages(from: pdfInfo)
    }
}
