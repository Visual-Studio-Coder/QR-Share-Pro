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

class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()
    
    var accentColor: Color {
        get {
            let colorData = UserDefaults.standard.data(forKey: "accentColor")
            let uiColor = colorData != nil ? UIColor.colorWithData(colorData!) : UIColor(Color(#colorLiteral(red: 0.3860174716, green: 0.7137812972, blue: 0.937712729, alpha: 1)))
            return Color(uiColor)
        }
        set {
            let uiColor = UIColor(newValue)
            UserDefaults.standard.set(uiColor.encode(), forKey: "accentColor")
            objectWillChange.send()
        }
    }
}

extension UIColor {
    func encode() -> Data {
        return try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
    }
    
    static func colorWithData(_ data: Data) -> UIColor {
        return try! NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)!
    }
}

struct AppIcon: Identifiable {
    var id = UUID()
    var iconURL: String
    var iconName: String
}

struct Home: View {
    @AppStorage("appIcon") private var appIcon = "AppIcon"
    @AppStorage("toggleAppIconTinting") private var toggleAppIconTinting = false
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    @State private var showingAboutAppSheet = false
    @State private var text = ""
    @State private var showSavePhotosQuestionAlert = false
    @State private var showSavedAlert = false
    @State private var showHistorySavedAlert = false
    @State private var qrCodeImage: UIImage?
    
    @State private var showingBrandingLogoSheet = false
    
    @State private var brandingImage: Image?
    
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    private var allIcons: [AppIcon] = [AppIcon(iconURL: "AppIcon", iconName: "Default"), AppIcon(iconURL: "AppIcon2", iconName: "Terminal"), AppIcon(iconURL: "AppIcon3", iconName: "Hologram")]
    
    private func changeAppIcon(to iconURL: String) {
            let iconName = iconURL == "AppIcon" ? nil : iconURL

            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error = error {
                    fatalError(error.localizedDescription)
                }
            }

            switch iconName {
            case "AppIcon2":
                AccentColorManager.shared.accentColor = Color(.green)
            case "AppIcon3":
                AccentColorManager.shared.accentColor = Color(UIColor(red: 252/255, green: 129/255, blue: 158/255, alpha: 1))
            default:
                AccentColorManager.shared.accentColor = Color(#colorLiteral(red: 0.3860174716, green: 0.7137812972, blue: 0.937712729, alpha: 1))
            }
        }
        
        switch iconName {
        case "AppIcon2":
            AccentColorManager.shared.accentColor = Color.mint
        case "AppIcon3":
            AccentColorManager.shared.accentColor = Color(UIColor(red: 252/255, green: 129/255, blue: 158/255, alpha: 1))
        default:
            AccentColorManager.shared.accentColor = Color(#colorLiteral(red: 0.3860174716, green: 0.7137812972, blue: 0.937712729, alpha: 1))
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
                
                Button {
                    showSavePhotosQuestionAlert = true
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(text.isEmpty)
            }
            .navigationTitle("New QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                generateQRCode(from: "never gonna give you up")
            }
            .alert("Save to Photos?", isPresented: $showSavePhotosQuestionAlert) {
                Button("Yes") {
                    if let qrCodeImage = qrCodeImage {
                        UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                        showSavedAlert = true
                    }
                    
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
                }
                
                Button("No") {
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
                }
            }
            .alert("Saved to Photos!", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert("Saved to Library!", isPresented: $showHistorySavedAlert) {
                Button("OK", role: .cancel) {}
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
                        Label("About QR Share", systemImage: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingBrandingLogoSheet) {
                ImagePicker(selectedImage: $brandingImage)
            }
            .sheet(isPresented: $showingAboutAppSheet) {
                NavigationView {
                    List {
                        Section("About QR Share") {
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
                        }
                        
                        Section("App Icon") {
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
                                                        .tint(.accentColor)
                                                    
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
                        }
                        
                        Section("Tinting") {
                            Toggle(isOn: $toggleAppIconTinting) {
                                Label("Icon & Button Tinting", systemImage: "drop.halffull")
                            }
                        }
                        
                        Section("Contributors") {
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
                        } header: {
                            Text("Contributors")
                        }
                        
                        Section("Support Us") {
                            Button {
                                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                                    DispatchQueue.main.async {
                                        SKStoreReviewController.requestReview(in: scene)
                                    }
                                }
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
                                if let url = URL(string: "https://aaronhma.com") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Label("Feature Request", systemImage: "star.bubble")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .tint(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                        
                        Section("Legal & Copyright") {
                            Label("Copyright © 2024 Aaron Ma, Vaibhav Satishkumar. All Rights Reserved.", systemImage: "quote.opening")
                            
                            Button {
                                if let url = URL(string: "https://aaronhma.com") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Label("MIT License", systemImage: "text.quote")
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
                        }
                        
                        Section("Environment") {
#if targetEnvironment(simulator)
                            Label("Xcode Simulator", systemImage: "hammer")
#else
                            Label("Production", systemImage: "iphone.gen3")
#endif
                        }
                    }
                    .accentColor(accentColorManager.accentColor)
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
                .accentColor(accentColorManager.accentColor)
            }
        }
        .onChange(of: toggleAppIconTinting) { _ in
            if !toggleAppIconTinting {
                AccentColorManager.shared.accentColor = Color.blue
            } else {
                changeAppIcon(to: appIcon)
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
class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()

    var accentColor: Color {
        get {
            let colorData = UserDefaults.standard.data(forKey: "accentColor")
            let uiColor = colorData != nil ? UIColor.colorWithData(colorData!) : UIColor(Color(#colorLiteral(red: 0.3860174716, green: 0.7137812972, blue: 0.937712729, alpha: 1)))
            return Color(uiColor)
        }
        set {
            let uiColor = UIColor(newValue)
            UserDefaults.standard.set(uiColor.encode(), forKey: "accentColor")
            objectWillChange.send()
        }
    }
}

extension UIColor {
    func encode() -> Data {
        return try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
    }

    static func colorWithData(_ data: Data) -> UIColor {
        return try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! UIColor
    }
}
