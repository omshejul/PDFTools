//
//  PDFToolsApp.swift
//  PDFTools
//
//  Created by Om Shejul on 02/11/25.
//

import Combine
import SwiftUI

@main
struct PDFToolsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
        }
    }
}

// App state to handle shared PDFs and Images
class AppState: ObservableObject {
    @Published var incomingPDFURL: URL?
    @Published var incomingImageURL: URL?

    func handleIncomingURL(_ url: URL) {
        let fileExtension = url.pathExtension.lowercased()

        // Check if it's a PDF file
        if fileExtension == "pdf" {
            handlePDF(url)
            return
        }

        // Check if it's an image file
        let imageExtensions = ["png", "jpg", "jpeg", "heic", "heif", "gif", "bmp", "tiff", "tif"]
        if imageExtensions.contains(fileExtension) {
            handleImage(url)
            return
        }
    }

    private func handlePDF(_ url: URL) {
        // For security-scoped resources, we need to access immediately
        // and copy the file before the access expires
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Copy the file to a temporary location immediately while we have access
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)

            // Remove if exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            // Copy file while we have security-scoped access
            try FileManager.default.copyItem(at: url, to: tempURL)

            // Store the temp URL (no security-scoped access needed)
            incomingPDFURL = tempURL
        } catch {
            // If copying fails, still try with the original URL
            // The ViewModel will handle security-scoped access
            incomingPDFURL = url
        }
    }

    private func handleImage(_ url: URL) {
        // For security-scoped resources, we need to access immediately
        // and copy the file before the access expires
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Copy the file to a temporary location immediately while we have access
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)

            // Remove if exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            // Copy file while we have security-scoped access
            try FileManager.default.copyItem(at: url, to: tempURL)

            // Store the temp URL (no security-scoped access needed)
            incomingImageURL = tempURL
        } catch {
            // If copying fails, still try with the original URL
            // The ViewModel will handle security-scoped access
            incomingImageURL = url
        }
    }
}
