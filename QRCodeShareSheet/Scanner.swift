//
//  Scanner.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/10/24.
//

import SwiftUI
import AVFoundation

class QRScannerController: UIViewController {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    var delegate: AVCaptureMetadataOutputObjectsDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // use back camera
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
        
        captureMetadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [ .qr ]
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
}

struct QRScanner: UIViewControllerRepresentable {
    @Binding var result: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator($result)
    }
    
    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.delegate = context.coordinator
        
        return controller
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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            QRScanner(result: $scanResult)
            
            Text(scanResult)
                .padding()
                .background(.black)
                .foregroundColor(.white)
                .padding(.bottom)
        }
    }
}

#Preview {
    Scanner()
}
