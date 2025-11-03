//
//  ContentView.swift
//  PDFTools
//
//  Created by Om Shejul on 03/11/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PDFToolView()
                .tabItem {
                    Label("PDF", systemImage: "doc.text.fill")
                }
                .tag(0)

            ImageToolView()
                .tabItem {
                    Label("Image", systemImage: "photo.fill")
                }
                .tag(1)
        }
        .onChange(of: appState.incomingPDFURL) { oldValue, newValue in
            if newValue != nil {
                selectedTab = 0  // Switch to PDF tab
            }
        }
        .onChange(of: appState.incomingImageURL) { oldValue, newValue in
            if newValue != nil {
                selectedTab = 1  // Switch to Image tab
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
