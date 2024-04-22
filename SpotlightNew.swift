import AppIntents
import UIKit

struct CreateQRCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Create QR Code"
    static let description: LocalizedStringResource = "Generate a QR code with the desired text."

    /// Launch your app when the system triggers this intent.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "QR Code Text or URL")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Create the URL with the `note` parameter as the query parameter
        guard let url = URL(string: "qrsharepro://new?q=\(note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw URLError(.badURL) // replace `some Error` with URLError
        }

        // Open the URL
        if await UIApplication.shared.open(url) {
            return .result()
        } else {
            throw URLError(.unsupportedURL)
        }
    }
}
struct TransferAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateQRCodeIntent(),
            phrases: [
                "Create a QR Code with \(.applicationName)",
                "Generate a QR Code with \(.applicationName)",
                "Create a QR Code",
            ],
            shortTitle: "QR Code",
            systemImageName: "qrcode"
        )
    }
}
