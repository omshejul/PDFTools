//
//  PDFDocument.swift
//  PDFTools
//
//  Created by Om Shejul on 02/11/25.
//

import Foundation
import PDFKit

struct PDFDocumentInfo: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let pageCount: Int
    let fileSize: Int64
    let isPasswordProtected: Bool
    let isUnlocked: Bool

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    init?(url: URL, isUnlockedVersion: Bool = false) {
        guard let pdfDoc = PDFDocument(url: url),
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? Int64
        else {
            return nil
        }

        self.url = url
        self.name = url.lastPathComponent
        self.pageCount = pdfDoc.pageCount
        self.fileSize = size
        self.isPasswordProtected = pdfDoc.isLocked
        self.isUnlocked = isUnlockedVersion
    }
}
