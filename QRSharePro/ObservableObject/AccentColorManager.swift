import SwiftUI

class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()
    
    var accentColor: Color {
        get {
            let colorData = UserDefaults.standard.data(forKey: "accentColor")
            let uiColor = colorData != nil ? UIColor.colorWithData(colorData!) : UIColor(Color(#colorLiteral(red: 0.3860174716, green: 0.7137812972, blue: 0.937712729, alpha: 1)))
            return Color(uiColor)
        }
        set {
            let uiColor = UIColor(newValue)
            UserDefaults.standard.set(uiColor.encode(), forKey: "accentColor")
            objectWillChange.send()
        }
    }
}
