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
    func didDetectQRCode(string: String)
    func didFailToDetectQRCode()
}

struct QRScanner: UIViewControllerRepresentable {
    @StateObject var viewModel = QRScannerViewModel(qrCodeStore: QRCodeStore())
    
    func makeUIViewController(context: Context) -> QRScannerController {
        return viewModel.scannerController
    }
    
    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {
    }
    
    var lastScannedURL: URL?
    var lastScannedString: String?
    
    mutating func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue,
           let url = URL(string: stringValue) {
            if stringValue.isValidURL() {
                guard url != lastScannedURL else { return }
                
                lastScannedURL = url
                
                viewModel.didDetectQRCode(url: url)
            } else {
                guard stringValue != lastScannedString else { return }
                
                lastScannedString = stringValue
                
                viewModel.didDetectQRCode(string: stringValue)
            }
        } else {
            viewModel.didFailToDetectQRCode()
        }
    }
}

struct Scanner: View {
    @StateObject var viewModel = QRScannerViewModel(qrCodeStore: QRCodeStore())
    private let monitor = NetworkMonitor()
    
    @State private var showingFullTextSheet = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if monitor.isActive {
                Label("Offline", systemImage: "network.slash")
                    .tint(.primary)
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let url = viewModel.unshortenedURL, url.host != viewModel.detectedURL?.host {
                    HStack {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            HStack {
                                if url.absoluteString.isValidURL() {
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
                                if let originalURL = viewModel.lastDetectedURL {
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
                        .padding(10)
                    }
                    .padding()
                    .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let originalURL = viewModel.detectedURL {
                    HStack {
                        Button {
                            UIApplication.shared.open(originalURL)
                        } label: {
                            HStack {
                                if originalURL.absoluteString.isValidURL() {
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let string = viewModel.detectedString {
                    Button {
                        showingFullTextSheet = true
                    } label: {
                        HStack {
                            Text(string)
                                .lineLimit(3)
                                .foregroundStyle(Color.accentColor)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                    .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .sheet(isPresented: $showingFullTextSheet) {
                        List {
                            Section {
                                Button {
                                    UIPasteboard.general.string = string
                                } label: {
                                    Label("Copy Text", systemImage: "doc.on.doc")
                                        .tint(Color.accentColor)
                                }
                                
                                Text(string)
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = string
                                        } label: {
                                            Label("Copy Text", systemImage: "doc.on.doc")
                                        }
                                    }
                            } footer: {
                                Text(string.count == 1 ? "1 character" : "\(string.count) characters")
                            }
                        }
                        .navigationTitle(string)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showingFullTextSheet = false
                                }
                            }
                        }
                    }
                } else if viewModel.cameraError {
                    Text("To scan QR codes, you need to enable camera permissions.")
                    
                    Button {} label: {
                        Text("Enable Camera Access")
                    }
                } else {
                    Text(viewModel.isScanning ? "Scanning..." : "No QR code detected")
                        .foregroundStyle(.white)
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.bottom)
        }
        .background(Color.black)
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        Scanner()
            .environmentObject(qrCodeStore)
    }
}
