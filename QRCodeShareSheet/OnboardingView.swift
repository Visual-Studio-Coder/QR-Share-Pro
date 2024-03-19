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
    case Home
    case Library
}

struct CustomTabView: View {
    @Binding var selection: Tab
    
    var body: some View {
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
                        .frame(width: getImage(tab: tab) == "house.fill" ? 25 : 20, height: getImage(tab: tab) == "house.fill" ? 25 : 20)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selection == tab ? .white : .gray)
                        .scaleEffect(selection == tab ? 1.5 : 1)
                }
                .background {
                    if tab == selection {
                        withAnimation(.easeOut(duration: 0.1).delay(0.07)) {
                            Circle()
                                .fill(.green)
                                .frame(width: 50, height: 50)
                                .shadow(color: .green, radius: 10)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .padding(.bottom, 10)
        .padding([.horizontal, .top])
    }
    
    func indicatorOffset(width: CGFloat) -> CGFloat{
        let index = CGFloat(getIndex())
        if index == 0 {
            return 0
        }
        let buttonWidth = width / CGFloat(Tab.allCases.count)
        return index * buttonWidth
    }
    
    func getIndex() -> Int{
        switch selection {
        case .Scanner:
            return 0
        case .Home:
            return 1
        case .Library:
            return 2
        }
    }
    
    func getImage(tab: Tab) -> String{
        switch tab {
        case .Scanner:
            return "qrcode.viewfinder"
        case .Home:
            return "house.fill"
        case .Library:
            return "books.vertical.fill"
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @AppStorage("isOnboardingDone") private var isOnboardingDone = false
    
    @State private var selection: Tab = .Home
    
    var body: some View {
        if isOnboardingDone {
            VStack {
                if selection == .Scanner {
                    Scanner()
                } else if selection == .Home {
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
            
            CustomTabView(selection: $selection)
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
