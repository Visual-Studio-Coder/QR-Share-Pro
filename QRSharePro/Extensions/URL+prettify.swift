//
//  URL+prettify.swift
//  QRSharePro
//
//  Created by Aaron Ma on 4/7/24.
//

import Foundation

extension URL {
    func prettify() -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        
        // Remove the last slash from the path
        if let lastSlashIndex = components.path.lastIndex(of: "/") {
            components.path = String(components.path[components.path.startIndex..<lastSlashIndex])
        }
        
        // Remove query parameters and fragment identifier
        components.queryItems = nil
        components.fragment = nil
        
        return components.url!
    }
}
