import SwiftUI

struct HistoryDetailInfo: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showSavedAlert = false
    @State private var qrCodeImage: UIImage?
    
    @State var qrCode: QRCode
    @State var originalText = ""
    
    func save() async throws {
        try await qrCodeStore.save(history: qrCodeStore.history)
    }
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
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
    
    func isValidURL(_ string: String) -> Bool {
        if let url = URLComponents(string: string) {
            return url.scheme != nil && !url.scheme!.isEmpty
        } else {
            return false
        }
    }
    
    var body: some View {
        ScrollView {
            if isEditing {
                VStack {
                    if !qrCode.text.isEmpty {
                        if let qrCodeImage = qrCodeImage {
                            Image(uiImage: qrCodeImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                            
                            Button(action: {
                                UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                showSavedAlert = true
                            }) {
                                Label("Save to Photos", systemImage: "photo")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .alert(isPresented: $showSavedAlert) {
                                Alert(title: Text("Saved to Photos!"))
                            }
                        }
                    }
                    
                    ZStack(alignment: .topTrailing) {
                        TextEditor(text: $qrCode.text)
                            .frame(minHeight: 200)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 0.5))
                            .onChange(of: qrCode.text) { newValue in
                                generateQRCode(from: newValue)
                            }
                        
                        Button(action: {
                            qrCode.text = ""
                            qrCodeImage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .padding()
                        }
                        .padding()
                    }
                }
                .padding()
                .onTapGesture {
                    // Dismiss keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onAppear {
                    Task {
                        if let data = qrCode.qrCode, let uiImage = UIImage(data: data) {
                            qrCodeImage = uiImage
                        }
                        
                        originalText = qrCode.text
                    }
                }
            } else {
                VStack(alignment: .leading) {
                    qrCode.qrCode?.toImage()?
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                    
                    if isValidURL(qrCode.text) {
                        HStack {
                            AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: qrCode.text)!.host!).ico")) { i in
                                i
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } placeholder: {
                                ProgressView()
                            }
                            
                            Text(URL(string: qrCode.text)!.host!)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .lineLimit(1)
                            
                            if URL(string: qrCode.text)!.path.isEmpty {
                                Spacer()
                                
                                Button {
                                    if let url = URL(string: qrCode.text) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Open", systemImage: "safari")
                                }
                            }
                        }
                        
                        if !URL(string: qrCode.text)!.path.isEmpty {
                            HStack {
                                Text(URL(string: qrCode.text)!.path)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Button {
                                    if let url = URL(string: qrCode.text) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Open", systemImage: "safari")
                                }
                            }
                        }
                    } else {
                        Text(qrCode.text)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Generated on")
                        
                        Text(qrCode.date, format: .dateTime)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(qrCode.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if isEditing {
                        if let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                            qrCodeStore.history[idx] = qrCode
                            
                            Task {
                                do {
                                    try await save()
                                } catch {
                                    print(error)
                                }
                            }
                        }
                    }
                    
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                }
            }
        }
        .confirmationDialog("Delete QR Code?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete QR Code", role: .destructive) {
                if let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                    qrCodeStore.history.remove(at: idx)
                    
                    Task {
                        do {
                            try await save()
                        } catch {
                            print(error)
                        }
                    }
                }
                
                showingDeleteConfirmation = false
            }
            
            Button("Cancel", role: .cancel) {
                showingDeleteConfirmation = false
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        HistoryDetailInfo(qrCode: QRCode(text: "Test"))
            .environmentObject(qrCodeStore)
    }
}
