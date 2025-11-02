//
//  PDFSize.swift
//  PDFTools
//
//  Created by Om Shejul on 02/11/25.
//

import Foundation

enum PDFSize: Sendable {
    case sizea4
    case letter
    case legal
    case custom(width: CGFloat, height: CGFloat)
    case scale(factor: CGFloat)  // Scale by percentage (e.g., 0.5 = 50%)

    var dimensions: (width: CGFloat, height: CGFloat) {
        switch self {
        case .sizea4:
            return (595.0, 842.0)  // A4 in points
        case .letter:
            return (612.0, 792.0)  // Letter in points
        case .legal:
            return (612.0, 1008.0)  // Legal in points
        case .custom(let width, let height):
            return (width, height)
        case .scale:
            return (0, 0)  // Not applicable for scale
        }
    }

    var displayName: String {
        switch self {
        case .sizea4:
            return "A4"
        case .letter:
            return "Letter"
        case .legal:
            return "Legal"
        case .custom:
            return "Custom"
        case .scale(let factor):
            return "Scale \(Int(factor * 100))%"
        }
    }
}
