import SwiftUI

@main
struct QRCodeApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	@Environment(\.colorScheme) var colorScheme
	@StateObject private var qrCodeStore = QRCodeStore()
	@StateObject var sharedData = SharedData()
	@ObservedObject var accentColorManager = AccentColorManager.shared
	
	var body: some Scene {
		WindowGroup {
			OnboardingView()
				.environmentObject(sharedData)
				.accentColor(accentColorManager.accentColor)
				.environmentObject(qrCodeStore)
				.splashView {
					ZStack {
						LinearGradient(colors: colorScheme == .dark ? [.blue.opacity(0.1), .blue.opacity(0.2), .blue.opacity(0.3), .blue.opacity(0.4), .blue.opacity(0.5), .blue.opacity(0.6)] : [.blue.opacity(0.9), .blue.opacity(0.8), .blue.opacity(0.7), .blue.opacity(0.6), .blue.opacity(0.5), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
							.ignoresSafeArea()
						
						VStack {
							Spacer()
							
							Spacer()
							
							Text("QR Share Pro")
								.font(.largeTitle)
								.bold()
								.foregroundStyle(.white)
								.padding(.top, 5)
								.shadow(radius: 50)
							
							Spacer()
							
							Text("Why did the QR code go to school?\nTo improve its scan-ability!")
								.multilineTextAlignment(.center)
								.foregroundStyle(.white)
								.padding(.bottom)
							
							Spacer()
						}
						
						Spacer()
					}
				}
		}
	}
}
