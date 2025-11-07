//
//  MuPDFBridge.h
//  PDFTools
//
//  Objective-C bridge to MuPDF library for selective image compression
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// Represents an extracted image from a PDF
@interface MuPDFExtractedImage : NSObject

@property (nonatomic, assign) int pageNumber;
@property (nonatomic, assign) int imageIndex;
@property (nonatomic, assign) int width;
@property (nonatomic, assign) int height;
@property (nonatomic, strong) NSData *imageData;
@property (nonatomic, assign) int objectNumber;
@property (nonatomic, assign) CGRect boundingBox;

@end

/// Bridge to MuPDF for image extraction and PDF manipulation
@interface MuPDFBridge : NSObject

/// Extract all images from a PDF
/// @param pdfPath Path to the PDF file
/// @param error Error if extraction fails
/// @return Array of extracted images or nil on failure
+ (nullable NSArray<MuPDFExtractedImage *> *)extractImagesFromPDF:(NSString *)pdfPath
                                                            error:(NSError **)error;

/// Compress PDF by replacing images with downscaled versions
/// @param sourcePath Path to source PDF
/// @param outputPath Path for output PDF
/// @param maxDimension Maximum width or height for images
/// @param jpegQuality JPEG quality (0.0 to 1.0)
/// @param error Error if compression fails
/// @return YES if successful, NO otherwise
+ (BOOL)compressPDFAtPath:(NSString *)sourcePath
               outputPath:(NSString *)outputPath
             maxDimension:(int)maxDimension
              jpegQuality:(float)jpegQuality
                    error:(NSError **)error;

/// Check if MuPDF library is available
+ (BOOL)isMuPDFAvailable;

@end

NS_ASSUME_NONNULL_END
