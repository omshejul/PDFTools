# MuPDF Integration Guide for PDFTools

This guide explains how to integrate the MuPDF library into the PDFTools iOS application to enable selective PDF image compression while preserving vector content.

## Overview

The PDFTools app now has two compression modes:

1. **Selective (Images Only)** - Extracts images from PDFs, downscales them, and puts them back while preserving text and vector graphics (REQUIRES MuPDF)
2. **Full Page (Rasterize)** - Converts entire pages to images (works with native iOS frameworks)

Currently, the app defaults to "Selective" mode but falls back to the rasterize method if MuPDF is not available.

## Why MuPDF?

iOS's native PDFKit doesn't support:
- Extracting individual images from PDF pages
- Replacing images within existing PDF structure
- Preserving vector content while modifying embedded images

MuPDF is an open-source, lightweight PDF library that provides these capabilities.

## Integration Steps

### Option 1: Using CocoaPods (Recommended)

1. **Install CocoaPods** (if not already installed):
   ```bash
   sudo gem install cocoapods
   ```

2. **Create a Podfile** in your project root:
   ```ruby
   platform :ios, '16.0'
   use_frameworks!

   target 'PDFTools' do
     pod 'MuPDF', '~> 1.23'
   end
   ```

3. **Install MuPDF**:
   ```bash
   cd /path/to/PDFTools
   pod install
   ```

4. **Open the generated `.xcworkspace`** file instead of `.xcodeproj`:
   ```bash
   open PDFTools.xcworkspace
   ```

### Option 2: Manual Integration with XCFramework

If CocoaPods is not desired, you can manually integrate MuPDF:

1. **Download MuPDF source**:
   ```bash
   git clone --recursive https://github.com/ArtifexSoftware/mupdf.git
   cd mupdf
   git checkout 1.23.0  # Or latest stable version
   ```

2. **Build MuPDF for iOS**:
   ```bash
   make -j4 XCFLAGS="-DTOFU -DTOFU_CJK"
   ```

3. **Create XCFramework**:
   ```bash
   # Build for device
   xcodebuild -project platform/ios/MuPDF.xcodeproj \
              -scheme MuPDF \
              -sdk iphoneos \
              -configuration Release \
              SKIP_INSTALL=NO \
              BUILD_LIBRARY_FOR_DISTRIBUTION=YES

   # Build for simulator
   xcodebuild -project platform/ios/MuPDF.xcodeproj \
              -scheme MuPDF \
              -sdk iphonesimulator \
              -configuration Release \
              SKIP_INSTALL=NO \
              BUILD_LIBRARY_FOR_DISTRIBUTION=YES

   # Create XCFramework
   xcodebuild -create-xcframework \
              -framework build/Release-iphoneos/MuPDF.framework \
              -framework build/Release-iphonesimulator/MuPDF.framework \
              -output MuPDF.xcframework
   ```

4. **Add XCFramework to Xcode**:
   - Drag `MuPDF.xcframework` into your Xcode project
   - Go to Target > General > Frameworks, Libraries, and Embedded Content
   - Ensure MuPDF.xcframework is set to "Embed & Sign"

### Option 3: Swift Package Manager (Experimental)

There are community-maintained Swift packages for MuPDF:

```swift
// In Package.swift
dependencies: [
    .package(url: "https://github.com/bhuemer/mupdf-swift", from: "1.0.0")
]
```

**Note**: This is experimental and may not be as stable as CocoaPods or manual integration.

## Configure Xcode Project

### 1. Update Bridging Header

The bridging header is already created at `PDFTools/PDFTools-Bridging-Header.h`. Ensure it's configured in Xcode:

1. Select your project in Xcode
2. Select the PDFTools target
3. Go to Build Settings
4. Search for "Bridging Header"
5. Set **Objective-C Bridging Header** to: `PDFTools/PDFTools-Bridging-Header.h`

### 2. Add MuPDF Headers to Bridging Header

Update the bridging header to include MuPDF:

```objc
//  PDFTools-Bridging-Header.h

#import "../MuPDFBridge/MuPDFBridge.h"

// Add MuPDF headers
#import <mupdf/fitz.h>
#import <mupdf/pdf.h>
```

### 3. Update Build Settings

1. **Header Search Paths**:
   - Add: `$(PODS_ROOT)/MuPDF/include` (if using CocoaPods)
   - Or: Path to your MuPDF headers (if manual)

2. **Library Search Paths**:
   - Add: `$(PODS_ROOT)/MuPDF/lib` (if using CocoaPods)

3. **Other Linker Flags**:
   - Add: `-ObjC`
   - Add: `-lmupdf` (if manually integrated)

### 4. Add MuPDF Bridge Files to Xcode

1. Select your project in Xcode
2. Right-click on the project navigator
3. Add Files to "PDFTools"
4. Select the `MuPDFBridge` folder
5. Ensure "Copy items if needed" is checked
6. Ensure "Create groups" is selected
7. Target should be PDFTools

## Implement MuPDF Bridge

The bridge files are already created but need MuPDF-specific code to be uncommented:

### Update `MuPDFBridge.m`

Open `/home/user/PDFTools/MuPDFBridge/MuPDFBridge.m` and uncomment the full implementation sections marked with comments.

The key functions to implement:

1. **`extractImagesFromPDF:error:`** - Extracts all images from PDF pages
2. **`compressPDFAtPath:outputPath:maxDimension:jpegQuality:error:`** - Compresses PDF by replacing images

These implementations use MuPDF's C API to:
- Open PDF documents with `fz_open_document`
- Iterate through pages with `fz_load_page`
- Access page resources to find image XObjects
- Extract image data with `pdf_load_stream`
- Scale images with `fz_scale_pixmap`
- Replace images in the PDF structure
- Save modified PDFs with `pdf_save_document`

## Testing the Integration

### 1. Build and Run

```bash
cd /path/to/PDFTools
xcodebuild -project PDFTools.xcodeproj -scheme PDFTools -sdk iphonesimulator
```

Or build in Xcode (⌘B)

### 2. Check MuPDF Availability

The app will automatically detect if MuPDF is available. Check the console output:

```
✅ MuPDF available - using selective image compression
```

or

```
ℹ️ MuPDF not available - using fallback compression method
```

### 3. Test with Sample PDFs

Test with various PDF types:

1. **Text-heavy PDFs** - Should show minimal compression with selective mode
2. **Image-heavy PDFs** - Should show significant compression
3. **Mixed content PDFs** - Should preserve text quality while compressing images

## File Structure

After integration, your project should have:

```
PDFTools/
├── PDFTools/
│   ├── Services/
│   │   ├── PDFProcessor.swift
│   │   ├── SelectivePDFCompressor.swift      # NEW
│   │   └── PDFImageExtractor.swift           # NEW
│   ├── ViewModels/
│   │   └── PDFProcessorViewModel.swift       # UPDATED
│   ├── Views/
│   │   └── PDFToolView.swift                 # UPDATED
│   └── PDFTools-Bridging-Header.h            # NEW
├── MuPDFBridge/
│   ├── MuPDFBridge.h                         # NEW
│   └── MuPDFBridge.m                         # NEW
├── Podfile                                    # NEW (if using CocoaPods)
├── MUPDF_INTEGRATION_GUIDE.md                # This file
└── PDFTools.xcodeproj/
```

## Troubleshooting

### "Undefined symbols" error

**Problem**: Linker errors about undefined MuPDF symbols.

**Solution**:
- Ensure MuPDF framework is added to "Frameworks, Libraries, and Embedded Content"
- Check "Other Linker Flags" includes `-ObjC`
- Verify Header Search Paths are correct

### "Use of undeclared identifier" error

**Problem**: Xcode can't find MuPDF types like `fz_context`.

**Solution**:
- Verify MuPDF headers are in the bridging header
- Check Header Search Paths include MuPDF include directory
- Clean build folder (Shift + ⌘ + K)

### MuPDF functions not working

**Problem**: `MuPDFBridge.isMuPDFAvailable()` returns `NO`.

**Solution**:
- Uncomment the implementation code in `MuPDFBridge.m`
- Update the `isMuPDFAvailable` method to actually check for MuPDF symbols
- Ensure MuPDF is properly linked

### App crashes when compressing

**Problem**: App crashes with MuPDF-related errors.

**Solution**:
- Check MuPDF context is properly created and destroyed
- Use `fz_try`/`fz_catch` blocks for error handling
- Verify image data is valid before processing
- Check memory management (retain/release cycles)

## Advanced Configuration

### Compression Quality Mapping

The app's quality settings map to MuPDF parameters:

| Quality    | JPEG Quality | Max Dimension | DPI |
|------------|-------------|---------------|-----|
| Best       | 90%         | 3300px        | 300 |
| High       | 70%         | 2200px        | 200 |
| Medium     | 50%         | 1650px        | 150 |
| Low        | 30%         | 1100px        | 100 |
| Very Low   | 15%         | 792px         | 72  |
| Minimum    | 5%          | 550px         | 50  |
| Custom     | User-defined| Calculated    | User|

### Custom Image Processing

You can modify `MuPDFBridge.m` to add custom image processing:

```objc
// Example: Apply additional filters
fz_pixmap *processed = apply_custom_filter(ctx, scaled);
fz_write_pixmap_as_jpeg(ctx, out, processed, quality);
```

### Selective Page Processing

To process only specific pages:

```objc
for (int pageNum = startPage; pageNum < endPage; pageNum++) {
    // Process only pages in range
}
```

## Performance Considerations

1. **Memory Usage**: MuPDF loads pages into memory. For large PDFs, process pages sequentially
2. **Processing Time**: Selective compression is slower than rasterization but produces better quality
3. **File Size**: Text-heavy PDFs will see minimal compression, image-heavy PDFs will compress significantly

## License Considerations

**MuPDF License**: AGPL v3 or Commercial

- **AGPL v3**: Free for open-source projects. If you distribute your app, you must make source code available
- **Commercial License**: Required for proprietary/closed-source applications

Contact Artifex Software for commercial licensing: https://artifex.com/

## Resources

- **MuPDF Documentation**: https://mupdf.readthedocs.io/
- **MuPDF Source**: https://github.com/ArtifexSoftware/mupdf
- **iOS Integration Examples**: https://mupdf.com/docs/examples/
- **API Reference**: https://mupdf.com/docs/api/

## Alternative Libraries

If MuPDF licensing is a concern, consider:

1. **PDFium** (Google) - BSD License
   - More permissive license
   - Similar capabilities
   - Larger binary size

2. **PoDoFo** - LGPL License
   - C++ library
   - More complex integration

3. **qpdf** - Apache 2.0 License
   - Command-line tool
   - Can be integrated via process execution

## Support

For issues with:
- **PDFTools app**: Create an issue in the PDFTools repository
- **MuPDF library**: Visit https://mupdf.com/support.html
- **Integration**: Refer to this guide or MuPDF iOS examples

## Next Steps

1. ✅ Choose integration method (CocoaPods recommended)
2. ✅ Install MuPDF library
3. ✅ Configure Xcode project
4. ✅ Uncomment implementation code in MuPDFBridge.m
5. ✅ Build and test
6. ✅ Verify selective compression works
7. ✅ Test with various PDF types
8. ✅ Consider licensing requirements

---

**Note**: The app will continue to work without MuPDF integration by falling back to the rasterization method. MuPDF is only required for the selective image compression feature that preserves vector content.
