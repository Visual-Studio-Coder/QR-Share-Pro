import SwiftUI
import AVFoundation

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
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
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
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
            delegate?.didDetectQRCode(code: stringValue)
        }
    }
}

protocol QRScannerControllerDelegate: AnyObject {
    func didDetectQRCode(code: String)
}

class QRScannerViewModel: ObservableObject, QRScannerControllerDelegate {
    @Published var detectedQRCode: String?
    let scannerController = QRScannerController()

    init() {
        scannerController.delegate = self
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

    func didDetectQRCode(code: String) {
        DispatchQueue.main.async {
            self.detectedQRCode = code
        }
    }
}

class FaviconLoader: ObservableObject {
    @Published var image: UIImage?

    func load(from url: URL) {
        let faviconURL = url.appendingPathComponent("favicon.ico")
        let task = URLSession.shared.dataTask(with: faviconURL) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
        task.resume()
    }
}

struct QRScanner: UIViewControllerRepresentable {
    @Binding var result: String
    @ObservedObject var viewModel: QRScannerViewModel

    func makeUIViewController(context: Context) -> QRScannerController {
        return viewModel.scannerController
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {
    }
}

class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    @Binding var scanResult: String
    
    init(_ scanResult: Binding<String>) {
        self._scanResult = scanResult
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            scanResult = "No QR code detected"
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObject.ObjectType.qr, let result = metadataObj.stringValue {
            scanResult = result
        }
    }
}

struct Scanner: View {
    @State var scanResult = "No QR code detected"
    @StateObject var viewModel = QRScannerViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            QRScanner(result: $scanResult, viewModel: viewModel)
                .onAppear {
                    viewModel.startScanning()
                }
                .onDisappear {
                    viewModel.stopScanning()
                }
            HStack {
                if let url = URL(string: viewModel.detectedQRCode ?? ""), UIApplication.shared.canOpenURL(url) {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        HStack {
                            AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(url.host!).ico")) { i in
                                i
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                            } placeholder: {
                                ProgressView()
                            }
                            Text(url.absoluteString)
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                        .foregroundColor(Color.white)
                        .cornerRadius(10)
                    }
                } else {
                    Text(viewModel.detectedQRCode ?? "No QR code detected")
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                        .foregroundColor(Color.white)
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
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}
