import SwiftUI

struct HistoryDetailInfo: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @State private var isEditing = false
    @State private var showingFullURL = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSavedAlert = false
    @State private var qrCodeImage: UIImage?
    
    @State var qrCode: QRCode
    @State var originalText = ""
    
    @State var boughtPro = true
    @State private var colorSelection = Color.black
    @State private var showingBrandingLogoSheet = false
    @State private var brandingImage: Image?
    
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
        VStack {
            if isEditing {
                Form {
                    if !qrCode.text.isEmpty {
                        if let qrCodeImage = qrCodeImage {
                            if let brandingImage = brandingImage {
                                Image(uiImage: qrCodeImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        brandingImage
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 50, height: 50)
                                    )
                            } else {
                                Image(uiImage: qrCodeImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        Image(uiImage: #imageLiteral(resourceName: "AppIcon"))
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 50, height: 50)
                                    )
                            }
                            
                            Button(action: {
                                UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                showingSavedAlert = true
                            }) {
                                Label("Save to Photos", systemImage: "photo")
                            }
                            .alert(isPresented: $showingSavedAlert) {
                                Alert(title: Text("Saved to Photos!"))
                            }
                        }
                    }
                    
                    TextField("Start typing...", text: $qrCode.text)
                        .keyboardType(.webSearch)
                        .autocapitalization(.none)
                        .modifier(ClearButton(text: $qrCode.text))
                        .onChange(of: qrCode.text) { newValue in
                            generateQRCode(from: newValue)
                        }
                    
                    Section {
                        if !boughtPro {
                            HStack {
                                Label("Color", systemImage: "paintbrush")
                                Spacer()
                                Label("Pro Required", systemImage: "lock")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Label("Branding Logo", systemImage: "briefcase")
                                Spacer()
                                Label("Pro Required", systemImage: "lock")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack {
                                Label("Color", systemImage: "paintbrush")
                                Spacer()
                                ColorPicker("", selection: $colorSelection)
                            }
                            
                            Button {
                                showingBrandingLogoSheet = true
                            } label: {
                                HStack {
                                    Label("Branding Logo", systemImage: "briefcase")
                                    Spacer()
                                    Text("Choose")
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                            .sheet(isPresented: $showingBrandingLogoSheet) {
                                ImagePicker(selectedImage: $brandingImage)
                            }
                        }
                    } header: {
                        Text("QR Code Theme")
                    }
                }
                //                .onTapGesture {
                //                    // Dismiss keyboard
                //                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                //                }
                .onAppear {
                    Task {
                        if let data = qrCode.qrCode, let uiImage = UIImage(data: data) {
                            qrCodeImage = uiImage
                        }
                        
                        originalText = qrCode.text
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        qrCode.qrCode?.toImage()?
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                        
                        if isValidURL(qrCode.text) {
                            HStack {
                                AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: qrCode.text)!.host!).ico")) { i in
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
                                
                                Spacer()
                                
                                Button {
                                    if let url = URL(string: qrCode.text) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("**Open**", systemImage: "safari")
                                        .padding(8)
                                        .foregroundStyle(.white)
                                        .background(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text(qrCode.text)
                                    .lineLimit(showingFullURL ? nil : 3)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                
                                if !showingFullURL {
                                    Button {
                                        showingFullURL.toggle()
                                    } label: {
                                        Text("MORE...")
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                            
                            Divider()
                        } else {
                            Text(qrCode.text)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                        
                        HStack(spacing: 0) {
                            Text("Last updated: ")
                            
                            Text(qrCode.date, format: .dateTime)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(qrCode.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            
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
                            qrCode.date = Date.now
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
//                            print(error)
                        }
                    }
                }
                
                showingDeleteConfirmation = false
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        NavigationView {
            HistoryDetailInfo(qrCode: QRCode(text: "https://idmsa.apple.com/"))
                .environmentObject(qrCodeStore)
        }
    }
}
