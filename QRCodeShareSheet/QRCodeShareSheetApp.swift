import SwiftUI

@main
struct QRCodeApp: App {
    @StateObject private var qrCodeStore = QRCodeStore()
    
    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .environmentObject(qrCodeStore)
        }
    }
}
