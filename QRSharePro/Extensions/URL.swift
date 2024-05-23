//
//  URL.swift
//  QRSharePro
//
//  Created by Aaron Ma on 5/23/24.
//

import Foundation

extension URL {
    func prettify() -> URL {
        var absoluteString = self.absoluteString
        
        if let hashIndex = absoluteString.firstIndex(of: "#") {
            absoluteString = String(absoluteString[..<hashIndex])
        }
        
        if let queryIndex = absoluteString.firstIndex(of: "?") {
            absoluteString = String(absoluteString[..<queryIndex])
        }
        
        if !absoluteString.isEmpty && absoluteString.last == "/" {
            absoluteString = String(absoluteString.dropLast())
        }
        
        return URL(string: absoluteString)!
    }
    
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true), let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
    }
}
