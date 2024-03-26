//
//  Home.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import StoreKit

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
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @Environment(\.requestReview) var requestReview
    
    @State private var showingAboutAppSheet = false
    @State private var text = ""
    @State private var showSavePhotosQuestionAlert = false
    @State private var showSavedAlert = false
    @State private var showHistorySavedAlert = false
    @State private var qrCodeImage: UIImage = UIImage()
    
    @FocusState private var isFocused
    
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    private var allIcons: [AppIcon] = [AppIcon(iconURL: "AppIcon", iconName: "Default"), AppIcon(iconURL: "AppIcon2", iconName: "Terminal"), AppIcon(iconURL: "AppIcon3", iconName: "Hologram")]
    
    private func changeColor(to iconName: String) {
        switch iconName {
        case "AppIcon2":
            AccentColorManager.shared.accentColor = Color.mint
        case "AppIcon3":
            AccentColorManager.shared.accentColor = Color(UIColor(red: 252/255, green: 129/255, blue: 158/255, alpha: 1))
        default:
            AccentColorManager.shared.accentColor = Color(#colorLiteral(red: 0.3860174716, green: 0.7137812972, blue: 0.937712729, alpha: 1))
        }
    }
    
    private func changeAppIcon(to iconURL: String) {
        let iconName = iconURL == "AppIcon" ? nil : iconURL
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
        }
        
        changeColor(to: iconName ?? "AppIcon")
    }
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    func save() async throws {
        qrCodeStore.save(history: qrCodeStore.history)
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
    
    var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                
                TextField("Create your own QR code...", text: $text)
                    .keyboardType(.webSearch)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: text) { newValue in
                        generateQRCode(from: newValue)
                    }
                    .onTapGesture {
                        isFocused = true
                    }
                    .onSubmit {
                        isFocused = false
                    }
                    .focused($isFocused)
                
                Section {}
                
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
                    UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                    showSavedAlert = true
                    
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
                
                Button("No") {
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
            .alert("Saved to Photos!", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert("Saved to History!", isPresented: $showHistorySavedAlert) {
                Button("OK", role: .cancel) {}
            }
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    let qrCodeImage = Image(uiImage: qrCodeImage)
                    
                    ShareLink(item: qrCodeImage, preview: SharePreview(text, image: qrCodeImage)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(text.isEmpty)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAboutAppSheet = true
                    } label: {
                        Label("About QR Share", systemImage: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAboutAppSheet) {
                NavigationStack {
                    List {
                        Section {
                            ShareLink(item: URL(string: "https://aaronhma.com")!) {
                                HStack {
                                    Image(uiImage: #imageLiteral(resourceName: UserDefaults.standard.string(forKey: "appIcon") ?? "AppIcon"))
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: .accentColor, radius: 8)
                                    
                                    VStack(alignment: .leading) {
                                        Text("QR Share")
                                            .bold()
                                        
                                        Text("Version \(appVersion)")
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title)
                                        .bold()
                                        .foregroundStyle(.secondary)
                                }
                                .tint(.primary)
                            }
                            
                            Button {
                                requestReview()
                            } label: {
                                HStack {
                                    Label("Rate App", systemImage: "star")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                        
                        Section("App Icon") {
                            ForEach(allIcons) { i in
                                Button {
                                    changeAppIcon(to: i.iconURL)
                                    UserDefaults.standard.set(i.iconURL, forKey: "appIcon")
                                } label: {
                                    HStack {
                                        Image(systemName: i.iconURL == UserDefaults.standard.string(forKey: "appIcon") ? "checkmark.circle.fill" : "circle")
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
                        }
                        
                        Section("Credits") {
                            Button {
                                if let url = URL(string: "https://github.com/Visual-Studio-Coder") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                VStack {
                                    HStack {
                                        Label("Vaibhav Satishkumar", systemImage: "person")
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .tint(.secondary)
                                    }
                                }
                            }
                            .tint(.primary)
                            
                            Button {
                                if let url = URL(string: "https://aaronhma.com") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Label("Aaron Ma", systemImage: "person")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .tint(.secondary)
                                }
                            }
                            .tint(.primary)
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
            }
        }
        .onChange(of: isFocused) { focus in
            if focus {
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
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
