import SwiftUI
import AVFoundation

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
            print(error)
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
    @Published var detectedURL: URL?
    @Published var unshortenedURL: URL?
    @Published var isScanning = false
    @Published var isLoading = false
    @Published var cameraError = false
    
    @Published var qrCodeImage: UIImage?
    @State var qrCode: QRCode
    var qrCodeStore: QRCodeStore
    
    func save() async throws {
        await qrCodeStore.save(history: qrCodeStore.history)
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
        
        //        Play system haptic
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // Generate QR Code image from the URL
        generateQRCode(from: url.absoluteString)
        
        // Check if qrCodeImage is not nil
        if let qrCodeImage = self.qrCodeImage, let pngData = qrCodeImage.pngData() {
            // Create a new QR Code object
            let newCode = QRCode(text: url.absoluteString, qrCode: pngData)
            qrCodeStore.history.append(newCode)
            Task {
                do {
                    try await save()
                    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                } catch {
                    fatalError(error.localizedDescription)
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
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
                                if let host = url.host {
                                    AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")) { image in
                                        image.resizable()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 16, height: 16)
                                }
                                Text(url.absoluteString)
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
                                if let host = originalURL.host {
                                    AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")) { image in
                                        image.resizable()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 16, height: 16)
                                }
                                Text(originalURL.absoluteString)
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
                    .background(.indigo)
                    .foregroundStyle(.white)
                } else {
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
