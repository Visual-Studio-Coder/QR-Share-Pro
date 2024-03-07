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
    @State private var qrCodeImage: UIImage?
    
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
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding()
                
                HStack {
                    Button(action: {
                        UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                        showSavedAlert = true
                    }) {
                        Label("Save to Photos", systemImage: "photo")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                    .alert(isPresented: $showSavedAlert) {
                        Alert(title: Text("Saved to Photos!"))
                    }
                    
                    Button {
                        let newCode = QRCode(text: text, qrCode: qrCodeImage.pngData())
                        
                        qrCodeStore.history.append(newCode)
                        
                        Task {
                            do {
                                try await save()
                            } catch {
                                fatalError(error.localizedDescription)
                            }
                        }
                    } label: {
                        Label("Share Link", systemImage: "link")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
            }
        }
        
        ZStack(alignment: .topTrailing) {
            ZStack {
                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 0.5))
                    .onChange(of: text) { newValue in
                        generateQRCode(from: newValue)
                    }
                    .font(.custom("Helvetica", size: 34))
                
                if text.isEmpty {
                    VStack {
                        HStack {
                            Text("Share anything with a QR code...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .font(.custom("Helvetica", size: 34))
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                }
            }
            
            Button(action: {
                text = ""
                qrCodeImage = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .padding()
            }
            .padding()
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
