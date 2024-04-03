//
//  String+isValidURL.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 4/3/24.
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
