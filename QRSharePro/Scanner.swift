import SwiftUI
import AVFoundation
import PermissionsKit
import CameraPermission

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
           let stringValue = readableObject.stringValue {
            delegate?.didDetectQRCode(string: stringValue)
        }
    }
}

protocol QRScannerControllerDelegate: AnyObject {
    func didDetectQRCode(string: String)
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
           let stringValue = readableObject.stringValue {
            viewModel.didDetectQRCode(string: stringValue)
            
        }
    }
}

struct Scanner: View {
    @StateObject var viewModel = QRScannerViewModel(qrCodeStore: QRCodeStore())
    private let monitor = NetworkMonitor()
    let authorized = Permission.camera.authorized
    @State private var showingFullTextSheet = false
    @State private var showingError = true
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if monitor.isActive {
                Label("Offline", systemImage: "network.slash")
                    .tint(.primary)
                    .padding(.bottom, 25)
            }
            
            QRScanner(viewModel: viewModel)
                .onAppear {
                    viewModel.startScanning()
                }
                .onDisappear {
                    viewModel.stopScanning()
                }
            
            VStack {
                if !authorized {
                    VStack {
                        Text("To scan QR codes, you need to enable camera permissions.")
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString),
                               UIApplication.shared.canOpenURL(settingsURL) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                    }
                } else if let string = viewModel.detectedString {
                    if string.isValidURL(), let url = URL(string: string) {
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
                                        .lineLimit(2)
                                }
                            }
                            .padding(.bottom)
                            .foregroundStyle(.blue)
                            
                            if viewModel.lastDetectedString != url.absoluteString {
                                Menu {
                                    Section {
                                        if let originalURL = viewModel.lastDetectedString {
                                            Button {
                                                UIApplication.shared.open(URL(string: originalURL)!)
                                            } label: {
                                                Text("\(originalURL)")
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
                        }
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Button {
                            showingFullTextSheet = true
                        } label: {
                            HStack {
                                Text(string)
                                    .lineLimit(3)
                                    .foregroundStyle(Color.accentColor)
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
                    }
                }
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        Scanner()
            .environmentObject(qrCodeStore)
    }
}
