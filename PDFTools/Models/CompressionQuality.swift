//
//  CompressionQuality.swift
//  PDFTools
//
//  Created by Om Shejul on 02/11/25.
//

import Foundation

enum CompressionQuality: String, CaseIterable, Sendable {
    case best = "Best Quality"
    case high = "High Quality"
    case medium = "Medium Quality"
    case low = "Low Quality"
    case veryLow = "Very Low Quality"
    case minimum = "Minimum Quality"

    var compressionValue: CGFloat {
        switch self {
        case .best:
            return 0.9  // 90% quality - minimal compression
        case .high:
            return 0.7  // 70% quality - good quality
        case .medium:
            return 0.5  // 50% quality - balanced
        case .low:
            return 0.3  // 30% quality - high compression
        case .veryLow:
            return 0.15  // 15% quality - very high compression
        case .minimum:
            return 0.05  // 5% quality - maximum compression
        }
    }

    var resolutionDPI: CGFloat {
        switch self {
        case .best:
            return 300  // Print quality
        case .high:
            return 200  // Good for printing
        case .medium:
            return 150  // Good for viewing
        case .low:
            return 100  // Acceptable for viewing
        case .veryLow:
            return 72  // Screen resolution
        case .minimum:
            return 50  // Very low resolution
        }
    }

    var description: String {
        switch self {
        case .best:
            return "Best quality, largest file size"
        case .high:
            return "High quality, good for printing"
        case .medium:
            return "Balanced quality and size"
        case .low:
            return "Smaller file, good for sharing"
        case .veryLow:
            return "Very small file, basic quality"
        case .minimum:
            return "Smallest possible file"
        }
    }

    var estimatedReduction: Double {
        switch self {
        case .best:
            return 0.15  // ~15% reduction
        case .high:
            return 0.30  // ~30% reduction
        case .medium:
            return 0.50  // ~50% reduction
        case .low:
            return 0.65  // ~65% reduction
        case .veryLow:
            return 0.75  // ~75% reduction
        case .minimum:
            return 0.85  // ~85% reduction
        }
    }
}
