//
//  PDFPageInfo.swift
//  PDFTools
//
//  Created by Om Shejul on 05/11/25.
//

import Foundation
import UIKit

struct PDFPageInfo: Identifiable, Sendable {
    let id = UUID()
    let pageNumber: Int
    let thumbnail: UIImage

    init(pageNumber: Int, thumbnail: UIImage) {
        self.pageNumber = pageNumber
        self.thumbnail = thumbnail
    }
}
