import SwiftUI

struct QRCode: Identifiable, Codable {
    var id = UUID()
    var text: String
    var originalURL: String
    var qrCode: Data?
    var date = Date.now
    var pinned = false
    var scanLocation: [Double] = []
    var wasScanned = false
    var wasCreated = false
    var wasEdited = false
}

@MainActor
class QRCodeStore: ObservableObject {
    @Published var history: [QRCode] = []
    
    private let userDefaults = UserDefaults(suiteName: "group.com.click.QRShare")
    
    init() {
        let notificationName = CFNotificationName("com.click.QRShare.dataChanged" as CFString)
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { (_, _, _, _, _) in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("com.click.QRShare.dataChanged"), object: nil)
            }
        }, notificationName.rawValue, nil, .deliverImmediately)
        NotificationCenter.default.addObserver(self, selector: #selector(load), name: NSNotification.Name("com.click.QRShare.dataChanged"), object: nil)
        load()
    }
    
    @objc func load() {
        guard let data = userDefaults?.data(forKey: "history") else {
            return
        }
        let decoder = JSONDecoder()
        if let loadedHistory = try? decoder.decode([QRCode].self, from: data) {
            self.history = loadedHistory
        }
    }
    
    func save(history: [QRCode]) {
        let encoder = JSONEncoder()
        if let encodedHistory = try? encoder.encode(history) {
            userDefaults?.set(encodedHistory, forKey: "history")
        }
    }
    
    func indexOfQRCode(withID id: UUID) -> Int? {
        return history.firstIndex(where: { $0.id == id })
    }
}
