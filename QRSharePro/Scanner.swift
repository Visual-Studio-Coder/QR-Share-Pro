import AVFoundation
import CameraPermission
import PermissionsKit
import SwiftUI
import UIKit
import PhotosUI

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    weak var delegate: QRScannerControllerDelegate?
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { accessGranted in
            guard accessGranted else { return }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        requestCameraPermission()
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
    
    func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue
        {
            delegate?.didDetectQRCode(string: stringValue)
        }
    }
}

protocol QRScannerControllerDelegate: AnyObject {
    func didDetectQRCode(string: String)
}

struct QRScanner: UIViewControllerRepresentable {
    @StateObject var viewModel = QRScannerViewModel(qrCodeStore: QRCodeStore())
    
    func makeUIViewController(context _: Context) -> QRScannerController {
        return viewModel.scannerController
    }
    
    func updateUIViewController(_: QRScannerController, context _: Context) {}
    
    var lastScannedURL: URL?
    var lastScannedString: String?
    
    mutating func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue
        {
            viewModel.didDetectQRCode(string: stringValue)
        }
    }
}

struct Scanner: View {
    @StateObject var viewModel = QRScannerViewModel(qrCodeStore: QRCodeStore())
    
    @AppStorage("showWebsiteFavicons") private var showWebsiteFavicons = AppSettings.showWebsiteFavicons
    
    private let monitor = NetworkMonitor()
    
    @State private var showingFullTextSheet = false
    @State private var isFlashlightOn = false
    @State private var showingCameraError = !Permission.camera.authorized
    @State private var isImagePickerPresented = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoData: Data?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let image = selectedImage  {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        Button {
                            selectedImage = nil
                            viewModel.clear()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.blue)
                        }
                            .frame(width: 60, height: 60)
                            .background(VisualEffectView(effect: UIBlurEffect(style: .prominent)).overlay(Color.accentColor.opacity(0.1)))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .padding(), alignment: .topTrailing
                    )
                    .onAppear {
                        viewModel.scanImage(image)
                    }
                VStack {
                    if let string = viewModel.detectedString {
                        if string.isValidURL(), let url = URL(string: string) {
                            HStack {
                                Button {
                                    UIApplication.shared.open(url)
                                } label: {
                                    HStack {
                                        if viewModel.isLoading {
                                            if #available(iOS 17.0, *) {
                                                Image(systemName: "link.badge.plus")
                                                    .symbolEffect(.pulse.wholeSymbol)
                                                    .frame(width: 16, height: 16)
                                            } else {
                                                Image(systemName: "link.badge.plus")
                                                //.symbolEffect(.pulse)
                                                    .frame(width: 16, height: 16)
                                            }
                                        } else {
                                            if let host = url.host {
                                                if showWebsiteFavicons {
                                                    AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")) { image in
                                                        image
                                                            .interpolation(.none)
                                                            .resizable()
                                                    } placeholder: {
                                                        ProgressView()
                                                    }
                                                    .frame(width: 16, height: 16)
                                                }
                                            }
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
                                        Image(systemName: "checkmark.shield.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .padding()
                            .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)).overlay(Color.accentColor.opacity(0.1)))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else if let url = URL(string: string), UIApplication.shared.canOpenURL(url) {
                            Button {
                                UIApplication.shared.open(URL(string: string)! as URL)
                            } label: {
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                    Text(string)
                                        .lineLimit(3)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding()
                            .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)).overlay(Color.accentColor.opacity(0.1)))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
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
                            .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)).overlay(Color.accentColor.opacity(0.1)))
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
                    } else {
                        Button {
                            // do nothing ig
                        } label: {
                            HStack {
                                Text("**No QR Code Detected**\nPlease upload a different image.")
                                Image(systemName: "rectangle.portrait.on.rectangle.portrait.slash")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)).overlay(Color.accentColor.opacity(0.1)))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding()
            } else {
                if !monitor.isActive {
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
                        
                        Text("You'll be able to see where you scanned QR codes. Apple Maps displays the saved coordinates onto a map.")
                            .padding(.horizontal, 50)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 50)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                        } label: {
                            Text("Open Settings")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .bold()
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                } else {
                    QRScanner(viewModel: viewModel)
                        .onAppear {
                            viewModel.startScanning()
                        }
                        .onDisappear {
                            viewModel.stopScanning()
                        }
                    
                    VStack {
                        if let string = viewModel.detectedString {
                            if string.isValidURL(), let url = URL(string: string) {
                                HStack {
                                    Button {
                                        UIApplication.shared.open(url)
                                    } label: {
                                        HStack {
                                            if viewModel.isLoading {
                                                if #available(iOS 17.0, *) {
                                                    Image(systemName: "link.badge.plus")
                                                        .symbolEffect(.pulse.wholeSymbol)
                                                        .frame(width: 16, height: 16)
                                                } else {
                                                    Image(systemName: "link.badge.plus")
                                                    //.symbolEffect(.pulse)
                                                        .frame(width: 16, height: 16)
                                                }
                                            } else {
                                                if let host = url.host {
                                                    if showWebsiteFavicons {
                                                        AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")) { image in
                                                            image
                                                                .interpolation(.none)
                                                                .resizable()
                                                        } placeholder: {
                                                            ProgressView()
                                                        }
                                                        .frame(width: 16, height: 16)
                                                    }
                                                }
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
                                            Image(systemName: "checkmark.shield.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                                .padding()
                                .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)).overlay(Color.accentColor.opacity(0.1)))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else if let url = URL(string: string), UIApplication.shared.canOpenURL(url) {
                                Button {
                                    UIApplication.shared.open(URL(string: string)! as URL)
                                } label: {
                                    HStack {
                                        Image(systemName: "link.circle.fill")
                                        Text(string)
                                            .lineLimit(3)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding()
                                .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)).overlay(Color.accentColor.opacity(0.1)))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
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
                                .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)).overlay(Color.accentColor.opacity(0.1)))
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
                    }
                    .padding()
                }
            }
        }
        .onChange(of: selectedImage) { newImage in
            if let newImage = newImage {
                viewModel.clear()
                viewModel.scanImage(newImage)
            }
        }
        .toolbar {
            if !showingCameraError {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        if selectedImage == nil {
                            toggleFlashlight()
                        }
                    }) {
                        Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.slash")
                    }
                    .disabled(selectedImage != nil)
                    .foregroundStyle(isFlashlightOn ? Color.accentColor : Color.secondary)
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Select a photo", systemImage: "photo.on.rectangle.angled")
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedPhotoData = data
                            selectedImage = UIImage(data: data)
                        }
                    }
                }
                
            }
        }
        .navigationTitle(Text("Scan QR Code"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                if isFlashlightOn {
                    device.torchMode = .off
                } else {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                }
                device.unlockForConfiguration()
                isFlashlightOn.toggle()
            } catch {
                print("Flashlight could not be used")
            }
        } else {
            print("Flashlight unavailable")
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
