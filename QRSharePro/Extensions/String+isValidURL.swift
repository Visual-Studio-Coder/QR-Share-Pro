//
//  String+isValidURL.swift
//  QRSharePro
//

//

import Foundation

extension String {
    func isValidURL() -> Bool {
        if let url = URLComponents(string: self) {
            if url.scheme != nil && !url.scheme!.isEmpty {
                let scheme = (url.scheme ?? "fail")
                return scheme == "http" || scheme == "https"
            }
        }

        return false
    }

    func isFIDOPassKey() -> Bool {
        if let url = URLComponents(string: self) {
            if url.scheme != nil && !url.scheme!.isEmpty {
                let scheme = (url.scheme ?? "fail")
                return scheme == "fido"
            }
        }

        return false
    }
}
