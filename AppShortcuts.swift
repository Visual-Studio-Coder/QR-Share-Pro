import AppIntents
import UIKit

struct ScanQRCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan QR Code"
    static let description: LocalizedStringResource = "Scan any QR code within QR Share Pro's scan tab."

    /// Launch your app when the system triggers this intent.
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Create the URL with the `note` parameter as the query parameter
        guard let url = URL(string: "qrsharepro://scan") else {
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


struct QRShareProShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: CreateQRCodeIntent(),
                phrases: [
                    "Create QR Code with \(.applicationName)",
                    "Generate QR Code with \(.applicationName)",
                    "Create",
                    "QR Code",
                ],
                shortTitle: "Create QR Code",
                systemImageName: "qrcode"
            )
            AppShortcut(
                intent: ScanQRCodeIntent(),
                phrases: [
                    "Scan a QR Code with \(.applicationName)",
                    "Scan QR Code with \(.applicationName)",
                    "Scan a QR Code",
                    "Open QR Code Scanner"
                ],
                shortTitle: "Scan QR Code",
                systemImageName: "qrcode.viewfinder"
            )
    }
}
