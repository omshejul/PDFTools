# PDFTools - iOS PDF & Image Processing App

## Project Overview

PDFTools is an iOS application built with SwiftUI that allows users to compress PDF files and downscale images with various quality settings. The app provides drag-and-drop functionality, file picker integration, and share-to-app capabilities for seamless file processing.

**Platform:** iOS 26+  
**Language:** Swift  
**Framework:** SwiftUI  
**Architecture:** MVVM (Model-View-ViewModel)

---

## Features

### PDF Tool

1. **PDF Page Reordering (NEW)** - Drag-and-drop interface to reorder PDF pages before processing
2. **Compression Toggle (NEW)** - Enable/disable compression (keeps original quality when off)
3. **PDF Compression** - Converts PDF pages to JPEG images with configurable quality
4. **Quality Selection** - 6 compression levels from Best to Minimum quality
5. **Password Unlock** - Unlock password-protected PDFs
6. **Drag and Drop** - Drop PDFs directly from Files app
7. **File Picker** - Traditional file selection interface
8. **Share to App** - Open PDFs from other apps via iOS share sheet
9. **Visual Feedback** - Real-time compression progress and file size comparison

### Image Tool (NEW)

1. **Image Downscaling** - Resize images to specific dimensions while preserving aspect ratio
2. **Custom Dimensions** - Enter custom width/height with auto-calculation
3. **Smart Quick Presets** - One-tap max dimension presets (1920px, 1280px, etc.) that auto-calculate the other dimension
4. **Aspect Ratio Lock** - Automatically maintains aspect ratio when adjusting dimensions
5. **Quality Control** - Adjustable output quality slider (10%-100%)
6. **Format Support** - Supports PNG, JPG, HEIC, GIF, BMP, TIFF
7. **QuickLook Preview** - Preview processed images before exporting
8. **Drag and Drop** - Drop images directly from Files app
9. **Share to App** - Open images from other apps via iOS share sheet

### Compression Quality Levels

| Level    | JPEG Quality | Resolution (DPI) | Estimated Reduction |
| -------- | ------------ | ---------------- | ------------------- |
| Best     | 90%          | 300              | 15%                 |
| High     | 70%          | 200              | 35%                 |
| Medium   | 50%          | 150              | 50%                 |
| Low      | 30%          | 100              | 70%                 |
| Very Low | 15%          | 72               | 80%                 |
| Minimum  | 5%           | 50               | 85%                 |

---

## Project Structure

```
PDFTools/
├── PDFToolsApp.swift           # App entry point, handles incoming URLs
├── ContentView.swift            # Main tab view (PDF & Image tabs)
├── Models/
│   ├── PDFDocument.swift       # PDF metadata model
│   ├── PDFPageInfo.swift       # PDF page model for reordering (NEW)
│   ├── ImageInfo.swift         # Image metadata model (NEW)
│   └── CompressionQuality.swift # Quality level enum
├── ViewModels/
│   ├── PDFProcessorViewModel.swift  # PDF business logic and state management
│   ├── PageReorderViewModel.swift   # Page reordering logic (NEW)
│   └── ImageProcessorViewModel.swift # Image business logic and state management (NEW)
├── Services/
│   ├── PDFProcessor.swift      # PDF compression & reordering engine
│   └── ImageProcessor.swift    # Image resizing engine (NEW)
├── Views/
│   ├── PDFToolView.swift       # PDF compression interface
│   ├── PageReorderView.swift   # Page reordering interface (NEW)
│   └── ImageToolView.swift     # Image resizing interface (NEW)
└── Utilities/
    └── FileManager+Extensions.swift # File utility extensions
```

---

## Architecture Details

### MVVM Pattern

**Model (`PDFInfo`, `CompressionQuality`)**

- Defines data structures for PDF metadata and compression settings
- Sendable conformance for Swift 6 concurrency

**View (`ContentView`, `DropZoneView`, `PDFDropDelegate`)**

- SwiftUI views for UI rendering
- Handles user interactions and visual feedback
- iOS 18-compatible drag-and-drop implementation

**ViewModel (`PDFProcessorViewModel`)**

- Manages app state and user interactions
- Coordinates between UI and PDF processing service
- Handles file selection, compression triggering, and error management

---

## Key Technical Implementation

### 1. PDF Compression Algorithm

iOS doesn't have native PDF compression like macOS Quartz filters. The solution:

```swift
func compressPDFWithFilter(at url: URL, quality: CompressionQuality) async throws -> URL {
    // 1. Render each PDF page to bitmap at specified DPI
    let scale = dpi / 72.0
    let renderSize = CGSize(width: pageRect.width * scale,
                           height: pageRect.height * scale)

    // 2. Create bitmap context
    UIGraphicsBeginImageContextWithOptions(renderSize, false, 1.0)

    // 3. Draw PDF page to context
    context.drawPDFPage(page)

    // 4. Compress to JPEG with quality parameter
    let options: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: jpegQuality
    ]

    // 5. Add compressed image to new PDF
    CGImageDestinationAddImage(imageDestination, cgImage, options as CFDictionary)
}
```

**Trade-offs:**

- ✅ Actually reduces file size (unlike simple scaling)
- ✅ Works on iOS (no macOS-only APIs)
- ❌ Text becomes non-searchable (rasterized)
- ❌ Vector graphics become bitmaps

### 2. Drag and Drop (iOS 18 Compatible)

**Problem:** iOS 18 changed `onDrop` behavior with closures  
**Solution:** Use `DropDelegate` protocol instead

```swift
struct PDFDropDelegate: DropDelegate {
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.fileURL])
    }

    func performDrop(info: DropInfo) -> Bool {
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, error in
            // iOS provides temporary URL - must copy to permanent location
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")
            try FileManager.default.copyItem(at: url, to: tempURL)
            viewModel.selectPDF(from: tempURL)
        }
        return true
    }
}
```

**Key Points:**

- Use `loadFileRepresentation` instead of `loadObject` for iOS 18
- Temporary URLs from drop must be copied immediately
- `DropDelegate` more reliable than closure-based `onDrop` on iOS 18

### 3. Share to App Integration

**Configuration Required:** Add to Xcode target Info settings

```json
{
  "CFBundleDocumentTypes": [
    {
      "CFBundleTypeName": "PDF Document",
      "CFBundleTypeRole": "Editor",
      "LSHandlerRank": "Alternate",
      "LSItemContentTypes": ["com.adobe.pdf"]
    }
  ]
}
```

**App Implementation:**

```swift
// PDFToolsApp.swift
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

// AppState handles incoming PDFs
class AppState: ObservableObject {
    @Published var incomingPDFURL: URL?

    func handleIncomingURL(_ url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else { return }
        incomingPDFURL = url
    }
}
```

### 4. Swift 6 Concurrency & Actor Isolation

**Issues Encountered:**

- Main actor-isolated properties accessed from non-isolated context
- `Task.detached` blocks can't access `@MainActor` properties directly

**Solution:** Extract properties before `Task.detached`

```swift
func processPDF() async {
    // Extract main-actor properties BEFORE Task.detached
    let jpegQuality = quality.compressionValue
    let dpi = quality.resolutionDPI

    return try await Task.detached {
        // Now can use jpegQuality and dpi safely
        // without accessing main-actor properties
    }.value
}
```

### 5. Image Resizing with Aspect Ratio Preservation (NEW)

The app now includes a separate tool for downscaling images while preserving their aspect ratio.

**Key Implementation:**

```swift
// ImageProcessor.swift
func resizeImage(at url: URL, targetWidth: Int, targetHeight: Int, quality: CGFloat) async throws -> URL {
    // Load image using CGImageSource
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        throw ImageProcessorError.invalidImage
    }
    
    // Create bitmap context for resizing
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: targetWidth,
        height: targetHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ImageProcessorError.processingFailed
    }
    
    // Set high quality interpolation
    context.interpolationQuality = .high
    
    // Draw resized image
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
    
    // Save with specified quality
    guard let resizedCGImage = context.makeImage() else {
        throw ImageProcessorError.processingFailed
    }
    
    // Save to file with quality settings
    let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, outputFormat, 1, nil)
    CGImageDestinationAddImage(destination, resizedCGImage, options as CFDictionary)
    CGImageDestinationFinalize(destination)
}
```

**Auto-Calculation Logic:**

```swift
// ImageProcessorViewModel.swift
func updateWidth(_ newWidth: String) {
    targetWidthString = newWidth
    
    // Auto-calculate height to preserve aspect ratio
    if let width = Int(newWidth),
       width > 0,
       let image = selectedImage {
        // Clamp width to original dimensions (prevent upscaling)
        let clampedWidth = min(width, image.width)
        
        // Update width if it was clamped
        if clampedWidth != width {
            targetWidthString = String(clampedWidth)
        }
        
        let newHeight = processor.calculateHeight(fromWidth: clampedWidth, aspectRatio: image.aspectRatio)
        targetHeightString = String(newHeight)
    }
}

func updateHeight(_ newHeight: String) {
    targetHeightString = newHeight
    
    // Auto-calculate width to preserve aspect ratio
    if let height = Int(newHeight),
       height > 0,
       let image = selectedImage {
        // Clamp height to original dimensions (prevent upscaling)
        let clampedHeight = min(height, image.height)
        
        // Update height if it was clamped
        if clampedHeight != height {
            targetHeightString = String(clampedHeight)
        }
        
        let newWidth = processor.calculateWidth(fromHeight: clampedHeight, aspectRatio: image.aspectRatio)
        targetWidthString = String(newWidth)
    }
}
```

**Supported Input Formats:**
- PNG, JPEG/JPG, HEIC/HEIF, GIF, BMP, TIFF

**Output Format Logic:**
- **Quality at 100%:** Keeps original format (PNG → PNG, JPEG → JPEG, etc.)
- **Quality < 100%:** Converts to JPEG for lossy compression (enables file size reduction for all formats)

This means:
- PNG/BMP/TIFF files can be compressed by reducing quality (auto-converts to JPEG)
- Same dimensions with quality < 100% still reduces file size
- Quality slider is effective for all input formats

**Features:**
- Automatic aspect ratio preservation
- **EXIF orientation handling** - correctly rotates images from camera
- Custom width/height inputs with live updates
- **Automatic dimension clamping** - prevents entering values larger than original
- Maximum dimension hints displayed in UI
- **Smart quick presets** - constrains longest side, calculates other dimension (1920px, 1280px, 800px, 640px)
- Quality slider (10% to 100%)
- Smart format conversion for compression
- **QuickLook preview** - view processed images before exporting
- Prevents upscaling (only downscales)
- Visual feedback with before/after comparison
- Format conversion indicator in UI

### 6. iOS 18 API Updates

**Deprecated:** `onChange(of:perform:)` with single parameter

```swift
// ❌ Old (iOS 17 and below)
.onChange(of: appState.incomingPDFURL) { newURL in
    // handle change
}

// ✅ New (iOS 18+)
.onChange(of: appState.incomingPDFURL) { oldValue, newValue in
    // handle change with both old and new values
}
```

**Removed:** `StrokedBorderShapeStyle` doesn't exist

```swift
// ❌ Incorrect
.strokeBorder(style: StrokedBorderShapeStyle(lineWidth: 2, dash: [8, 4]))

// ✅ Correct
.strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
```

### 7. PDF Page Reordering (NEW - November 5, 2025)

**Feature:** Drag-and-drop interface to reorder PDF pages before compression or processing.

**Key Implementation:**

```swift
// PageReorderViewModel.swift
func loadPages(from pdfInfo: PDFDocumentInfo) async {
    guard let pdfDocument = PDFDocument(url: pdfInfo.url) else { return }
    let pageCount = pdfDocument.pageCount
    
    // Generate thumbnails (UIImage must be on MainActor in Swift 6)
    var pageArray: [PDFPageInfo] = []
    for pageIndex in 0..<pageCount {
        autoreleasepool {
            guard let page = pdfDocument.page(at: pageIndex) else { return }
            let thumbnailSize = CGSize(width: 150, height: 200)
            let thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
            let pageInfo = PDFPageInfo(pageNumber: pageIndex + 1, thumbnail: thumbnail)
            pageArray.append(pageInfo)
        }
    }
    pages = pageArray
}

// PDFProcessor.swift
func reorderPages(at url: URL, pageOrder: [Int]) async throws -> URL {
    guard let pdfDocument = PDFDocument(url: url) else {
        throw PDFProcessorError.invalidPDF
    }
    
    let newDocument = PDFDocument()
    for (newIndex, originalIndex) in pageOrder.enumerated() {
        autoreleasepool {
            guard let page = pdfDocument.page(at: originalIndex) else { return }
            newDocument.insert(page, at: newIndex)
        }
    }
    
    guard newDocument.write(to: outputURL) else {
        throw PDFProcessorError.saveFailed
    }
    return outputURL
}
```

**UI Implementation:**
- Native iOS List with `.onMove()` modifier for drag-and-drop
- `.environment(\.editMode, .constant(.active))` keeps list in edit mode
- Thumbnails shown with page numbers
- Reset button to restore original order
- Save button generates reordered PDF

**Workflow:**
1. User imports PDF
2. Taps "Reorder Pages" button (purple)
3. Drags handle (≡) to reorder pages
4. Taps "Save Order" to generate reordered PDF
5. Can then optionally compress the reordered PDF

### 8. Compression Toggle (NEW - November 5, 2025)

**Feature:** Toggle switch to enable/disable compression (keeps original PDF quality when disabled).

**Key Implementation:**

```swift
// PDFProcessorViewModel.swift
@Published var isCompressionEnabled = true  // ON by default

func processPDF() async {
    let pdfToProcess = reorderedPDF ?? unlockedPDF ?? selectedPDF
    guard let pdf = pdfToProcess else { return }
    
    let outputURL: URL
    if isCompressionEnabled {
        // Apply JPEG compression with selected quality
        outputURL = try await processor.compressPDFWithFilter(at: pdf.url, quality: compressionQuality)
    } else {
        // No compression - just copy the file
        outputURL = try await processor.copyPDFWithoutCompression(at: pdf.url)
    }
}

// PDFProcessor.swift
func copyPDFWithoutCompression(at url: URL) async throws -> URL {
    guard let pdfDocument = PDFDocument(url: url) else {
        throw PDFProcessorError.invalidPDF
    }
    
    // Simply write the PDF as-is without any modifications
    guard pdfDocument.write(to: outputURL) else {
        throw PDFProcessorError.saveFailed
    }
    return outputURL
}
```

**UI Features:**
- Toggle switch with green tint when enabled
- Icon changes: "compress" (ON) vs "doc.text" (OFF)
- Compression quality selector only visible when toggle is ON
- Button text changes: "Compress PDF" vs "Process PDF"
- Default state: ON (compression enabled)

**Use Cases:**
- **Compression ON:** Reduce file size with quality control
- **Compression OFF:** Keep original quality (useful after page reordering only)

---

## Code Organization

### Models

#### `PDFDocument.swift`

```swift
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
}
```

#### `PDFPageInfo.swift` (NEW)

```swift
struct PDFPageInfo: Identifiable, Sendable {
    let id = UUID()
    let pageNumber: Int
    let thumbnail: UIImage
    
    init(pageNumber: Int, thumbnail: UIImage) {
        self.pageNumber = pageNumber
        self.thumbnail = thumbnail
    }
}
```

#### `ImageInfo.swift` (NEW)

```swift
struct ImageInfo: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let url: URL
    let width: Int
    let height: Int
    let fileSize: Int64
    
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var dimensionsFormatted: String {
        "\(width) × \(height) px"
    }
    
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }
}
```

#### `CompressionQuality.swift`

```swift
enum CompressionQuality: String, CaseIterable, Sendable {
    case best = "Best Quality"
    case high = "High Quality"
    case medium = "Medium Quality"
    case low = "Low Quality"
    case veryLow = "Very Low Quality"
    case minimum = "Minimum Quality"

    var compressionValue: CGFloat {
        switch self {
        case .best: return 0.9
        case .high: return 0.7
        case .medium: return 0.5
        case .low: return 0.3
        case .veryLow: return 0.15
        case .minimum: return 0.05
        }
    }

    var resolutionDPI: CGFloat {
        switch self {
        case .best: return 300
        case .high: return 200
        case .medium: return 150
        case .low: return 100
        case .veryLow: return 72
        case .minimum: return 50
        }
    }
}
```

### ViewModels

#### `PDFProcessorViewModel.swift`

```swift
@MainActor
class PDFProcessorViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var selectedPDF: PDFDocumentInfo?
    @Published var processedPDF: PDFDocumentInfo?
    @Published var compressionQuality: CompressionQuality = .medium
    @Published var isCompressionEnabled = true  // NEW: Compression toggle
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showingFilePicker = false
    @Published var showingShareSheet = false
    @Published var showingPasswordPrompt = false
    @Published var passwordInput = ""
    @Published var unlockedPDF: PDFDocumentInfo?
    
    // NEW: Page reordering properties
    @Published var showingPageReorder = false
    @Published var reorderedPDF: PDFDocumentInfo?

    private let processor = PDFProcessor()

    func selectPDF(from url: URL) { /* ... */ }
    func processPDF() async { /* ... */ }
    func unlockPDF(with password: String) async { /* ... */ }
    func handleReorderedPDF(url: URL) { /* ... */ }  // NEW
    func cleanup() { /* ... */ }
}
```

#### `PageReorderViewModel.swift` (NEW)

```swift
@MainActor
class PageReorderViewModel: ObservableObject {
    @Published var pages: [PDFPageInfo] = []
    @Published var isProcessing = false
    @Published var isLoadingPages = false
    @Published var errorMessage: String?
    
    private let processor = PDFProcessor()
    private var pdfURL: URL?
    
    func loadPages(from pdfInfo: PDFDocumentInfo) async { /* ... */ }
    func movePages(from source: IndexSet, to destination: Int) { /* ... */ }
    func saveReorderedPDF() async -> URL? { /* ... */ }
    func resetOrder(from pdfInfo: PDFDocumentInfo) async { /* ... */ }
}
```

#### `ImageProcessorViewModel.swift` (NEW)

```swift
@MainActor
class ImageProcessorViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var selectedImage: ImageInfo?
    @Published var processedImage: ImageInfo?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showingFilePicker = false
    @Published var showingShareSheet = false
    
    // Dimension inputs
    @Published var targetWidthString: String = ""
    @Published var targetHeightString: String = ""
    @Published var outputQuality: CGFloat = 0.9
    
    private let processor = ImageProcessor()
    
    func selectImage(from url: URL) { /* ... */ }
    func updateWidth(_ newWidth: String) { /* Auto-calculates height */ }
    func updateHeight(_ newHeight: String) { /* Auto-calculates width */ }
    func processImage() async { /* ... */ }
    func resetToOriginalDimensions() { /* ... */ }
    func setCommonPreset(width: Int, height: Int) { /* ... */ }
    func cleanup() { /* ... */ }
}
```

### Services

#### `PDFProcessor.swift`

Core PDF processing logic:

- **Compression**: Renders PDF pages to images at specified DPI, compresses with JPEG quality settings
- **Page Reordering (NEW)**: Reorders pages using PDFKit's `insert(_:at:)` method
- **Copy Without Compression (NEW)**: Preserves original PDF quality when compression is disabled
- **Password Unlocking**: Unlocks password-protected PDFs
- Uses `PDFDocument`, `CGContext`, `CGImageDestination`, and `PDFKit`

Key Methods:
- `compressPDFWithFilter(at:quality:)` - Compresses PDF with JPEG
- `reorderPages(at:pageOrder:)` - Reorders pages (NEW)
- `copyPDFWithoutCompression(at:)` - Copies without compression (NEW)
- `removePassword(from:password:)` - Unlocks protected PDFs

#### `ImageProcessor.swift` (NEW)

Core image resizing logic:

- Loads images using `CGImageSource`
- Resizes images with high-quality interpolation
- Preserves aspect ratio calculations
- Supports multiple image formats (PNG, JPG, HEIC, GIF, BMP, TIFF)
- Prevents upscaling (only downscales)
- Configurable output quality
- Uses `CGContext` and `CGImageDestination`

### Views

#### `ContentView.swift`

Main tab view:

- TabView with two tabs: PDF and Image
- Automatic tab switching when files are shared to the app
- Passes AppState to both tool views via environment object

#### `PDFToolView.swift`

PDF compression interface:

- Header with app branding
- Drop zone or file picker (when no PDF selected)
- PDF info card (selected file details)
- Password unlock prompt for protected PDFs
- **Reorder Pages button (NEW)** - Opens page reordering interface
- **Compression toggle (NEW)** - Enable/disable compression
- Quality selector (full-width menu with icons) - Only visible when compression enabled
- Process/Compress button with progress indicator (text changes based on toggle state)
- Processed PDF card with size comparison
- Export and reset buttons
- Integrates with `PDFDropDelegate`

#### `ImageToolView.swift` (NEW)

Image resizing interface:

- Header with app branding
- Drop zone or file picker (when no image selected)
- Image info card (dimensions, file size)
- Custom width/height input fields with auto-calculation
- Aspect ratio lock indicator
- Smart preset buttons (Original, 1920px, 1280px, 800px, 640px) - constrains longest side
- Quality slider (10%-100%) with format conversion indicator
- Resize button with progress indicator
- Processed image card with size comparison
- **QuickLook preview button** - opens native iOS preview
- Export and reset buttons
- Integrates with `ImageDropDelegate`

#### Drop Delegates

**`PDFDropDelegate`** - iOS 18-compatible PDF drop handling:
- Validates dropped items are PDF files
- Manages drop target state
- Loads and copies dropped PDFs
- Handles errors gracefully

**`ImageDropDelegate`** (NEW) - iOS 18-compatible image drop handling:
- Validates dropped items are image files
- Supports PNG, JPG, HEIC, GIF, BMP, TIFF formats
- Manages drop target state
- Loads and copies dropped images
- Handles errors gracefully

---

## Build & Run

### Requirements

- Xcode 16+
- iOS 18.0+ SDK
- Swift 6.0+

### Build Steps

```bash
cd /Users/omshejul/SavedMain/Xcode/PDFTools
xcodebuild -scheme PDFTools -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Running the App

1. Open `PDFTools.xcodeproj` in Xcode
2. Select target device/simulator
3. Press Cmd+R to build and run

---

## Configuration

### Info.plist Settings (Required for Share to App)

To enable sharing PDFs and images from other apps:

1. Open Xcode → PDFTools target → Info tab
2. Add Document Types:

   **PDF Document:**
   - **Name:** PDF Document
   - **Types:** com.adobe.pdf
   - **Role:** Editor
   - **Handler Rank:** Alternate

   **Image Files (NEW):**
   - **Name:** Image Files
   - **Types:** public.png, public.jpeg, public.heic, public.gif, public.bmp, public.tiff
   - **Role:** Editor
   - **Handler Rank:** Alternate

3. Add Custom Properties:
   - **UISupportsDocumentBrowser:** YES
   - **LSSupportsOpeningDocumentsInPlace:** YES

**Note:** These settings are NOT in a manual Info.plist file (causes build conflicts). Configure via Xcode's GUI.

---

## Known Issues & Solutions

### 1. Build Error: Multiple Info.plist

**Error:** `duplicate output file Info.plist`  
**Cause:** Manual Info.plist conflicts with auto-generated one  
**Solution:** Delete manual Info.plist, configure via Xcode target settings

### 2. Drag and Drop Not Working

**Error:** Prohibited symbol instead of plus icon  
**Cause:** iOS 18 changed onDrop behavior  
**Solution:** Use `DropDelegate` protocol with `loadFileRepresentation`

### 3. onChange Deprecation Warning

**Error:** `onChange(of:perform:)` deprecated in iOS 17  
**Solution:** Use two-parameter version: `onChange(of:) { oldValue, newValue in }`

### 4. Swift 6 Actor Isolation Errors

**Error:** Main actor-isolated property accessed from nonisolated context  
**Solution:** Extract properties before `Task.detached` block

### 5. File Size Increase After Compression (PDF)

**Issue:** Text PDFs become larger when compressed  
**Cause:** Rasterization creates larger files for vector content  
**Solution:** Lower DPI/quality for text PDFs, or skip compression

### 6. Image File Size Increase After Processing (CRITICAL)

**Issue:** Images sometimes become MUCH larger despite reducing dimensions

**Example:**
```
Original: 1500×1030px @ 115 KB (JPEG at ~50% quality)
Resized:  640×439px @ 339 KB (JPEG at 90% quality)
Result:   3x LARGER! 😱
```

**Cause:** **Original JPEG quality vs. Output quality mismatch**

The original image was heavily compressed (low quality ~50%). When you resize it at 90% quality, you're applying LESS compression than the original, resulting in a larger file despite fewer pixels.

**How it works:**
1. Original heavily compressed (0.3 bytes/pixel) = small file
2. App decompresses to raw pixels
3. App resizes with high-quality interpolation
4. App recompresses at 90% quality (1.2 bytes/pixel) = large file

**Solution:** 
- **Check compression indicator** - App shows "Heavily compressed (quality ~50-70%)" for original
- **Match or lower quality** - If original is 50%, set output to 50% or less
- **Use warning system** - App warns: "Original is heavily compressed. Try lowering quality to 70% or less"
- **Rule of thumb:** For heavily compressed JPEGs, use quality 60-70% or lower

**Additional causes:**
- **PNG recompression:** iOS doesn't optimize as well as specialized tools
- **Same dimensions + 100% quality:** Recompression overhead without benefits
- **EXIF stripping:** Some metadata removed, but compression artifacts added

---

## Development History

### Initial Implementation

- Basic PDF scaling (didn't actually compress)
- Fixed SwiftLint violations (7 issues)
- Added Combine import for ObservableObject

### Compression Implementation

- Researched iOS PDF compression (no native API)
- Implemented render-to-JPEG approach
- Created 6 quality levels with DPI/quality pairs
- Added smart file size estimation

### UI Improvements

- Simplified to compression-only (removed scaling)
- Created full-width quality selector with icons
- Color-coded quality levels (green, blue, orange, red, purple, pink)
- Added visual quality info card

### Drag & Drop Feature

- Initial implementation with closure-based onDrop
- Fixed iOS 18 compatibility with DropDelegate
- Implemented security-scoped resource handling
- Added visual drop zone with dashed border

### Share to App Feature

- Created AppState for URL handling
- Added onOpenURL integration
- Documented Info.plist configuration
- Fixed onChange API for iOS 18

### Password Protection Feature

- Added PDF password detection
- Implemented password unlock functionality
- Created password prompt UI
- Added unlocked PDF export option

### PDF Page Reordering Feature (NEW - November 5, 2025)

- Created PDFPageInfo model for page representation
- Implemented PageReorderViewModel for state management
- Added thumbnail generation with UIImage (Swift 6 MainActor compatible)
- Created PageReorderView with native iOS List drag-and-drop
- Integrated reorderPages method in PDFProcessor using PDFKit
- Added purple "Reorder Pages" button to PDFToolView
- Implemented workflow: Import → Reorder → Compress → Export
- Fixed SwiftLint violations (0 violations in new files)

### Compression Toggle Feature (NEW - November 5, 2025)

- Added isCompressionEnabled toggle to PDFProcessorViewModel (default: ON)
- Implemented copyPDFWithoutCompression method in PDFProcessor
- Created toggle UI with green/gray icons
- Made quality selector conditionally visible (only when compression enabled)
- Updated process button text: "Compress PDF" vs "Process PDF"
- Allows users to reorder pages without compression
- Preserves original PDF quality when compression is disabled

### Image Resizing Tool (NEW - November 3, 2025)

- Created separate image processing module
- Implemented aspect ratio preservation logic
- **Fixed EXIF orientation handling** - images from camera now display correctly
- Added auto-calculation for width/height inputs
- **Added dimension clamping** - prevents upscaling beyond original size
- Created quick preset buttons for common resolutions
- Added quality slider for output control
- **Smart format conversion** - auto-converts to JPEG when quality < 100%
- Implemented multi-format support (PNG, JPG, HEIC, GIF, BMP, TIFF)
- **Added QuickLook preview** - preview images before exporting
- Created ImageToolView with purple theme
- Added ImageDropDelegate for drag-and-drop
- Integrated tab navigation between PDF and Image tools
- Updated AppState to handle incoming image files

---

## Testing Checklist

### PDF Tool - File Selection

- ✅ Browse button opens file picker
- ✅ Drag PDF from Files app shows green highlight
- ✅ Drop PDF loads file correctly
- ✅ Share PDF from other apps opens in PDFTools
- ✅ Password-protected PDFs show lock icon
- ✅ Password unlock prompt appears

### PDF Tool - Compression

- ✅ All 6 quality levels compress PDFs
- ✅ Progress indicator shows during compression
- ✅ File size reduces appropriately per quality
- ✅ Error handling for invalid files
- ✅ Unlocked PDFs can be compressed

### Image Tool - File Selection (NEW)

- ✅ Browse button opens file picker for images
- ✅ Drag image from Files app shows green highlight
- ✅ Drop image loads file correctly
- ✅ Share image from other apps opens in PDFTools
- ✅ All formats supported (PNG, JPG, HEIC, GIF, BMP, TIFF)
- ✅ Image dimensions displayed correctly

### Image Tool - Resizing (NEW)

- ✅ Width input auto-calculates height
- ✅ Height input auto-calculates width
- ✅ Aspect ratio preserved in calculations
- ✅ Original preset resets to original dimensions
- ✅ Quick presets work for all resolutions
- ✅ Quality slider adjusts output quality
- ✅ Prevents upscaling (only downscales)
- ✅ Progress indicator shows during processing
- ✅ File size comparison shown after processing

### UI/UX

- ✅ Tab navigation switches between PDF and Image tools
- ✅ Incoming files auto-switch to correct tab
- ✅ Quality selector shows icon, title, subtitle (PDF)
- ✅ Dimension inputs update in real-time (Image)
- ✅ Processed files show size comparison
- ✅ Export button shares processed files
- ✅ Reset button clears state

### Edge Cases

- ✅ Non-PDF/non-image files show error message
- ✅ Corrupted files handled gracefully
- ✅ Very large PDFs (100+ pages) compress successfully
- ✅ Very large images (10000×10000px) resize successfully
- ✅ Multiple processing operations without restart
- ✅ Background/foreground transitions maintain state
- ✅ Invalid dimension inputs handled properly
- ✅ Zero or negative dimensions prevented

---

## Performance Considerations

### Memory Management

- Large PDFs processed page-by-page to avoid memory spikes
- Temporary files cleaned up after compression
- Images released immediately after adding to PDF

### Processing Time

Approximate compression times (on iPhone 15):

- 10-page PDF: 2-5 seconds
- 50-page PDF: 10-20 seconds
- 100-page PDF: 20-40 seconds

### File Size Results

Real-world compression results:

- **Image-heavy PDFs:** 50-85% reduction (very effective)
- **Text PDFs:** 0-30% reduction (may increase size)
- **Mixed content:** 30-60% reduction

---

## Future Enhancements

### Potential Features

1. **Batch Processing** - Compress multiple PDFs at once
2. **OCR Integration** - Preserve text searchability
3. **Custom Quality** - User-defined DPI and JPEG quality
4. **Cloud Integration** - iCloud Drive, Dropbox support
5. **Compression Preview** - Sample page before full compression
6. **Smart Quality** - Auto-detect best quality based on content
7. **Undo/Redo** - Revert compression settings
8. **Watermarking** - Add text/image watermarks
9. **PDF Merging** - Combine multiple PDFs before compression
10. **Analytics** - Track compression savings over time

### Technical Improvements

1. **Background Processing** - Use BackgroundTasks framework
2. **Progress Tracking** - Per-page compression progress
3. **Caching** - Cache common compression settings
4. **Error Recovery** - Resume failed compressions
5. **Unit Tests** - Comprehensive test coverage
6. **UI Tests** - Automated UI testing
7. **Accessibility** - VoiceOver support improvements
8. **Localization** - Multi-language support

---

## Resources & References

### Apple Documentation

- [SwiftUI Drop Operations](https://developer.apple.com/documentation/swiftui/dropoperation)
- [PDFKit Framework](https://developer.apple.com/documentation/pdfkit)
- [Core Graphics PDF](https://developer.apple.com/documentation/coregraphics/cgpdfdocument)
- [Image I/O Framework](https://developer.apple.com/documentation/imageio)

### Community Resources

- Stack Overflow: iOS 18 onDrop issues
- GitHub: SwiftUI File Drop Examples
- WWDC Sessions: Drag and Drop in SwiftUI

### MCP Servers Used

- **Context7** - Up-to-date iOS documentation
- **PostHog** - Analytics integration
- **Sticky Notes** - Development notes
- **Google Tasks** - Task tracking

---

## License & Credits

**Developer:** Om Shejul  
**Created:** November 2, 2025  
**Platform:** iOS 18+  
**Framework:** SwiftUI with MVVM architecture

---

## Appendix: Complete Code Snippets

### Main App Entry Point

```swift
// PDFToolsApp.swift
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

class AppState: ObservableObject {
    @Published var incomingPDFURL: URL?

    func handleIncomingURL(_ url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else { return }
        incomingPDFURL = url
    }
}
```

### Quality Selector UI

```swift
Menu {
    ForEach(CompressionQuality.allCases, id: \.self) { quality in
        Button {
            viewModel.compressionQuality = quality
        } label: {
            Label {
                VStack(alignment: .leading) {
                    Text(quality.rawValue)
                    Text(quality.description).font(.caption)
                }
            } icon: {
                Image(systemName: qualityIcon(for: quality))
            }
        }
    }
} label: {
    HStack(spacing: 12) {
        // Icon
        ZStack {
            Circle()
                .fill(qualityColor(for: viewModel.compressionQuality).opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: qualityIcon(for: viewModel.compressionQuality))
                .foregroundColor(qualityColor(for: viewModel.compressionQuality))
        }

        // Title and subtitle
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.compressionQuality.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(viewModel.compressionQuality.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }

        Spacer()

        // Chevron indicator
        Image(systemName: "chevron.up.chevron.down")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding(12)
    .background(Color(.systemBackground))
    .cornerRadius(10)
}
```

---

**Document Version:** 1.0  
**Last Updated:** November 2, 2025  
**Status:** Production Ready
