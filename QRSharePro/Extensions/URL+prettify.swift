//
//  URL+prettify.swift
//  QRSharePro
//
//  Created by Aaron Ma on 4/7/24.
//

import Foundation

extension URL {
    func prettify() -> URL {
//        var modifiedURLString = self
//        
//        if let hashIndex = absoluteString.firstIndex(of: "#") {
//            var components = URLComponents(url: modifiedURLString, resolvingAgainstBaseURL: false)!
//            components.fragment = nil
//            modifiedURLString = components.url!
//        }
//        
//        if let queryIndex = absoluteString.firstIndex(of: "?") {
//            var components = URLComponents(url: modifiedURLString, resolvingAgainstBaseURL: false)!
//            components.queryItems = nil
//            modifiedURLString = components.url!
//        }
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
}
