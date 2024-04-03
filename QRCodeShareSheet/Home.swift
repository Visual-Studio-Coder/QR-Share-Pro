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
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.requestReview) var requestReview
    
    //    @State var showingTabView: Bool = false
    
    @State private var showingAboutAppSheet = false
    @State private var text = ""
    @State private var showSavePhotosQuestionAlert = false
    @State private var showSavedAlert = false
    @State private var showHistorySavedAlert = false
    @State private var showingWhatsNewAlert = false
    @State private var qrCodeImage: UIImage = UIImage()
    
    @FocusState private var isFocused
    
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    private var allIcons: [AppIcon] = [AppIcon(iconURL: "AppIcon", iconName: "Sky Blue (Default)"), AppIcon(iconURL: "AppIcon2", iconName: "Terminal Green"), AppIcon(iconURL: "AppIcon3", iconName: "Holographic Pink")]
    
    private func changeColor(to iconName: String) {
        switch iconName {
        case "AppIcon2":
            AccentColorManager.shared.accentColor = colorScheme == .dark ? .green.opacity(0.01) : .mint
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
                print(error.localizedDescription)
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
            ScrollView {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                
                TextField("Create your own QR code...", text: $text)
                    .padding()
                    .background(.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
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
                        
                        if !text.isEmpty {
                            showSavePhotosQuestionAlert = true
                        }
                    }
                    .focused($isFocused)
                    .padding(.horizontal)
                
                Button {
                    showSavePhotosQuestionAlert = true
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .foregroundStyle(.white)
                        .opacity(text.isEmpty ? 0.3 : 1)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(colorScheme == .dark ? 0.7 : 1))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .disabled(text.isEmpty)
                .padding(.horizontal)
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
                            print(error.localizedDescription)
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
                            print(error.localizedDescription)
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
                        Label("About QR Share Pro", systemImage: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAboutAppSheet) {
                NavigationStack {
                    List {
                        Section {
                            ShareLink(item: URL(string: "https://apps.apple.com/us/app/qr-share-pro/id6479589995")!) {
                                HStack {
                                    Image(uiImage: #imageLiteral(resourceName: UserDefaults.standard.string(forKey: "appIcon") ?? "AppIcon"))
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: .accentColor, radius: 5)
                                    
                                    VStack(alignment: .leading) {
                                        Text("QR Share Pro")
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
                        
                        Section("Release Notes") {
#if targetEnvironment(simulator)
                            Button {
                                showingWhatsNewAlert = true
                            } label: {
                                Label("Developer Beta 1", systemImage: "hammer")
                            }
                            .buttonStyle(PlainButtonStyle())
#else
                            Button {
                                showingWhatsNewAlert = true
                            } label: {
                                Label("TestFlight Beta 6", systemImage: "hammer")
                            }
                            .buttonStyle(PlainButtonStyle())
#endif
                            
                            Button {
                                showingWhatsNewAlert = true
                            } label: {
                                Text("See what's new...")
                                    .bold()
                            }
                        }
                        .alert("This version contains:\n\n- Redesigned QR code form\n- Redesigned History tab\n- Updated URL shortening\n- Official passkey support without app crashing\n- QR Share is now QR Share Pro\n- Bug fixes & improvements", isPresented: $showingWhatsNewAlert) {}
                        
                        Section("App Icon & Themes") {
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
                    .navigationBarTitle("About QR Share Pro")
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
