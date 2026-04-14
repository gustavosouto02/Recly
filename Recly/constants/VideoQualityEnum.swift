//
//  VideoQualityEnum.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 13/04/26.
//

import Foundation
import SwiftUI

enum VideoQuality: String, CaseIterable {
    case hd30 = "HD 30fps"
    case hd60 = "HD 60fps"
    case fullHD30 = "FullHD 30fps"
    case fullHD60 = "FullHD 60fps"
    case uhd4k30 = "4K 30fps"
    case uhd4k60 = "4K 60fps"
}
