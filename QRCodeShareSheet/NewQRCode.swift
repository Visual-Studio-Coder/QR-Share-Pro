//
//  NewQRCode.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

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
                Button(action:
                        {
                    self.text = ""
                })
                {
                    Image(systemName: "delete.left")
                        .foregroundColor(Color(UIColor.opaqueSeparator))
                }
                .padding(.trailing, 15)
            }
        }
    }
}

struct NewQRCode: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var text = ""
    @State private var showSavedAlert = false
    @State private var showHistorySavedAlert = false
    @State private var qrCodeImage: UIImage?
    
    @State private var savedToPhotos = false
    @State private var addedToLibrary = false
    
    @State var boughtPro = false
    @State private var colorSelection = Color.black
    
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
        Form {
            if !text.isEmpty {
                if let qrCodeImage = qrCodeImage {
                    Image(uiImage: qrCodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                    
                    Button {
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            
            TextField("Start typing...", text: $text)
                .keyboardType(.webSearch)
                .autocapitalization(.none)
                .font(.custom("SF Pro", size: 34))
                .modifier(ClearButton(text: $text))
                .onChange(of: text) { newValue in
                    generateQRCode(from: newValue)
                    addedToLibrary = false
                    savedToPhotos = false
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
                        Label("Watermark", systemImage: "water.waves")
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
                    
                    NavigationLink {
                        VStack(alignment: .leading) {
                            Text("Coming Soon")
                        }
                        .navigationTitle("Watermark")
                    } label: {
                        HStack {
                            Label("Watermark", systemImage: "water.waves")
                            Spacer()
                            Text("Coming Soon")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        VStack(alignment: .leading) {
                            Text("Coming Soon")
                        }
                        .navigationTitle("Branding Logo")
                    } label: {
                        HStack {
                            Label("Branding Logo", systemImage: "briefcase")
                            Spacer()
                            Text("Coming Soon")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("QR Code Settings")
            }
            
            if !text.isEmpty {
                HStack {
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
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        NewQRCode()
            .environmentObject(qrCodeStore)
    }
}
