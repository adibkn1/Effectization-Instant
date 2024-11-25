//
//  ContentProvider.swift
//  QR Scanner
//
//  Created by Swarup Panda on 23/11/24.
//

import Foundation

protocol ContentProvider {
    func getAllCategories() -> [String]
}

class DefaultContentProvider: ContentProvider {
    func getContent(for category: String) -> [ImageViewContent]? {
        return ContentConfiguration.contentForButtons[category]
    }
    
    func getAllCategories() -> [String] {
            return ContentConfiguration.categoryOrder
        }
}
