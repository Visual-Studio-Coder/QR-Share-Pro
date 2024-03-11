//
//  Home.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI
import PhotosUI
import CoreImage.CIFilterBuiltins

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
    var proRequired: Bool = true
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
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @EnvironmentObject var storeKit: StoreKitManager
    
    @State private var showingSettingsSheet = false
    @State private var showingGetProSheet = false
    
    @State private var toggleAppIconTinting = true
    @State private var boughtPro = true
    
    @State private var text = ""
    @State private var showSavedAlert = false
    @State private var showHistorySavedAlert = false
    @State private var qrCodeImage: UIImage?
    
    @State private var savedToPhotos = false
    @State private var addedToLibrary = false
    
    @State private var showingBrandingLogoSheet = false
    
    @State private var colorSelection = Color.black
    
    @State private var brandingImage: Image?
    
    //    @State private var animateGradient = false
    
    private var allIcons: [AppIcon] = [AppIcon(iconURL: "AppIcon", iconName: "Default", proRequired: false), AppIcon(iconURL: "AppIcon2", iconName: "Terminal", proRequired: false), AppIcon(iconURL: "AppIcon3", iconName: "Hologram", proRequired: false), AppIcon(iconURL: "AppIcon3", iconName: "Pro 1"), AppIcon(iconURL: "AppIcon2", iconName: "Pro 2"), AppIcon(iconURL: "AppIcon", iconName: "Pro 3")]
    
    @State private var currentlySelected = "AppIcon"
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                //                RadialGradient(colors: [.gray, .white], center: .center, startRadius: animateGradient ? 400 : 200, endRadius: animateGradient ? 20 : 40)
                ////                    .frame(height: UIScreen.main.bounds.height * 0.2)
                //                    .ignoresSafeArea()
                //                    .onAppear {
                //                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                //                            animateGradient.toggle()
                //                        }
                //                    }
                
                Form {
                    if !text.isEmpty {
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
                            
                            Button {
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    
                    TextField("Start typing...", text: $text)
                        .keyboardType(.webSearch)
                        .autocapitalization(.none)
                        .modifier(ClearButton(text: $text))
                        .onChange(of: text) { newValue in
                            generateQRCode(from: newValue)
                            addedToLibrary = false
                            savedToPhotos = false
                        }
                    //                        .onTapGesture {
                    //                            // Dismiss keyboard
                    //                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    //                        }
                    
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
                        }
                    } header: {
                        Text("QR Code Theme")
                    }
                    
                    if !text.isEmpty {
                        Button {
                            if let qrCodeImage = qrCodeImage {
                                UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                savedToPhotos = true
                                showSavedAlert = true
                            }
                        } label: {
                            Label(savedToPhotos ? "Saved to Photos" : "Save to Photos", systemImage: savedToPhotos ? "checkmark" : "square.and.arrow.down.fill")
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
                                
                                addedToLibrary = true
                                showHistorySavedAlert = true
                            }
                        } label: {
                            Label(addedToLibrary ? "Added to Library" : "Add to Library", systemImage: addedToLibrary ? "checkmark" : "plus")
                        }
                        .alert("Saved to Photos!", isPresented: $showSavedAlert) {
                            Button("OK", role: .cancel) {}
                        }
                        .alert("Saved to Library!", isPresented: $showHistorySavedAlert) {
                            Button("OK", role: .cancel) {}
                        }
                    }
                }
                .navigationTitle("New QR Code")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettingsSheet = true
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                    }
                }
                .sheet(isPresented: $showingBrandingLogoSheet) {
                    ImagePicker(selectedImage: $brandingImage)
                }
                .sheet(isPresented: $showingSettingsSheet) {
                    NavigationView {
                        List {
                            if !boughtPro {
                                Section {
                                    NavigationLink {
                                        GetPro()
                                            .environmentObject(storeKit)
                                    } label: {
                                        Label("**QR Share Pro** - $1.99", systemImage: "crown.fill")
                                    }
                                }
                            }
                            
                            Section {
                                NavigationLink {
                                    List {
                                        Section {
                                            ForEach(allIcons.filter { !$0.proRequired }) { i in
                                                Button {
                                                    changeAppIcon(to: i.iconURL)
                                                    currentlySelected = i.iconURL
                                                } label: {
                                                    HStack {
                                                        Image(systemName: i.iconURL == currentlySelected ? "checkmark.circle.fill" : "circle")
                                                            .font(.title2)
                                                        
                                                        Image(uiImage: #imageLiteral(resourceName: i.iconURL))
                                                            .resizable()
                                                            .frame(width: 50, height: 50)
                                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                                            .shadow(radius: 50)
                                                        
                                                        Text(i.iconName)
                                                    }
                                                }
                                            }
                                        } header: {
                                            Text("Free Icons")
                                        }
                                        
                                        Section {
                                            ForEach(allIcons.filter { $0.proRequired }) { i in
                                                Button {
                                                    //                        changeAppIcon(to: i.iconURL)
                                                    //                        currentlySelected = i.iconURL
                                                } label: {
                                                    HStack {
                                                        //                            Image(systemName: i.iconURL == currentlySelected ? "checkmark.circle.fill" : "circle")
                                                        //                                .font(.title2)
                                                        
                                                        Image(systemName: "lock")
                                                        
                                                        Image(uiImage: #imageLiteral(resourceName: i.iconURL))
                                                            .resizable()
                                                            .frame(width: 50, height: 50)
                                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                                            .shadow(radius: 50)
                                                        
                                                        Text(i.iconName)
                                                        
                                                        Spacer()
                                                        
                                                        Text("Pro Required")
                                                    }
                                                }
                                                .foregroundStyle(.secondary)
                                            }
                                        } header: {
                                            Text("Pro Icons")
                                        }
                                    }
                                    .navigationTitle("App Icon")
                                    .navigationBarTitleDisplayMode(.inline)
                                } label: {
                                    HStack {
                                        Label("App Icon", systemImage: "square.grid.3x3.square")
                                        Spacer()
                                        Text("Default")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Toggle(isOn: $toggleAppIconTinting) {
                                    Label("App Icon Tinting for Icons", systemImage: "drop.halffull")
                                }
                            } header: {
                                Text("App Icon")
                            }
                            
                            Section {
                                Toggle(isOn: $boughtPro) {
                                    Label("Enable Pro Features", systemImage: "hammer")
                                }
                            } header: {
                                Text("Developer")
                            }
                            
                            Section {
                                HStack {
                                    Image(uiImage: #imageLiteral(resourceName: "AppIcon"))
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    
                                    VStack(alignment: .leading) {
                                        Text(boughtPro ? "QR Share Pro" : "QR Share")
                                            .bold()
                                        Text("Version 0.0.1")
                                            .foregroundStyle(.secondary)
                                        Text("The [X] Company")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                HStack {
                                    Label("Rate App", systemImage: "star")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack {
                                    Label("Share App", systemImage: "square.and.arrow.up")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                Text(boughtPro ? "QR Share Pro" : "QR Share")
                            }
                        }
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
                .sheet(isPresented: $showingGetProSheet) {
                    NavigationView {
                        GetPro()
                            .environmentObject(storeKit)
                    }
                }
            }
        }
        .onChange(of: storeKit.purchasedPlan) { course in
            Task {
                boughtPro = (try? await storeKit.isPurchased(storeKit.storeProducts[0])) ?? false
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        @StateObject var storeKit = StoreKitManager()
        
        Home()
            .environmentObject(qrCodeStore)
            .environmentObject(storeKit)
    }
}
