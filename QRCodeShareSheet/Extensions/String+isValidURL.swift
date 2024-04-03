//
//  String+isValidURL.swift
//  QRCodeShareSheet
//

//

import Foundation

extension String {
    func isValidURL() -> Bool {
        if let url = URLComponents(string: self) {
            return url.scheme != nil && !url.scheme!.isEmpty
        }
        
        return false
    }
}
