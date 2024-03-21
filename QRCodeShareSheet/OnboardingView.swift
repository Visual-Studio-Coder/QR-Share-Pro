//
//  OnboardingView.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/5/24.
//

import SwiftUI

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
    case Library
}

struct OnboardingView: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @AppStorage("isOnboardingDone") private var isOnboardingDone = false
    
    @State private var selection: Tab = .NewQRCode
    
    func getImage(tab: Tab) -> String{
        switch tab {
        case .Scanner:
            return "qrcode.viewfinder"
        case .NewQRCode:
            return "plus"
        case .Library:
            return "books.vertical.fill"
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
                    Library()
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
            TabView {
                OnboardingPageView(image: Image("AppIcon"), title: "QR Code Generator", description: "This app allows you to generate QR codes from text.")
                OnboardingPageView(image: Image(systemName: "square.and.arrow.up"), title: "Share Sheet", description: "You can add this app to the share sheet to generate QR codes from other apps.")
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

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        OnboardingView()
            .environmentObject(qrCodeStore)
    }
}
