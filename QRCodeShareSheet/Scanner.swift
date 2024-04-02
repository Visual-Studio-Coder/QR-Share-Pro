import SwiftUI
import AVFoundation
import CoreLocation
import WebKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()

    @Published var location: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get the user's location: \(error.localizedDescription)")
    }
}

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    weak var delegate: QRScannerControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Don't run this on the simulator - run it on your iPhone.")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            print(error.localizedDescription)
            return
        }
        
        captureSession.addInput(videoInput)
        
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)
        
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [.qr]
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.addSublayer(videoPreviewLayer!)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = view.layer.bounds.inset(by: view.safeAreaInsets)
    }
    
    func startScanning() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue,
           let url = URL(string: stringValue) {
            delegate?.didDetectQRCode(url: url)
        } else {
            delegate?.didFailToDetectQRCode()
        }
    }
}

protocol QRScannerControllerDelegate: AnyObject {
    func didDetectQRCode(url: URL)
    func didFailToDetectQRCode()
}

class QRScannerViewModel: ObservableObject, QRScannerControllerDelegate {
    @ObservedObject var locationManager = LocationManager()
    
    @Published var detectedURL: URL?
    @Published var unshortenedURL: URL?
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
        self.qrCode = QRCode(text: "") // Initialize qrCode here
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
    
    let filter = CIFilter.qrCodeGenerator()
    let context = CIContext()
    
    func sampleData() {
        qrCodeStore.history.append(QRCode(text: "https://duckduckgo.com/", scanLocation: [51.507222, -0.1275], wasScanned: true))
        
        do {
            try save()
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
        } catch {
            print(error.localizedDescription)
        }
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
    
    @MainActor func didDetectQRCode(url: URL) {
        // Check if the newly detected URL is the same as the last one detected
        if url == lastDetectedURL {
            // If it is, simply return without doing anything
            return
        }
        
        // Play system haptic
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // Generate QR Code image from the URL
        generateQRCode(from: url.absoluteString)
        
        // Check if qrCodeImage is not nil
        if let qrCodeImage = self.qrCodeImage, let pngData = qrCodeImage.pngData() {
            locationManager.requestLocation()
            
            var userLocation: [Double] = [] // rewrite user's location in memory
            
            if let location = locationManager.location {
                print("user location:", location)
                userLocation = [location.latitude, location.longitude]
            } else {
                print("Could not get user location.")
            }
            
            let newCode = QRCode(text: url.absoluteString, qrCode: pngData, scanLocation: userLocation, wasScanned: true)
            
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
        
        // Update the last detected URL
        lastDetectedURL = url
        
        DispatchQueue.main.async {
            self.detectedURL = url
            self.isScanning = false
            self.isLoading = true
        }
        
        // Unshorten the URL
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let urlResponse = response, let finalURL = urlResponse.url {
                DispatchQueue.main.async {
                    self.unshortenedURL = finalURL
                    self.isLoading = false
                    
                    // Disable JavaScript
                    let preferences = WKWebpagePreferences()
                    preferences.allowsContentJavaScript = false
                    
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

struct QRScanner: UIViewControllerRepresentable {
    @StateObject var viewModel = QRScannerViewModel(qrCodeStore: QRCodeStore())
    
    func makeUIViewController(context: Context) -> QRScannerController {
        return viewModel.scannerController
    }
    
    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {
    }
    
    var lastScannedURL: URL?
    
    mutating func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue,
           let url = URL(string: stringValue) {
            // Check if the newly scanned URL is the same as the last one scanned.
            if url == lastScannedURL {
                // If it is, simply return without doing anything
                return
            }
            
            // Update the last scanned URL
            lastScannedURL = url
            
            viewModel.didDetectQRCode(url: url)
        } else {
            viewModel.didFailToDetectQRCode()
        }
    }
}

struct Scanner: View {
    @StateObject var viewModel = QRScannerViewModel(qrCodeStore: QRCodeStore())
    private let monitor = NetworkMonitor()
    
    private func isValidURL(_ string: String) -> Bool {
        if let url = URLComponents(string: string) {
            return url.scheme != nil && !url.scheme!.isEmpty
        } else {
            return false
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if monitor.isActive {
                HStack {
                    Label("You're offline.", systemImage: "network.slash")
                        .tint(.primary)
                    Spacer()
                    Image(systemName: "multiply.circle.fill")
                        .foregroundStyle(Color.gray)
                }
            }
            
            Spacer()
            
            QRScanner(viewModel: viewModel)
                .onAppear {
                    viewModel.startScanning()
                }
                .onDisappear {
                    viewModel.stopScanning()
                }
            
            VStack {
                if viewModel.isLoading {
                    HStack {
                        if let originalURL = viewModel.detectedURL {
                            Button {
                                UIApplication.shared.open(originalURL)
                            } label: {
                                HStack {
                                    if let host = originalURL.host {
                                        AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")) { image in
                                            image.resizable()
                                        } placeholder: {
                                            ProgressView()
                                        }
                                        .frame(width: 16, height: 16)
                                    }
                                    
                                    Text(originalURL.absoluteString)
                                        .lineLimit(2)
                                }
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding()
                    .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                    .cornerRadius(10)
                } else if let url = viewModel.unshortenedURL, url.host != viewModel.detectedURL?.host {
                    HStack {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            HStack {
                                if isValidURL(url.absoluteString) {
                                    if let host = url.host {
                                        AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")) { image in
                                            image.resizable()
                                        } placeholder: {
                                            ProgressView()
                                        }
                                        .frame(width: 16, height: 16)
                                    }
                                }
                                
                                Text(url.absoluteString)
                                    .lineLimit(2)
                            }
                        }
                        .foregroundStyle(Color.accentColor)
                        
                        Menu {
                            Section {
                                if let originalURL = viewModel.detectedURL {
                                    Button {
                                        UIApplication.shared.open(originalURL)
                                    } label: {
                                        Text("\(originalURL.absoluteString)")
                                            .foregroundStyle(.blue)
                                            .lineLimit(5)
                                    }
                                }
                            } header: {
                                Text("Original URL")
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                    .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                    .cornerRadius(10)
                } else if let originalURL = viewModel.detectedURL {
                    HStack {
                        Button {
                            UIApplication.shared.open(originalURL)
                        } label: {
                            HStack {
                                if isValidURL(originalURL.absoluteString) {
                                    if let host = originalURL.host {
                                        AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")) { image in
                                            image.resizable()
                                        } placeholder: {
                                            ProgressView()
                                        }
                                        .frame(width: 16, height: 16)
                                    }
                                }
                                
                                Text(originalURL.absoluteString)
                                    .lineLimit(2)
                            }
                        }
                        .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                    .cornerRadius(10)
                } else if viewModel.cameraError {
                    Text("To scan QR codes, you need to enable camera permissions.")
                    
                    Button {} label: {
                        Text("Enable Camera Access")
                    }
                } else {
                    Button("Use Sample Data") {
                        viewModel.sampleData()
//                        viewModel.generateQRCode(from: "https://duckduckgo.com")
//                        viewModel.didDetectQRCode(url: URL(string: "https://duckduckgo.com")!)
                    }
                    
                    Text(viewModel.isScanning ? "Scanning..." : "No QR code detected")
                        .foregroundStyle(.white)
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                        .cornerRadius(10)
                }
            }
            .padding(.bottom)
        }
        .background(Color.black)
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        return UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        Scanner()
            .environmentObject(qrCodeStore)
    }
}
