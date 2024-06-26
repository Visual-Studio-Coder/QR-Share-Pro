import CoreImage.CIFilterBuiltins
import Photos
import StoreKit
import SwiftUI

class SharedData: ObservableObject {
    @Published var text: String = ""
}

struct NavigationBackButton: ViewModifier {
    @Environment(\.presentationMode) var presentationMode
    var color: Color
    var text: String
    
    func body(content: Content) -> some View {
        return content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Settings") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.backward")
                                .foregroundStyle(color)
                                .bold()
                            
                            Text(text)
                                .foregroundStyle(color)
                        }
                    } primaryAction: {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
    }
}

struct Home: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.requestReview) var requestReview
    @EnvironmentObject var sharedData: SharedData
    
    @AppStorage("showWebsiteFavicons") private var showWebsiteFavicons = AppSettings.showWebsiteFavicons
    @AppStorage("playHaptics") private var playHaptics = AppSettings.playHaptics
    @AppStorage("launchTab") private var launchTab = AppSettings.launchTab
    @AppStorage("isOnboardingDone") private var isOnboardingDone = false
    
    @State var text = "" // TODO: add a helper function that takes in widget input (please submit a PR)
    @State private var showingSettingsSheet = false
    @State private var textIsEmptyWithAnimation = true
    @State private var showSavedAlert = false
    @State private var showExceededLimitAlert = false
    @State private var showHistorySavedAlert = false
    @State private var showPermissionsError = false
    @State private var qrCodeImage: UIImage = .init()
    @State private var showingClearFaviconsConfirmation = false
    @State private var animatedText = ""
    
    let fullText = "Start typing to\ngenerate a QR code..."
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    @FocusState private var isFocused
    
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    private var allIcons = [AppIcon(iconURL: "AppIcon", iconName: "Sky Blue"), AppIcon(iconURL: "AppIcon2", iconName: "Terminal Green"), AppIcon(iconURL: "AppIcon3", iconName: "Holographic Pink")]
    private var allTabs = ["Scan QR Code", "New QR Code", "History"]
    
    private func changeColor(to iconName: String) {
        switch iconName {
        case "AppIcon2":
            AccentColorManager.shared.accentColor = .green
        case "AppIcon3":
            AccentColorManager.shared.accentColor = Color(UIColor(red: 252 / 255, green: 129 / 255, blue: 158 / 255, alpha: 1))
        default:
            AccentColorManager.shared.accentColor = Color(#colorLiteral(red: 0.3860174716, green: 0.7137812972, blue: 0.937712729, alpha: 1))
        }
    }
    
    private func changeAppIcon(to iconURL: String) {
        guard iconURL != (UserDefaults.standard.string(forKey: "appIcon") ?? "AppIcon") else { return }
        
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
    
    private func save() async throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }
    
    private func generateQRCode(from string: String) {
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
    
    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.3.0"
    }
    
    private var appBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "69"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .opacity(textIsEmptyWithAnimation ? 0.2 : 1)
                    .draggable(Image(uiImage: qrCodeImage))
                    .disabled(text.isEmpty)
                    .contextMenu {
                        if !text.isEmpty {
                            if text.count <= 3000 {
                                ShareLink(item: Image(uiImage: qrCodeImage), preview: SharePreview(text, image: Image(uiImage: qrCodeImage))) {
                                    Label("Share QR Code", systemImage: "square.and.arrow.up")
                                }
                                
                                Divider()
                            }
                            
                            Button {
                                if text.count > 3000 {
                                    showExceededLimitAlert = true
                                } else {
                                    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                        if status == .denied {
                                            showPermissionsError = true
                                        } else {
                                            UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                            showSavedAlert = true
                                            
                                            let newCode = QRCode(text: text, originalURL: text, qrCode: qrCodeImage.pngData())
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
                                }
                            } label: {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                            
                            Button {
                                if text.count > 3000 {
                                    showExceededLimitAlert = true
                                } else {
                                    let newCode = QRCode(text: text, originalURL: text, qrCode: qrCodeImage.pngData())
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
                            } label: {
                                Label("Save to History", systemImage: "clock.arrow.circlepath")
                            }
                        }
                    }
                    .overlay {
                        if text.isEmpty {
                            Text(animatedText)
                                .font(.title)
                                .multilineTextAlignment(.center)
                                .bold()
                                .onReceive(timer) { _ in
                                    let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
                                    
                                    if animatedText.count < fullText.count && isOnboardingDone {
                                        animatedText.append(fullText[fullText.index(fullText.startIndex, offsetBy: animatedText.count)])
                                        if playHaptics {
                                            hapticGenerator.impactOccurred()
                                        }
                                    } else {
                                        timer.upstream.connect().cancel()
                                    }
                                }
                        }
                    }
                
                HStack {
                    Spacer()
                    
                    Text("\(text.count)/3000 characters")
                        .foregroundStyle(text.count > 3000 ? .red : .secondary)
                        .bold()
                }
                .padding(.top, 3)
                .padding(.trailing)
                
                TextField("Create your own QR code...", text: $text)
                    .focused($isFocused)
                    .padding()
                    .background(.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .keyboardType(.alphabet)
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .onChange(of: text) { newValue in
                        generateQRCode(from: newValue)
                        
                        withAnimation {
                            textIsEmptyWithAnimation = newValue.isEmpty
                        }
                    }
                    .onTapGesture {
                        isFocused = true
                    }
                    .onSubmit {
                        isFocused = false
                        
                        if text.count > 3000 {
                            showExceededLimitAlert = true
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                
                Menu {
                    Button {
                        if text.count > 3000 {
                            showExceededLimitAlert = true
                        } else {
                            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                if status == .denied {
                                    showPermissionsError = true
                                } else {
                                    UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                    showSavedAlert = true
                                    
                                    let newCode = QRCode(text: text, originalURL: text, qrCode: qrCodeImage.pngData())
                                    qrCodeStore.history.append(newCode)
                                    
                                    Task {
                                        do {
                                            try await save()
                                        } catch {
                                            print(error.localizedDescription)
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                    }
                    
                    Button {
                        if text.count > 3000 {
                            showExceededLimitAlert = true
                        } else {
                            let newCode = QRCode(text: text, originalURL: text, qrCode: qrCodeImage.pngData())
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
                    } label: {
                        Label("Save to History", systemImage: "clock.arrow.circlepath")
                    }
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
                UINavigationBar.appearance().tintColor = .black
                generateQRCode(from: "QR Share Pro")
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .scrollDismissesKeyboard(.interactively)
            .alert("We need permission to save this QR code to your photo library.", isPresented: $showPermissionsError) {
                Button("Open Settings", role: .cancel) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString),
                       UIApplication.shared.canOpenURL(settingsURL)
                    {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            }
            .alert("You'll need to remove \(text.count - 3000) characters first!", isPresented: $showExceededLimitAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert("Saved to Photos!", isPresented: $showSavedAlert) {}
            .alert("Saved to History!", isPresented: $showHistorySavedAlert) {}
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
                        showingSettingsSheet = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettingsSheet) {
                NavigationStack {
                    List {
                        Section {
                            NavigationLink {
                                List {
                                    Section {
                                        ForEach(allIcons) { i in
                                            Button {
                                                changeAppIcon(to: i.iconURL)
                                                UserDefaults.standard.set(i.iconURL, forKey: "appIcon")
                                            } label: {
                                                HStack {
                                                    Image(systemName: i.iconURL == (UserDefaults.standard.string(forKey: "appIcon") ?? "AppIcon") ? "checkmark.circle.fill" : "circle")
                                                        .resizable()
                                                        .frame(width: 20, height: 20)
                                                        .font(.title2)
                                                        .tint(.accentColor)
                                                        .padding(.trailing, 5)
                                                    
                                                    Image(uiImage: #imageLiteral(resourceName: i.iconURL))
                                                        .resizable()
                                                        .frame(width: 50, height: 50)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        .shadow(radius: 50)
                                                    
                                                    Text(i.iconName)
                                                        .tint(.primary)
                                                }
                                            }
                                        }
                                    }
                                }
                                .accentColor(accentColorManager.accentColor)
                                .navigationTitle("App Icon & Theme")
                                .navigationBackButton(color: accentColorManager.accentColor, text: "Settings")
                            } label: {
                                Label("App Icon & Theme", systemImage: "app.gift")
                            }
                            
                            NavigationLink {
                                List {
                                    Section {
                                        Toggle(isOn: $playHaptics.animation()) {
                                            Label("Play Haptics", systemImage: "wave.3.right")
                                        }
                                    } footer: {
                                        if !playHaptics {
                                            Text("System haptics will still be played. To disable all haptics, open **Settings > Sounds & Haptics**.")
                                        } else {
                                            Text("Haptics will play when available.")
                                        }
                                    }
                                }
                                .accentColor(accentColorManager.accentColor)
                                .navigationTitle(Text("Haptics"))
                                .navigationBackButton(color: accentColorManager.accentColor, text: "Settings")
                            } label: {
                                Label("Haptics", systemImage: "hand.tap")
                            }
                            
                            NavigationLink {
                                List {
                                    Section {
                                        ForEach(allTabs, id: \.self) { i in
                                            Button {
                                                if i == "Scan QR Code" {
                                                    launchTab = .Scanner
                                                } else if i == "History" {
                                                    launchTab = .History
                                                } else {
                                                    launchTab = .NewQRCode
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: ((launchTab == .Scanner && i == "Scan QR Code") || (launchTab == .History && i == "History") || (launchTab == .NewQRCode && i == "New QR Code")) ? "checkmark.circle.fill" : "circle")
                                                        .resizable()
                                                        .frame(width: 20, height: 20)
                                                        .font(.title2)
                                                        .tint(.accentColor)
                                                        .padding(.trailing, 5)
                                                    
                                                    if i == "Scan QR Code" {
                                                        Label(i, systemImage: "camera")
                                                            .tint(.primary)
                                                    } else if i == "History" {
                                                        Label(i, systemImage: "clock.arrow.circlepath")
                                                            .tint(.primary)
                                                    } else {
                                                        Label(i, systemImage: "plus")
                                                            .tint(.primary)
                                                    }
                                                }
                                            }
                                        }
                                    } footer: {
                                        Text("Choose the default tab that appears upon app launch.")
                                    }
                                }
                                .accentColor(accentColorManager.accentColor)
                                .navigationTitle(Text("Default Tab"))
                                .navigationBackButton(color: accentColorManager.accentColor, text: "Settings")
                            } label: {
                                Label("Default Tab", systemImage: "star")
                            }
                            
                            NavigationLink {
                                NavigationStack {
                                    List {
                                        Section {
                                            Button {
                                                if let url = URL(string: "https://github.com/Visual-Studio-Coder/QR-Share-Pro/blob/master/PRIVACY.md") {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                HStack {
                                                    Label("Privacy Policy", systemImage: "checkmark.shield")
                                                    Spacer()
                                                    Image(systemName: "arrow.up.right")
                                                        .tint(.secondary)
                                                }
                                            }
                                            .tint(.primary)
                                        }
                                        
                                        Section {
                                            Toggle(isOn: $showWebsiteFavicons) {
                                                Label("Show Website Favicons", systemImage: "info.square")
                                            }
                                            .onChange(of: showWebsiteFavicons) { state in
                                                if !state {
                                                    showingClearFaviconsConfirmation = true
                                                }
                                            }
                                        } footer: {
                                            Text("Favicons are privately queried through DuckDuckGo.")
                                        }
                                        .alert("Are you sure you'd like to hide website favicons? This will clear all cached favicons.", isPresented: $showingClearFaviconsConfirmation) {
                                            Button("Hide Website Favicons", role: .destructive) {
                                                URLCache.shared.removeAllCachedResponses()
                                            }
                                            
                                            Button("Cancel", role: .cancel) {
                                                showWebsiteFavicons = true
                                            }
                                        }
                                    }
                                    .accentColor(accentColorManager.accentColor)
                                    .navigationTitle("Privacy")
                                    .navigationBackButton(color: accentColorManager.accentColor, text: "Settings")
                                }
                            } label: {
                                Label("Privacy", systemImage: "checkmark.shield")
                            }
                        }
                        
#if targetEnvironment(simulator)
                        Section {
                            Button {
                                isOnboardingDone = false
                            } label: {
                                Label("Show Onboarding", systemImage: "hand.wave")
                                    .tint(.primary)
                            }
                        }
#endif
                        
                        Section {
                            NavigationLink {
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
                                                        
                                                        Text("Version \(appVersion) (\(appBuild))")
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
                                            
                                            Button {
                                                if let url = URL(string: "https://github.com/Visual-Studio-Coder/QR-Share-Pro?tab=readme-ov-file#we--open-source") {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                HStack {
                                                    Label("Contribute", systemImage: "curlybraces")
                                                    Spacer()
                                                    Image(systemName: "arrow.up.right")
                                                        .tint(.secondary)
                                                }
                                            }
                                            .tint(.primary)
                                        }
                                        
                                        Section("Support Us") {
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
                                    }
                                    .accentColor(accentColorManager.accentColor)
                                    .navigationTitle("About QR Share Pro")
                                    .navigationBackButton(color: accentColorManager.accentColor, text: "Settings")
                                }
                            } label: {
                                Label("About QR Share Pro", systemImage: "info.circle")
                            }
                        } footer: {
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("QR Share Pro v\(appVersion) (\(appBuild))")
                                        .bold()
                                    Spacer()
                                }
                                .padding(.top)
                            }
                        }
                    }
                    .accentColor(accentColorManager.accentColor)
                    .navigationBarTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingSettingsSheet = false
                            } label: {
                                Text("Done")
                                    .tint(accentColorManager.accentColor)
                            }
                        }
                        
                        ToolbarItemGroup(placement: .keyboard) {
                            Button("Clear") {
                                text = ""
                            }
                            Spacer()
                            Button("Done") {
                                isFocused = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: isFocused) { focus in
            if focus {
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                }
            }
        }
        .onReceive(sharedData.$text) { newText in
            text = newText.removingPercentEncoding ?? ""
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
