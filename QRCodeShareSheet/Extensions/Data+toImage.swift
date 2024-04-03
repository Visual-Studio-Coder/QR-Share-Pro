//
//  Data+toImage.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 4/3/24.
//

import SwiftUI

extension Data {
    func toImage() -> Image? {
        guard let uiImage = UIImage(data: self) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}
