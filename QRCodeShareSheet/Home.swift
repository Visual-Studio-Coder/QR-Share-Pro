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
            //            self.parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct AppIcon: Identifiable {
    var id = UUID()
    var iconURL: String
    var iconName: String
}

struct ClearButton: ViewModifier
{
    @Binding var text: String
    
    public func body(content: Content) -> some View
    {
        ZStack(alignment: .trailing)
        {
            content
            
            if !text.isEmpty
            {
                Button {
                    self.text = ""
                } label: {
                    Image(systemName: "delete.left")
                        .foregroundColor(Color(UIColor.opaqueSeparator))
                }
                .padding(.trailing, 15)
            }
        }
    }
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
    
    @State private var forceUpdate: Bool = false
    
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
            ZStack {
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
                                        .frame(width: 50, height: 50)
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
                                        .frame(width: 50, height: 50)
                                )
                        }
                    }
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .keyboardType(.webSearch)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: text) { newValue in
                                generateQRCode(from: newValue)
                            }
                        Text(text.isEmpty ? "Enter text here…" : "")
                            .foregroundColor(.gray)
                            .opacity(text.isEmpty ? 1 : 0)
                            .padding(.all, 8) // Add padding
                            .font(.system(size: 16)) // Adjust font size
                    }
                    
                    
                    Section(header: Text("Branding Logo")) {
                        Menu {
                            Button(action: {
                                brandingImage = nil
                                forceUpdate.toggle()
                            }) {
                                Label("Clear Logo", systemImage: "xmark")
                            }
                            Button(action: {
                                showingBrandingLogoSheet = true
                            }) {
                                Label("Choose from Photos", systemImage: "photo.stack")
                            }
                            Button(action: {
                                showingBrandingLogoSheet = true
                            }) {
                                Label("Choose from Files", systemImage: "doc")
                            }
                        } label: {
                            Label("Choose Branding Logo", systemImage: "photo.stack")
                        }
                    }
                    
                    Section(header: Text("Save")) {
                        Menu {
                            Button(action: {
                                if let qrCodeImage = qrCodeImage {
                                    UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                    showSavedAlert = true
                                }
                            }) {
                                Label("Save to Photos", systemImage: "photo.stack")
                            }
                            
                            Button(action: {
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
                            }) {
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
                            Label("Save Options", systemImage: "square.and.arrow.down")
                        }
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
                                
                                Button(action: {
                                    // Add your action here
                                }) {
                                    HStack {
                                        Label("Share App", systemImage: "square.and.arrow.up")
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Button(action: {
                                    // Add your action here
                                }) {
                                    HStack {
                                        Label {
                                            Text("Github")
                                        } icon: {
                                            Image(decorative: colorScheme == .dark ? "github-mark-white" : "github-mark")
                                                .resizable()
                                                .scaledToFit()
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } header: {
                                Text("QR Share")
                            }
                            
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
                                Text("App Icon")
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
        }.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
