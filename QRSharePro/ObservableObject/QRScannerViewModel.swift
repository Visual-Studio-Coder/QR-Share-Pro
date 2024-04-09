//
//  QRScannerViewModel.swift
//  QRSharePro
//
//  Created by Aaron Ma on 4/3/24.
//

import SwiftUI
import AVFoundation

class QRScannerViewModel: ObservableObject, QRScannerControllerDelegate {
    @ObservedObject var locationManager = LocationManager()
    
    //    @Published var isURL: Bool = true
    @Published var detectedURL: URL?
    @Published var unshortenedURL: URL?
    @Published var detectedString: String?
    
    @Published var isScanning = false
    @Published var isLoading = false
    @Published var cameraError = true
    
    @Published var qrCodeImage: UIImage?
    @Published var qrCode: QRCode
    
    var qrCodeStore: QRCodeStore
    
    func save() throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }
    
    let scannerController = QRScannerController()
    
    init(qrCodeStore: QRCodeStore) {
        self.qrCodeStore = qrCodeStore
        self.qrCode = QRCode(text: "", originalURL: "")
        scannerController.delegate = self
    }
    
    func startScanning() {
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.scannerController.startScanning()
            self.cameraError = false
        }
    }
    
    func stopScanning() {
        isScanning = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.scannerController.stopScanning()
        }
    }
    
    @Published var lastDetectedURL: URL?
    @Published var lastDetectedString: String?
    
    let filter = CIFilter.qrCodeGenerator()
    let context = CIContext()
    
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
    
    @MainActor func didDetectQRCode(string: String) {
        guard string != lastDetectedString else { return }
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        generateQRCode(from: string)
        
        if let qrCodeImage = self.qrCodeImage, let pngData = qrCodeImage.pngData() {
            var userLocation: [Double] = [] // re-write user's location in memory
            
            if let location = locationManager.location {
                userLocation = [location.latitude, location.longitude]
            } else {
                print("Could not get user location.")
            }
            
            let newCode = QRCode(text: string, originalURL: string, qrCode: pngData, scanLocation: userLocation, wasScanned: true)
            
            qrCodeStore.history.append(newCode)
            
            Task {
                do {
                    try save()
                    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        
        lastDetectedString = string
        
        DispatchQueue.main.async {
            self.detectedString = string
            self.isScanning = false
            self.isLoading = true
            //            self.isURL = false
        }
    }
    
    @MainActor func didDetectQRCode(url: URL) {
        guard url != lastDetectedURL else { return }
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        lastDetectedURL = url
        let sanitizedURL = url.absoluteString.removeTrackers()
        detectedURL = URL(string: sanitizedURL)
        
        var request = URLRequest(url: detectedURL!.prettify(), cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 15.0)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let finalURL = response?.url else { return } // don't use force-unwrap to prevent maliciously crafted qr codes
            
            DispatchQueue.main.async {
                self.generateQRCode(from: sanitizedURL)
                
                let qrCodeImage = self.qrCodeImage!
                let pngData = qrCodeImage.pngData()!
                var userLocation: [Double] = [] // re-write user's location in memory
                
                if let location = self.locationManager.location {
                    userLocation = [location.latitude, location.longitude]
                } else {
                    print("Could not get user location.")
                }
                
                let newCode = QRCode(text: finalURL.prettify().absoluteString, originalURL: url.absoluteString, qrCode: pngData, scanLocation: userLocation, wasScanned: true)
                
                self.qrCodeStore.history.append(newCode)
                
                Task {
                    do {
                        try self.save()
                        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                    } catch {
                        print("Failed to save: \(error.localizedDescription)")
                    }
                }
                
                userLocation = [] // re-write user's location in memory
                
                self.detectedURL = finalURL.prettify()
                self.unshortenedURL = finalURL.prettify()
                self.isScanning = false
                self.isLoading = true
            }
        }.resume()
    }
    
    func didFailToDetectQRCode() {
        DispatchQueue.main.async {
            self.isScanning = false
            self.cameraError = true
        }
    }
}
