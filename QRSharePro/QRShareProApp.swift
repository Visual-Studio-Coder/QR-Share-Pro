import SwiftUI

@main
struct QRCodeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appIcon") private var appIcon = "AppIcon"
    @StateObject private var qrCodeStore = QRCodeStore()
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .accentColor(accentColorManager.accentColor)
                .environmentObject(qrCodeStore)
                .splashView {
                    ZStack {
                        LinearGradient(colors: [colorScheme == .dark ? accentColorManager.accentColor.opacity(0.6) : accentColorManager.accentColor, colorScheme == .dark ? accentColorManager.accentColor.opacity(0.1) : accentColorManager.accentColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .ignoresSafeArea()
                        
                        VStack {
                            Spacer()
                            
                            Spacer()
                            
                            Image(uiImage: #imageLiteral(resourceName: appIcon))
                                .resizable()
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                .shadow(color: colorScheme == .dark ? accentColorManager.accentColor : accentColorManager.accentColor.opacity(0.1), radius: 50)
                            
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
