import SwiftUI

extension Data {
    func toImage() -> Image? {
        guard let uiImage = UIImage(data: self) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    func convertToUIImage() -> UIImage? {
            return UIImage(data: self)
    }
}
