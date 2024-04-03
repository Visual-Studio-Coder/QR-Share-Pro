import SwiftUI
import ColorfulX

struct OnboardingView: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    @AppStorage("isOnboardingDone") private var isOnboardingDone = false
    
    @State private var showingPrivacySheet = false
    @State private var showingTabView = true
    @State private var completedStep1 = false
    @State private var selection: Tab = .NewQRCode
    @State private var colors: [Color] = [.purple, .indigo, .pink, .orange, .red]
    
    let features = [
        Feature(title: "Create QR Codes from the Share Menu", description: "Share text & URL with just a QR code.", image: "square.and.arrow.up"),
        Feature(title: "Confidently Scan QR Codes", description: "Prevent phishing attacks by seeing where QR code links *actually* take you.", image: "qrcode.viewfinder"),
        Feature(title: "Create New QR Code", description: "Generate any type of QR code from URLs to Wi-Fi, all without being tracked.", image: "plus"),
        Feature(title: "View QR Code History", description: "Scanned QR codes, created codes, and shared QR codes live in one place.", image: "clock.arrow.circlepath")
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
                
                if showingTabView {
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
                                    .animation(Animation.easeInOut(duration: 0.75).delay(0.01), value: selection)
                                    .foregroundStyle(selection == tab ? Color.accentColor : .gray)
                                    .scaleEffect(selection == tab ? 2 : 1)
                                    .bold(selection == tab)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 15)
                    .padding(.bottom, 10)
                    .padding([.horizontal, .top])
                }
            } else {
                if !completedStep1 {
                    ZStack {
                        ColorfulView(color: $colors)
                            .ignoresSafeArea()
                            .opacity(0.8)
                        
                        VStack(spacing: 20) {
                            ScrollView {
                                VStack(spacing: 20) {
                                    Image(uiImage: UIImage(named: "AppIcon") ?? UIImage()) // shouldn't this be a force-unwrap? this will cause issues with the user not being able to see our app icon
                                        .resizable()
                                        .frame(width: 150, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                        .accessibilityHidden(true)
                                        .shadow(color: .accentColor, radius: 15)
                                        .padding(.top, 20)
                                    
                                    VStack {
                                        Text("Say \"hello\" to")
                                            .foregroundStyle(.white)
                                        
                                        Text("QR Share Pro")
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
                                Button {
                                    showingPrivacySheet = true
                                } label: {
                                    Text("We *actually* respect your privacy. Our app is 100% offline, with all data stored **on-device*.")
                                        .foregroundStyle(.white)
                                    
                                    Text("Learn more...")
                                        .foregroundStyle(.blue)
                                        .bold()
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button {
                                    completedStep1 = true
                                } label: {
                                    Text("Continue")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(Color.accentColor)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .bold()
                                }
                            }
                            .sheet(isPresented: $showingPrivacySheet) {
                                List {
                                    Section("All Features") {
                                        Text("We strongly support users' right to privacy. QR Share Pro doesn't collect or sell your data to anyone. In fact, our app is 100% offline, with all data stored **on-device**, only using the internet for querying website favicons and displaying where you scanned QR codes.")
                                    }
                                    
                                    Section("Website Favicons") {
                                        Text("We query website favicon images through DuckDuckGo, in which DuckDuckGo collects no data about you, except the website URL to fulfill the query. DuckDuckGo does not log website URLs.")
                                        
                                        Button {
                                            if let url = URL(string: "https://duckduckgo.com/privacy") {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            Text("Read DuckDuckGo's Privacy Policy")
                                        }
                                    }
                                    
                                    Section("Apple Maps") {
                                        Text("If you enable Location Services, your location will be tagged to scanned QR codes to display where you scanned QR codes, we use Apple Maps's API. This is not shared with anyone else, and is stored on-device.")
                                        
                                        Button {
                                            if let url = URL(string: "https://apple.com/legal/privacy") {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            Text("Read Apple's Privacy Policy")
                                        }
                                    }
                                }
                                .navigationTitle("We ❤️ Privacy")
                                .toolbar {
                                    Button("Done") {
                                        showingPrivacySheet = false
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    ZStack {
                        ScrollView {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .scaledToFit()
                                .frame(height: 200)
                                .padding(.top, 50)
                                .padding(.bottom, 50)
                            
                            Text("Add QR Share Pro to the Share Menu")
                                .font(.title)
                                .bold()
                                .multilineTextAlignment(.center)
                            
                            Text("Quickly share text & URLs with QR codes!")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 50)
                                .padding(.bottom, 50)
                            
                            ShareLink(item: "https://apps.apple.com/us/app/qr-share-pro/id6479589995/") {
                                Label {
                                    Text("Show Share Menu")
                                } icon: {
                                    Image(systemName: "gear")
                                }
                            }
                            .padding()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            
                            VStack {
                                Button {
                                    isOnboardingDone = true
                                } label: {
                                    Text("Get Started")
                                        .font(.title)
                                        .bold()
                                        .padding()
                                        .foregroundStyle(.white)
                                }
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.bottom, 20)
                            }
                        }
                    }
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
