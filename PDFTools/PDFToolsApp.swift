//
//  PDFToolsApp.swift
//  PDFTools
//
//  Created by Om Shejul on 02/11/25.
//

import SwiftUI
import Combine

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

// App state to handle shared PDFs
class AppState: ObservableObject {
    @Published var incomingPDFURL: URL?

    func handleIncomingURL(_ url: URL) {
        // Check if it's a PDF file
        guard url.pathExtension.lowercased() == "pdf" else { return }

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
}
