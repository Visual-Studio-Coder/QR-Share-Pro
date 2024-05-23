//
//  String+extractFirstURL.swift
//  Share
//

//

import Foundation

extension String {
    func extractFirstURL() -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: self, options: [], range: NSMakeRange(0, self.utf16.count))
        let urls = matches?.compactMap { Range($0.range, in: self) }.map { String(self[($0)]) }
        return urls?.first ?? self
    }
}
