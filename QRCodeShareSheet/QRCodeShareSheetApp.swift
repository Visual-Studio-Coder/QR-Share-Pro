import SwiftUI

struct SplashView<SplashContent: View>: ViewModifier {
    private let splashContent: () -> SplashContent
    
    @State private var isActive = true
    
    init(@ViewBuilder splashContent: @escaping () -> SplashContent) {
        self.splashContent = splashContent
    }
    
    func body(content: Content) -> some View {
        if isActive {
            splashContent()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation {
                            self.isActive = false
                        }
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func splashView<SplashContent: View>(@ViewBuilder splashContent: @escaping () -> SplashContent) -> some View {
        self.modifier(SplashView(splashContent: splashContent))
    }
}

@main
struct QRCodeApp: App {
    @StateObject private var qrCodeStore = QRCodeStore()
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .accentColor(accentColorManager.accentColor)
                .environmentObject(qrCodeStore)
                .splashView {
                    ZStack {
                        LinearGradient(colors: [Color(#colorLiteral(red: 0.3860174716, green: 0.7137812972, blue: 0.937712729, alpha: 1)), Color(#colorLiteral(red: 0.5606167912, green: 0.8587760329, blue: 0.9991238713, alpha: 1))], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .ignoresSafeArea()
                        
                        VStack {
                            Spacer()
                            
                            Spacer()
                            
                            Image(uiImage: #imageLiteral(resourceName: "AppIcon"))
                                .resizable()
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 32))
                                .shadow(radius: 50)
                            
                            Text("QR Share")
                                .font(.largeTitle)
                                .fontWeight(.bold)
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
