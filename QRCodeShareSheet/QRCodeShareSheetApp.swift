import SwiftUI

private let defaultTimeout: TimeInterval = 0.25

struct SplashView<SplashContent: View>: ViewModifier {
    private let timeout: TimeInterval
    private let splashContent: () -> SplashContent
    
    @State private var isActive = true
    
    init(timeout: TimeInterval = defaultTimeout,
         @ViewBuilder splashContent: @escaping () -> SplashContent) {
        self.timeout = timeout
        self.splashContent = splashContent
    }
    
    func body(content: Content) -> some View {
        if isActive {
            splashContent()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
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
    func splashView<SplashContent: View>(
        timeout: TimeInterval = defaultTimeout,
        @ViewBuilder splashContent: @escaping () -> SplashContent
    ) -> some View {
        self.modifier(SplashView(timeout: timeout, splashContent: splashContent))
    }
    
    @ViewBuilder
    func stretchable(in geo: GeometryProxy) -> some View {
        let width = geo.size.width
        let height = geo.size.height
        let minY = geo.frame(in: .global).minY
        let useStandard = minY <= 0
        self.frame(width: width, height: height + (useStandard ? 0 : minY))
            .offset(y: useStandard ? 0 : -minY)
    }
}

@main
struct QRCodeApp: App {
    @StateObject private var qrCodeStore = QRCodeStore()
    @StateObject private var storeKit = StoreKitManager()
    
//    struct SplashView: View {
//        @State var isActive:Bool = false
//
//        var body: some View {
//            VStack {
//                if self.isActive {
//                    HomeView()
//                } else {
//                    Text("Awesome Splash Screen!")
//                        .font(.largeTitle)
//                }
//            }
//            .onAppear {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
//                    withAnimation {
//                        self.isActive = true
//                    }
//                }
//            }
//        }
//
//    }
    
    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .environmentObject(qrCodeStore)
                .environmentObject(storeKit)
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
