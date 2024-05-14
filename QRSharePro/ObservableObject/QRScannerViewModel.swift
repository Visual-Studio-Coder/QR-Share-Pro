import SwiftUI
import AVFoundation

class QRScannerViewModel: ObservableObject, QRScannerControllerDelegate {
    @ObservedObject var locationManager = LocationManager()
    
    @AppStorage("playHaptics") private var playHaptics = AppSettings.playHaptics
    
    @Published var unshortenedURL: URL?
    @Published var detectedString: String?
    
    @Published var qrCodeImage: UIImage?
    
    @Published var qrCode: QRCode
    
    @Published var isLoading = false
    
    var qrCodeStore: QRCodeStore
    
    func save() throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }
    
    @MainActor func clear() {
        detectedString = nil
    }
    
    let scannerController = QRScannerController()
    
    init(qrCodeStore: QRCodeStore) {
        self.qrCodeStore = qrCodeStore
        self.qrCode = QRCode(text: "", originalURL: "")
        scannerController.delegate = self
        scannerController.requestCameraPermission()
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.scannerController.startScanning()
        }
    }
    
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.scannerController.stopScanning()
        }
    }
    
    @MainActor func scanImage(_ image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        
        let context = CIContext()
        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: options)
        
        if let features = qrDetector?.features(in: ciImage) as? [CIQRCodeFeature] {
            for feature in features {
                if let decodedString = feature.messageString {
                    didDetectQRCode(string: decodedString)
                }
            }
        }
    }
    
    @Published var lastDetectedURL: URL?
    @Published var lastDetectedString: String? = ""
    
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
        isLoading = true
        if string.extractFirstURL().isValidURL(), let url = URL(string: string.extractFirstURL()), UIApplication.shared.canOpenURL(url) {
            guard url != URL(string: lastDetectedString!) else { 
                return 
            }
            lastDetectedString = string
            self.detectedString = string
            
            if playHaptics {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
            
            let sanitizedURL = url.absoluteString.removeTrackers()
            
            let configuration = URLSessionConfiguration.ephemeral
            let delegateQueue = OperationQueue()
            let delegate = CustomURLSessionDelegate()
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
            
            self.generateQRCode(from: sanitizedURL)
            let qrCodeImage = self.qrCodeImage!
            let pngData = qrCodeImage.pngData()!
            
            var userLocation: [Double] = []
            
            DispatchQueue.main.async {
                if let location = self.locationManager.location {
                    userLocation = [location.latitude, location.longitude]
                } else {
                    print("Could not get user location.")
                }
            }
            
            let newCode = QRCode(text: sanitizedURL, originalURL: string, qrCode: pngData, scanLocation: userLocation, wasScanned: true)
            
            self.qrCodeStore.history.append(newCode)
            
            Task {
                do {
                    try self.save()
                    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                } catch {
                    print("Failed to save: \(error.localizedDescription)")
                }
            }
            
            var urlComponents = URLComponents(string: sanitizedURL)
            urlComponents?.scheme = "https"
            
            if let httpsURL = urlComponents?.url, UIApplication.shared.canOpenURL(httpsURL) {
                session.dataTask(with: httpsURL) { (data, response, error) in
                    guard error == nil else { 
                        return 
                    }
                    guard let response = response else { 
                        return 
                    }
                    guard let finalURL = response.url else { 
                        return 
                    }
                    
                    DispatchQueue.main.async {
                        let newCode = QRCode(text: finalURL.absoluteString.removeTrackers(), originalURL: string, qrCode: pngData, scanLocation: userLocation, wasScanned: true)
                        
                        self.qrCodeStore.history.removeLast()
                        self.qrCodeStore.history.append(newCode)
                        
                        self.detectedString = finalURL.absoluteString.removeTrackers()
                        
                        Task {
                            do {
                                try self.save()
                                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                            } catch {
                                print("Failed to save: \(error.localizedDescription)")
                            }
                        }
                        
                        self.unshortenedURL = finalURL
                        self.isLoading = false
                    }
                }.resume()
            }
            
            userLocation = []
        }
    }
}
class CustomURLSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        var newRequest = newRequest
        if let url = newRequest.url {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https" // Enforce HTTPS
            if let urlString = components?.url?.absoluteString.removeTrackers(), // Remove trackers
               let newUrl = URL(string: urlString) {
                newRequest.url = newUrl
            }
        }
        completionHandler(newRequest)
    }
}
