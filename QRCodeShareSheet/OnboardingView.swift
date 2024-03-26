import SwiftUI
import ColorfulX

struct OnboardingPageView: View {
    var image: Image
    var title: String
    var description: String
    
    var body: some View {
        VStack {
            image
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .padding(.top, 50)
                .padding(.bottom, 50)
            Text(title)
                .font(.title)
                .bold()
            Text(description)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
                .padding(.bottom, 50)
            Spacer()
        }
    }
}

enum Tab: String, CaseIterable {
    case Scanner
    case NewQRCode
    case History
}

struct Feature: Decodable, Identifiable {
    var id = UUID()
    let title: String
    let description: String
    let image: String
}


struct OnboardingView: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    @AppStorage("isOnboardingDone") private var isOnboardingDone = false
    
    @State private var selection: Tab = .NewQRCode
    @State private var colors: [Color] = [.black, .indigo, .pink]
    
    let features = [
        Feature(title: "QR Share", description: "Share text & URL with just a QR code.", image: "square.and.arrow.up"),
        Feature(title: "Confidently scan QR codes", description: "Remove trackers & stop phishing in its tracks.", image: "qrcode.viewfinder"),
        Feature(title: "Create New QR Code", description: "If you liked the first one, wait until you see this!", image: "plus"),
        Feature(title: "History", description: "All your previously scanned QR codes, created codes, and shared QR codes live in one place.", image: "clock.arrow.circlepath")
    ]
    
    
    func getImage(tab: Tab) -> String {
        switch tab {
        case .Scanner:
            return "qrcode.viewfinder"
        case .NewQRCode:
            return "plus"
        case .History:
            return "clock.arrow.circlepath"
        }
    }
    
    func openURL(_ url: URL) {
        print(url.absoluteString)
        
        if url.absoluteString.contains("new") {
            selection = .NewQRCode
        } else if url.absoluteString.contains("scan") {
            selection = .Scanner
        } else {
            selection = .History
        }
    }
    
    var body: some View {
        VStack {
            if isOnboardingDone {
                VStack {
                    if selection == .Scanner {
                        Scanner()
                    } else if selection == .NewQRCode {
                        Home()
                    } else {
                        History()
                    }
                }
                .onAppear {
                    Task {
                        qrCodeStore.load()
                    }
                    
                    //#if targetEnvironment(simulator)
                    //                UserDefaults.standard.set(false, forKey: "isOnboardingDone")
                    //#endif
                }
                
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeOut(duration: 0.2).delay(0.07)) {
                                selection = tab
                            }
                        } label: {
                            Image(systemName: getImage(tab: tab))
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(selection == tab ? Color.accentColor : .gray)
                                .scaleEffect(selection == tab ? 2 : 1)
                                .bold(selection == tab)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 2)
                .padding(.bottom, 10)
                .padding([.horizontal, .top])
            } else {
                ZStack {
                    ColorfulView(color: $colors)
                        .ignoresSafeArea()
                        .opacity(0.8)
                    
                    VStack(spacing: 20) {
                        ScrollView {
                            VStack(spacing: 20) {
                                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                                    .resizable()
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                    .accessibilityHidden(true)
                                    .shadow(color: .accentColor, radius: 15)
                                    .padding(.top, 20)
                                
                                HStack {
                                    Text("Welcome to")
                                        .foregroundStyle(.white)
                                    
                                    Text("QR Share")
                                        .foregroundStyle(.cyan)
                                }
                                .multilineTextAlignment(.center)
                                .font(.largeTitle)
                                .bold()
                                
                                ForEach(features) { feature in
                                    HStack {
                                        Image(systemName: feature.image)
                                            .frame(width: 44)
                                            .font(.title)
                                            .foregroundStyle(Color.accentColor)
                                            .accessibilityHidden(true)
                                        
                                        VStack(alignment: .leading) {
                                            Text(feature.title)
                                                .foregroundStyle(.white)
                                                .font(.headline)
                                                .bold()
                                            
                                            Text(feature.description)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        .accessibilityElement(children: .combine)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        
                        VStack {
                            Text("We respect your privacy.")
                                .foregroundStyle(.white)
                            
                            Button {} label: {
                                Text("Learn more...")
                                    .bold()
                            }
                            
                            Button {
                                isOnboardingDone = true
                            } label: {
                                Text("Continue")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                                    .bold()
                            }
                        }
                    }
                    .padding()
                    //                    VStack {
                    //                        Spacer()
                    //                        Image(systemName: "square.and.arrow.up")
                    //                            .resizable()
                    //                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    //                            .scaledToFit()
                    //                            .frame(height: 200)
                    //                            .padding(.top, 50)
                    //                            .padding(.bottom, 50)
                    //                        Text("Add QR Share to the Share Menu")
                    //                            .font(.title)
                    //                            .bold()
                    //                            .multilineTextAlignment(.center)
                    //                        Text("Generate QR Codes from any app. \nClick \"Show Share Menu,\" scroll through the list of apps, tap \"more,\" and add QR Share!")
                    //                            .font(.subheadline)
                    //                            .multilineTextAlignment(.center)
                    //                            .padding(.horizontal, 50)
                    //                            .padding(.bottom, 50)
                    //
                    //                        ShareLink(item: "https://apple.com/") {
                    //                            Label {
                    //                                Text("Show Share Menu")
                    //                            } icon: {
                    //                                Image(systemName: "gear")
                    //                            }
                    //
                    //                        }
                    //                        .padding()
                    //                        .background(.white)
                    //                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    //
                    //                        Spacer()
                    //                    }
                    //                    VStack {
                    //                        Spacer()
                    //                        Image(uiImage: #imageLiteral(resourceName: "QR-scan-demo"))
                    //                            .resizable()
                    //                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    //                            .scaledToFit()
                    //                            .padding(50)
                    //                            .padding(.bottom, 50)
                    //                        Text("Confidently scan QR codes.")
                    //                            .font(.title)
                    //                            .bold()
                    //                            .multilineTextAlignment(.center)
                    //                        Text("Some QR codes contain tracking links that collect sensitive info, such as your IP address, before redirecting you. We automatically unshorten these URLs so you know where you're *really* headed.")
                    //                            .font(.subheadline)
                    //                            .multilineTextAlignment(.center)
                    //                            .padding(.horizontal, 50)
                    //                            .padding(.bottom, 50)
                    //
                    //                        Text("Get Started")
                    //                            .font(.title)
                    //                            .bold()
                    //                            .padding()
                    //                            .background(.blue)
                    //                            .foregroundStyle(.white)
                    //                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    //                            .padding(.bottom, 20)
                    //                            .onTapGesture {
                    //                                isOnboardingDone = true
                    //                            }
                    //                        Spacer()
                    //                    }
                }
            }
        }
        .onOpenURL(perform: openURL)
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        OnboardingView()
            .environmentObject(qrCodeStore)
    }
}
