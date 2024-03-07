import SwiftUI

struct Home: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @State private var text = ""
    @State private var qrCodeImage: UIImage?
    @State private var showingSettingsSheet = false
    @State private var showingGetProSheet = false
    @State private var showSavedAlert = false
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    func save() async throws {
        try await qrCodeStore.save(history: qrCodeStore.history)
    }
    
    func generateQRCode(from string: String) {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let qrCode = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledQrCode = qrCode.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledQrCode, from: scaledQrCode.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    if !text.isEmpty {
                        if let qrCodeImage = qrCodeImage {
                            Image(uiImage: qrCodeImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                            
                            HStack {
                                Button(action: {
                                    UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                    showSavedAlert = true
                                }) {
                                    Label("Save to Photos", systemImage: "photo")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .alert(isPresented: $showSavedAlert) {
                                    Alert(title: Text("Saved to Photos!"))
                                }
                                
                                Button {
                                    let newCode = QRCode(name: text, qrCode: qrCodeImage.pngData(), tinyURL: "https://tinyurl.com/rickroll")
                                    
                                    qrCodeStore.history.append(newCode)
                                    
                                    Task {
                                        do {
                                            try await save()
                                        } catch {
                                            fatalError(error.localizedDescription)
                                        }
                                    }
                                } label: {
                                    Label("Share Link", systemImage: "link")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    ZStack(alignment: .topTrailing) {
                        TextEditor(text: $text)
                            .frame(minHeight: 200)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 0.5))
                            .onChange(of: text) { newValue in
                                generateQRCode(from: newValue)
                            }
                        
                        Button(action: {
                            text = ""
                            qrCodeImage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .padding()
                        }
                        .padding()
                    }
                    
                    Divider()
                    
                    VStack {
                        LinearGradient(colors: [.green, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        
                        Text("**QR Share Pro**")
                            .font(.title2)
                        
                        Text("Customize your QR codes, get detailed insights, and more. All for just $1.99/year.")
                            .multilineTextAlignment(.center)
                        
                        Button {
                            showingGetProSheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Get Pro →")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        .sheet(isPresented: $showingGetProSheet) {
                            NavigationView {
                                GetPro()
                                    .navigationBarTitle("QR Share Pro")
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button {
                                                showingSettingsSheet = false
                                            } label: {
                                                Text("Done")
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding()
                .onTapGesture {
                    // Dismiss keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("QR Share")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettingsSheet) {
                NavigationView {
                    SettingsView()
                        .navigationBarTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showingSettingsSheet = false
                                } label: {
                                    Text("Done")
                                }
                            }
                        }
                }
            }
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
