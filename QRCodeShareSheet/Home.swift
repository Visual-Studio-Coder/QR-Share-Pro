//
//  Home.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI
import PhotosUI
import CoreImage.CIFilterBuiltins
import StoreKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: Image?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    class Coordinator: PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if let selectedImage = results.first {
                selectedImage.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let uiImage = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.selectedImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
            picker.dismiss(animated: true)
        }
    }
}

struct AppIcon: Identifiable {
    var id = UUID()
    var iconURL: String
    var iconName: String
}

struct Home: View {
    @AppStorage("appIcon") private var appIcon = "AppIcon"
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingAboutAppSheet = false
    @State private var text = ""
    @State private var showSavedAlert = false
    @State private var showHistorySavedAlert = false
    @State private var qrCodeImage: UIImage?
    
    @State private var showingBrandingLogoSheet = false
    
    //    @State private var colorSelection = Color.black
    
    @State private var brandingImage: Image?
    
    private var allIcons: [AppIcon] = [AppIcon(iconURL: "AppIcon", iconName: "Default"), AppIcon(iconURL: "AppIcon2", iconName: "Terminal"), AppIcon(iconURL: "AppIcon3", iconName: "Hologram")]
    
    private func changeAppIcon(to iconURL: String) {
        let iconName = iconURL == "AppIcon" ? nil : iconURL
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
        }
    }
    
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
    
    func appVersion(in bundle: Bundle = .main) -> String {
        guard let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            fatalError("CFBundleShortVersionString missing from info dictionary")
        }
        
        return version
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let qrCodeImage = qrCodeImage {
                    if let brandingImage = brandingImage {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                brandingImage
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            )
                    } else {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(uiImage: #imageLiteral(resourceName: appIcon))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            )
                    }
                }
                
                TextField("Create your own QR code...", text: $text)
                    .keyboardType(.webSearch)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: text) { newValue in
                        generateQRCode(from: newValue)
                    }
                
                Section {}
                
                Menu {
                    Button {
                        brandingImage = nil
                    } label: {
                        Label("Clear Logo", systemImage: "xmark")
                    }
                    
                    Divider()
                    
                    Button {
                        showingBrandingLogoSheet = true
                    } label: {
                        Label("Choose from Photos", systemImage: "photo.stack")
                    }
                    
                    Button {
                        showingBrandingLogoSheet = true
                    } label: {
                        Label("Choose from Files", systemImage: "doc")
                    }
                } label: {
                    Label("Choose Branding Logo", systemImage: "photo.stack")
                }
                
                Menu {
                    Button {
                        if let qrCodeImage = qrCodeImage {
                            UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                            showSavedAlert = true
                        }
                    } label: {
                        Label("Save to Photos", systemImage: "photo.stack")
                    }
                    
                    Button {
                        if let qrCodeImage = qrCodeImage {
                            let newCode = QRCode(text: text, qrCode: qrCodeImage.pngData())
                            qrCodeStore.history.append(newCode)
                            Task {
                                do {
                                    try await save()
                                } catch {
                                    fatalError(error.localizedDescription)
                                }
                            }
                            showHistorySavedAlert = true
                        }
                    } label: {
                        Label("QR Share Library", systemImage: "books.vertical.fill")
                    }
                    
                    Button(action: {
                        if let qrCodeImage = qrCodeImage {
                            UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                            let newCode = QRCode(text: text, qrCode: qrCodeImage.pngData())
                            qrCodeStore.history.append(newCode)
                            Task {
                                do {
                                    try await save()
                                } catch {
                                    fatalError(error.localizedDescription)
                                }
                            }
                            showSavedAlert = true
                            showHistorySavedAlert = true
                        }
                    }) {
                        Label("Both", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
            .navigationTitle("New QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                generateQRCode(from: "never gonna give you up")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {} label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAboutAppSheet = true
                    } label: {
                        Label("About QR Share", systemImage: "info.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingBrandingLogoSheet) {
                ImagePicker(selectedImage: $brandingImage)
            }
            .sheet(isPresented: $showingAboutAppSheet) {
                NavigationView {
                    List {
                        Section {
                            HStack {
                                Image(uiImage: #imageLiteral(resourceName: appIcon))
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                
                                VStack(alignment: .leading) {
                                    Text("QR Share")
                                        .bold()
                                    Text("Version \(appVersion())")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Label("Environment: Xcode Simulator", systemImage: "globe.americas.fill")
                        } header: {
                            Text("About QR Share")
                        }
                        
                        Section {
                            NavigationLink {
                                List {
                                    Section {
                                        ForEach(allIcons) { i in
                                            Button {
                                                changeAppIcon(to: i.iconURL)
                                                appIcon = i.iconURL
                                            } label: {
                                                HStack {
                                                    Image(systemName: i.iconURL == appIcon ? "checkmark.circle.fill" : "circle")
                                                        .font(.title2)
                                                        .tint(.blue)
                                                    
                                                    Image(uiImage: #imageLiteral(resourceName: i.iconURL))
                                                        .resizable()
                                                        .frame(width: 50, height: 50)
                                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                                        .shadow(radius: 50)
                                                    
                                                    Text(i.iconName)
                                                        .tint(.primary)
                                                }
                                            }
                                        }
                                    } header: {
                                        Text("All App Icons")
                                    }
                                }
                                .navigationTitle("App Icon")
                                .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                Label("App Icon", systemImage: "square.grid.3x3.square")
                            }
                        } header: {
                            Text("App Icon")
                        }
                        
                        Section {
                            Button {
                                if let url = URL(string: "https://aaronhma.com") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Label("Aaron Ma", systemImage: "person.fill")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .tint(.secondary)
                                }
                            }
                            .tint(.primary)
                            
                            Button {
                                if let url = URL(string: "https://github.com/Visual-Studio-Coder") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Label("Vaibhav Satishkumar", systemImage: "person.fill")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .tint(.secondary)
                                }
                            }
                            .tint(.primary)
                        } header: {
                            Text("Credits")
                        }
                        
                        Section {
                            Button {
                                SKStoreReviewController.requestReview()
                            } label: {
                                HStack {
                                    Label("Rate App", systemImage: "star")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                            
                            Button {} label: {
                                HStack {
                                    Label("Share App", systemImage: "square.and.arrow.up")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                            
                            Button {
                                if let url = URL(string: "https://github.com/Visual-Studio-Coder/QRCodeShareSheet") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Label("Contribute (GitHub)", systemImage: "curlybraces")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .tint(.secondary)
                                }
                            }
                            .tint(.primary)
                        } header: {
                            Text("Support Us")
                        }
                    }
                    .navigationBarTitle("About QR Share")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingAboutAppSheet = false
                            } label: {
                                Text("Done")
                            }
                        }
                    }
                }
            }
        }
        //        .onTapGesture {
        //            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        //        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        Home()
            .environmentObject(qrCodeStore)
    }
}
