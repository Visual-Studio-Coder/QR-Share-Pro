//struct Scanner: View {
//    @State var scanResult = "No QR code detected"
//    @State private var x: CGFloat = 1
//    @StateObject var viewModel = QRScannerViewModel()
//
//    var body: some View {
//        ZStack(alignment: .bottom) {
//            QRScanner(result: $scanResult, viewModel: viewModel)
//                .onAppear {
//                    viewModel.startScanning()
//                }
//                .onDisappear {
//                    viewModel.stopScanning()
//                }
//                .scaleEffect(x)
//
//            HStack {
//                Button {
//                    x -= 0.5
//                } label: {
//                    Image(systemName: "plus")
//                        .padding()
//                        .font(.largeTitle)
//                        .foregroundStyle(.white)
//                        .background(.blue)
//                        .clipShape(Circle())
//                }
//
//                if let url = URL(string: viewModel.detectedQRCode ?? ""), UIApplication.shared.canOpenURL(url) {
//                    Button(action: {
//                        UIApplication.shared.open(url)
//                    }) {
//                        HStack {
//                            AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(url.host!).ico")) { i in
//                                i
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fit)
//                                    .frame(width: 20, height: 20)
//                            } placeholder: {
//                                ProgressView()
//                            }
//                            Text(url.absoluteString)
//                                .foregroundColor(.blue)
//                                .underline()
//                        }
//                        .padding()
//                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
//                        .foregroundColor(Color.white)
//                        .cornerRadius(10)
//                    }
//                } else {
//                    Text(viewModel.detectedQRCode ?? "No QR code detected")
//                        .padding()
//                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
//                        .foregroundColor(Color.white)
//                        .cornerRadius(10)
//                }
//
//                Button {
//                    x += 0.5
//                } label: {
//                    Image(systemName: "plus")
//                        .font(.largeTitle)
//                        .foregroundStyle(.white)
//                        .background(.blue)
//                        .clipShape(Circle())
//                }
//            }
//            .padding(.bottom)
//        }
//        .background(Color.black)
//    }
//}

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
        captureMetadataOutput.metadataObjectTypes = [ .qr ]
        
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
    let scannerController = QRScannerController()
    
    init() {
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
    
    func didDetectQRCode(url: URL) {
        // Check if the newly detected URL is the same as the last one detected
        if url == lastDetectedURL {
            // If it is, simply return without doing anything
            return
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
        }
    }
}

struct QRScanner: UIViewControllerRepresentable {
    @ObservedObject var viewModel: QRScannerViewModel
    
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
                // If it is, simply return without doing anythinga
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
    @StateObject var viewModel = QRScannerViewModel()
    
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
                    VisualEffectView(effect: UIBlurEffect(style: .dark))
                        .frame(width: 50, height: 50)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        )
                        .cornerRadius(10)
                } else if let url = viewModel.unshortenedURL {
                    Menu {
                        Section(header: Text("Open Original URL:")) {
                            if let originalURL = viewModel.detectedURL {
                                Button(action: {
                                    UIApplication.shared.open(originalURL)
                                }) {
                                    Text("\(originalURL.absoluteString)")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Button(action: {
                                UIApplication.shared.open(url)
                            }) {
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
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                    .cornerRadius(10)
                } else {
                    Text(viewModel.isScanning ? "Scanning..." : "No QR code detected")
                        .foregroundColor(.white)
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
    Scanner()
}
