//
//  NewQRCode.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct NewQRCode: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var text = ""
    @State private var showSavedAlert = false
    @State private var showHistorySavedAlert = false
    @State private var qrCodeImage: UIImage?
    
    @State private var savedToPhotos = false
    @State private var addedToLibrary = false
    
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
                .padding()
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $text)
                .frame(minHeight: 150)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 0.5))
                .onChange(of: text) { newValue in
                    generateQRCode(from: newValue)
                    addedToLibrary = false
                    savedToPhotos = false
                }
                .font(.custom("Helvetica", size: 34))
            
            Button(action: {
                text = ""
                qrCodeImage = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .padding()
            }
            .padding()
        }
        .padding()
        
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
                .padding()
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
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
                .padding()
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
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

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        NewQRCode()
            .environmentObject(qrCodeStore)
    }
}