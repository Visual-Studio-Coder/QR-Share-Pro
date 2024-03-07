import SwiftUI

struct Home: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore

    var body: some View {
        NavigationView {
            VStack {
                NavigationLink {
                } label: {
                    HStack {
                        Spacer()
                        Text("Scan QR Code →")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                
                NavigationLink {
                    MyCodes()
                } label: {
                    HStack {
                        Spacer()
                        Text("Generate New Code →")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                
                NavigationLink {
                    History()
                } label: {
                    HStack {
                        Spacer()
                        Text("History →")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                
                NavigationLink {
                    Analytics()
                } label: {
                    HStack {
                        Spacer()
                        Text("Analytics →")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        Home()
            .environmentObject(qrCodeStore)
    }
}
