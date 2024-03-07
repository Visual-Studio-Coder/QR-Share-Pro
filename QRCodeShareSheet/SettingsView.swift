import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.0.1")
                        .foregroundColor(.secondary)
                }
                
                Text("Made with 💖 & 😀 from Cupertino, CA.")
            } header: {
                Text("About QR Code")
            }
            
            Section {
                Button {} label: {
                    Text("Get Pro")
                }
            } header: {
                Text("QR Code Pro")
            }
            
            Section {
                Text("You'll get 1 week of **QR Code Pro** for free for every friend you refer.")
                
                Button {} label: {
                    Text("Share App")
                }
            } header: {
                Text("Share QR Code")
            }
        }
    }
}

#Preview {
    SettingsView()
}
