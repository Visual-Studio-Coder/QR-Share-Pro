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
                .fontWeight(.bold)
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

struct OnboardingView: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @AppStorage("isOnboardingDone") private var isOnboardingDone = false
    
    @State private var selection: Tab = .NewQRCode
    @State private var colors: [Color] = [.gray, .orange, .yellow, .green, .blue, .white, .purple, .pink, .gray, .white]
    
    func getImage(tab: Tab) -> String{
        switch tab {
        case .Scanner:
            return "qrcode.viewfinder"
        case .NewQRCode:
            return "plus"
        case .History:
            return "clock.arrow.circlepath"
        }
    }
    
    var body: some View {
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
                    try await qrCodeStore.load()
                }
            }
            
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selection = tab
                        }
                    } label: {
                        Image(systemName: getImage(tab: tab))
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 15, height: 15)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(selection == tab ? .white : .gray)
                            .scaleEffect(selection == tab ? 1.5 : 1)
                    }
                    .background {
                        if tab == selection {
                            withAnimation(.easeOut(duration: 0.1).delay(0.07)) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .opacity(0.8)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: .indigo, radius: 10)
                            }
                        }
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
            TabView {
                VStack {
                    Spacer()
                    Image(uiImage: #imageLiteral(resourceName: "AppIcon"))
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: 37))
                        .scaledToFit()
                        .frame(height: 200)
                        .padding(.top, 50)
                        .padding(.bottom, 50)
                    Text("Welcome to QR Share!")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Generate QR codes from directly from the Share menu, securely scan codes, and manage your QR code library!")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50)
                        .padding(.bottom, 50)
                    Spacer()
                }
                VStack {
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .scaledToFit()
                        .frame(height: 200)
                        .padding(.top, 50)
                        .padding(.bottom, 50)
                    Text("Add QR Share to the Share Menu")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text("Generate QR Codes from any app. \nClick \"Show Share Menu,\" scroll through the list of apps, tap \"more,\" and add QR Share!")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50)
                        .padding(.bottom, 50)
                    if #available(iOS 16.0, *) {
                        ShareLink(item: "https://github.com/") {
                            Label {
                                Text("Show Share Menu")
                            } icon: {
                                Image(systemName: "gear")
                            }

                        }
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    } else {
                        // Fallback on earlier versions
                    }
                    Spacer()
                }
                VStack {
                    Spacer()
                    Image(uiImage: #imageLiteral(resourceName: "QR-Scan-demo"))
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .scaledToFit()
                        .padding(50)
                        .padding(.bottom, 50)
                    Text("Scan codes *Privately* and *Securely*")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text("Some QR codes contain tracking links that collect sensitive info, such as your IP address, before redirecting you. We automatically unshorten these URLs so you know where you're *really* headed.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50)
                        .padding(.bottom, 50)
                    Spacer()
                }
                VStack {
                    Text("Get Started")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 20)
                        .onTapGesture {
                            isOnboardingDone = true
                        }
                }
                .tabItem {
                    Image(systemName: "checkmark.circle")
                    Text("Done")
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        OnboardingView()
            .environmentObject(qrCodeStore)
    }
}
