import SwiftUI
import AVFoundation

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    weak var delegate: QRScannerControllerDelegate?
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: {accessGranted in
            guard accessGranted == true else { return }
            //            self.presentCamera()
        })
    }
    
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
    @State private var showingFullTextSheet = false
    @State private var showingCameraError = true
    @State private var showingCameraErrorSheet = true
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if monitor.isActive {
                Label("Offline", systemImage: "network.slash")
                    .tint(.primary)
                    .padding(.bottom, 25)
            }
            
            if showingCameraError {
                VStack {
                    Spacer()
                    
                    Image(uiImage: #imageLiteral(resourceName: UserDefaults.standard.string(forKey: "appIcon") ?? "AppIcon"))
                        .resizable()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .accessibilityHidden(true)
                        .shadow(color: .accentColor, radius: 15)
                        .padding(.top, 20)
                    
                    Text("QR Share Pro")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                        .bold()
                    
                    Text("is requesting:")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.bottom, 20)
                    
                    Label("Camera", systemImage: "camera")
                        .bold()
                    
                    Text("Your camera is used to scan QR codes. This is done 100% offline.")
                        .padding(.horizontal, 50)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 50)
                        .foregroundStyle(.secondary)
                    
                    Label("Location", systemImage: "location")
                        .bold()
                    
                    Text("You'll be able to see where you scanned QR codes. This is done 100% offline, with Apple Maps used to show your location on a map.")
                        .padding(.horizontal, 50)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 50)
                        .foregroundStyle(.secondary)
                    
                    Label("We don't track you.", systemImage: "checkmark.shield")
                    
                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    } label: {
                        Text("Open Settings")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .bold()
                    .padding(.horizontal)
                    
                    Spacer()
                }
            } else {
                QRScanner(viewModel: viewModel)
            }
            
            VStack {
                if let string = viewModel.detectedString {
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
                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)).overlay(Color.accentColor.opacity(0.1)))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else if UIApplication.shared.canOpenURL(URL(string: string)!) {
                        Button {
                            UIApplication.shared.open(URL(string: string)! as URL)
                        } label: {
                            HStack {
                                Text(string)
                                    .lineLimit(3)
                                    .foregroundStyle(.blue)
                                Image(systemName: "link.circle.fill")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)).overlay(Color.accentColor.opacity(0.1)))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    } 
                    else {
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
                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)).overlay(Color.accentColor.opacity(0.1)))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
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
                    .padding(.bottom)
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
