//
//  UIColor.swift
//  QRSharePro
//
//  Created by   on 5/22/24.
//

import UIKit

extension UIColor {
    func encode() -> Data {
        return try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
    }
    
    static func colorWithData(_ data: Data) -> UIColor {
        return try! NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)!
    }
}
