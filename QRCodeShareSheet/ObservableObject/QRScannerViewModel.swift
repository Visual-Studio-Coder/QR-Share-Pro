//
//  QRScannerViewModel.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 4/3/24.
//

import SwiftUI
import AVFoundation

class QRScannerViewModel: ObservableObject, QRScannerControllerDelegate {
    @ObservedObject var locationManager = LocationManager()
    
    @Published var isURL: Bool = true
    @Published var detectedURL: URL?
    @Published var unshortenedURL: URL?
    @Published var detectedString: String?
    
    @Published var isScanning = false
    @Published var isLoading = false
    @Published var cameraError = false
    
    @Published var qrCodeImage: UIImage?
    @Published var qrCode: QRCode
    
    var qrCodeStore: QRCodeStore
    
    func save() throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }
    
    let scannerController = QRScannerController()
    
    init(qrCodeStore: QRCodeStore) {
        self.qrCodeStore = qrCodeStore
        self.qrCode = QRCode(text: "")
        scannerController.delegate = self
    }
    
    func startScanning() {
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.scannerController.startScanning()
        }
    }
    
    func stopScanning() {
        isScanning = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.scannerController.stopScanning()
        }
    }
    
    var lastDetectedURL: URL?
    var lastDetectedString: String?
    
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
            
            let newCode = QRCode(text: string, qrCode: pngData, scanLocation: userLocation, wasScanned: true)
            
            qrCodeStore.history.append(newCode)
            
            Task {
                do {
                    try save()
                    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRSharePro.dataChanged" as CFString), nil, nil, true)
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
            self.isURL = false
        }
    }
    
    @MainActor func didDetectQRCode(url: URL) {
        guard url != lastDetectedURL else { return }
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        generateQRCode(from: url.absoluteString)
        
        if let qrCodeImage = self.qrCodeImage, let pngData = qrCodeImage.pngData() {
            var userLocation: [Double] = [] // re-write user's location in memory
            
            if let location = locationManager.location {
                userLocation = [location.latitude, location.longitude]
            } else {
                print("Could not get user location.")
            }
            
            let newCode = QRCode(text: url.absoluteString, qrCode: pngData, scanLocation: userLocation, wasScanned: true)
            
            qrCodeStore.history.append(newCode)
            
            Task {
                do {
                    try save()
                    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRSharePro.dataChanged" as CFString), nil, nil, true)
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        
        lastDetectedURL = url
        
        DispatchQueue.main.async {
            self.detectedURL = url
            self.isScanning = false
            self.isLoading = true
            self.isURL = true
        }
        
        // Unshorten the URL
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let urlResponse = response, let finalURL = urlResponse.url {
                DispatchQueue.main.async {
                    self.unshortenedURL = finalURL
                    self.isLoading = false
                    
                    // Delete cookies
                    let cookieJar = HTTPCookieStorage.shared
                    for cookie in cookieJar.cookies ?? [] {
                        cookieJar.deleteCookie(cookie)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
        
        task.resume()
    }
    
    func didFailToDetectQRCode() {
        DispatchQueue.main.async {
            self.isScanning = false
            self.cameraError = true
        }
    }
}
