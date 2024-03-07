import SwiftUI
import CoreImage.CIFilterBuiltins
import Photos

struct ContentView: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @State private var selection: Tab = .History
    
    enum Tab {
        case Home
        case History
    }
    
    var body: some View {
        TabView(selection: $selection) {
            Home()
                .environmentObject(qrCodeStore)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .onAppear {
                    Task {
                        try await qrCodeStore.load()
                    }
                }
                .tag(Tab.Home)
            
            History()
                .environmentObject(qrCodeStore)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .onAppear {
                    Task {
                        try await qrCodeStore.load()
                    }
                }
                .tag(Tab.History)
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        ContentView()
            .environmentObject(qrCodeStore)
    }
}
