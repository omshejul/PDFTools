# iOS PDF Tool - Development Plan

## Project Overview
Build an iOS app for PDF manipulation including compression, resizing, merging, and splitting.

## Tech Stack
- **Language:** Swift
- **UI Framework:** SwiftUI
- **PDF Processing:** PDFKit, Core Graphics (CGPDFDocument, CGContext)
- **Minimum iOS:** 26
- **Architecture:** MVVM

## Core Features

### 1. PDF Import
- Document picker integration
- Support Files app, iCloud Drive
- Handle multiple file selection
- Validate PDF format

### 2. PDF Compression
- Quality levels: Low (0.3), Medium (0.5), High (0.7)
- Downsample images within PDF
- Remove metadata
- Show before/after file sizes

### 3. Size Conversion
- Preset sizes: A4, Letter, Legal, Custom
- Maintain aspect ratio option
- Portrait/Landscape orientation
- Scale content to fit

### 4. Additional Operations
- Merge multiple PDFs
- Split PDF by page ranges
- Extract specific pages
- Reorder pages
- Rotate pages

### 5. Export
- Save to Files app
- Share sheet integration
- Preview before export

## File Structure
```
PDFToolApp/
├── App/
│   ├── PDFToolApp.swift
│   └── ContentView.swift
├── Models/
│   ├── PDFDocument.swift
│   └── ProcessingOptions.swift
├── ViewModels/
│   ├── PDFListViewModel.swift
│   └── PDFProcessorViewModel.swift
├── Views/
│   ├── DocumentPickerView.swift
│   ├── PDFPreviewView.swift
│   ├── OperationsView.swift
│   └── ExportView.swift
├── Services/
│   ├── PDFProcessor.swift
│   ├── PDFCompressor.swift
│   ├── PDFResizer.swift
│   └── FileManager+Extensions.swift
└── Utilities/
    ├── PDFSize.swift
    └── Constants.swift
```

## Key Classes/Protocols

### PDFProcessor Service
```swift
class PDFProcessor {
    func compress(pdf: URL, quality: CompressionQuality) async throws -> URL
    func resize(pdf: URL, to size: PDFSize) async throws -> URL
    func merge(pdfs: [URL]) async throws -> URL
    func split(pdf: URL, ranges: [Range<Int>]) async throws -> [URL]
    func extractPages(from pdf: URL, pages: [Int]) async throws -> URL
}
```

### Models
- `PDFDocument`: Represents loaded PDF with metadata
- `CompressionQuality`: Enum (low, medium, high)
- `PDFSize`: Preset sizes + custom dimensions
- `ProcessingOperation`: Enum of available operations

## Technical Requirements

### Compression Algorithm
1. Load PDF using `CGPDFDocument`
2. Create new `CGContext` with compression
3. Iterate through pages
4. For each page:
   - Extract images
   - Downsample to target quality
   - Redraw with compressed images
5. Write to new PDF file

### Resize Implementation
1. Calculate new dimensions
2. Create `CGContext` with target size
3. Draw each page scaled to fit
4. Maintain aspect ratio if enabled

### Memory Management
- Process large PDFs page-by-page
- Use autoreleasepool for iterations
- Clean up temporary files
- Handle background processing for large files

## UI Flow
1. **Home Screen:** List of imported PDFs
2. **Import Screen:** Document picker
3. **Preview Screen:** PDF viewer with page thumbnails
4. **Operations Screen:** Select operation + parameters
5. **Processing Screen:** Progress indicator
6. **Result Screen:** Before/after comparison, export options

## Error Handling
- Invalid PDF format
- Insufficient storage space
- Corrupted files
- Permission errors
- Processing failures

## Testing Priorities
1. Various PDF types (scanned, vector, mixed)
2. Large files (50+ MB, 100+ pages)
3. Edge cases (encrypted, forms, annotations)
4. Memory usage under load

## Implementation Phases

**Phase 1:** Basic structure + import/preview
**Phase 2:** Compression feature
**Phase 3:** Resize feature
**Phase 4:** Merge/split features
**Phase 5:** UI polish + export
**Phase 6:** Performance optimization + testing

## Dependencies
```swift
// Package.swift - if using SPM
// No external dependencies needed - use native frameworks
```

## Notes
- Store processed files in app's Documents directory
- Clear temp files after export
- Support Dark Mode
- Add haptic feedback for operations
- Consider background processing for large files