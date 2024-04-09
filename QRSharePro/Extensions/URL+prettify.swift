//
//  URL+prettify.swift
//  QRSharePro
//
//  Created by Aaron Ma on 4/7/24.
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
}
