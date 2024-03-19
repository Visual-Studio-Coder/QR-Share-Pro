import SwiftUI

struct QRCode: Identifiable, Codable {
    var id = UUID()
    var text: String
    var qrCode: Data?
    var brandingLogo: Data?
    var date = Date.now
}

extension Data {
    func toImage() -> Image? {
        guard let uiImage = UIImage(data: self) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

@MainActor
class QRCodeStore: ObservableObject {
    @Published var history: [QRCode] = []
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
        .appendingPathComponent("qrcode.data")
    }
    
    func load() async throws {
        let task = Task<[QRCode], Error> {
            let fileURL = try Self.fileURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                return []
            }
            let history = try JSONDecoder().decode([QRCode].self, from: data)
            return history
        }
        let history = try await task.value
        self.history = history
    }
    
    func save(history: [QRCode]) async throws {
        let task = Task {
            let data = try JSONEncoder().encode(history)
            let outfile = try Self.fileURL()
            try data.write(to: outfile)
        }
        _ = try await task.value
    }
    
    func indexOfQRCode(withID id: UUID) -> Int? {
        return history.firstIndex(where: { $0.id == id })
    }
}
