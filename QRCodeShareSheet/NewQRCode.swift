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
    
    @State private var selection = "Photos"
    private var allSaveChoices = ["Photos", "History"]
    
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
                .cornerRadius(10)
            }
        }
        
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $text)
                .frame(minHeight: 150)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 0.5))
                .onChange(of: text) { newValue in
                    generateQRCode(from: newValue)
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
        
        if !text.isEmpty {
            HStack {
                Picker("Save", selection: $selection) {
                    ForEach(allSaveChoices, id: \.self) {
                        Text($0)
                    }
                }
                
                Button {
                    if let qrCodeImage = qrCodeImage {
                        if selection == "Photos" {
                            UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                            showSavedAlert = true
                        } else {
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
                } label: {
                    Text("Save →")
                        .fontWeight(.bold)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .alert("Saved to Photos!", isPresented: $showSavedAlert) {
                    Button("OK", role: .cancel) {}
                }
                .alert("Saved to History!", isPresented: $showHistorySavedAlert) {
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
