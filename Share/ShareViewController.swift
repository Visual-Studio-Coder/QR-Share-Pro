import UIKit
import Social
import SwiftUI
import CoreImage.CIFilterBuiltins
import MobileCoreServices
import UniformTypeIdentifiers
import ColorfulX
import Photos

class ShareViewController: UIViewController {
    var hostingView: UIHostingController<ShareView>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hostingView = UIHostingController(rootView: ShareView(extensionContext: extensionContext))
        hostingView.modalPresentationStyle = .pageSheet
        hostingView.view.frame = view.frame
        view.addSubview(hostingView.view)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
            self.hostingView.view.frame = CGRect(origin: .zero, size: size)
        })
    }
}

@MainActor
struct ShareView: View {
    var qrCodeStore = QRCodeStore()
    var extensionContext: NSExtensionContext?
    
    @State private var qrCodeImage: UIImage?
    @State private var isBackgroundVisible = false
    @State private var receivedText: String = ""
    @State private var showAlert = false
    @State private var showPermissionsError = false
    @State private var colors: [Color] = [.gray, .orange, .yellow, .green, .blue, .white, .purple, .pink, .gray, .white]
    
    var body: some View {
        ZStack {
            ColorfulView(color: $colors)
                .ignoresSafeArea()
            
            if let qrCodeImage = qrCodeImage {
                VStack {
                    Image(uiImage: qrCodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(16)
                    
                    Button(action: {
                        dismiss()
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }, label: {
                        HStack {
                            Spacer()
                            Text("Dismiss")
                                .font(.title)
                                .padding(.vertical, 16)
                                .bold()
                            Spacer()
                        }
                    })
                    .onLongPressGesture(minimumDuration: 0, pressing: { inProgress in
                        if inProgress {
                            let generator = UIImpactFeedbackGenerator(style: .soft)
                            generator.impactOccurred()
                        }
                    }, perform: {})
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 16)
                    .tint(Color(UIColor(red: 0.11, green: 0.14, blue: 0.79, alpha: 1.0)))
                    
                    HStack {
                        Button(action: {
                            let ciImage = CIImage(cgImage: qrCodeImage.cgImage!)
                            let context = CIContext()
                            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                    if status == .denied {
                                        showPermissionsError = true
                                    } else {
                                        let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
                                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                                        showAlert = true
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20))
                                Text("Save")
                                Spacer()
                            }
                            .frame(height: 60)
                            .padding(.horizontal)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .alert(isPresented: $showAlert) {
                            Alert(title: Text("Saved!"), message: Text("The QR code has been saved to your photos."), dismissButton: .default(Text("OK")))
                        }
                        .alert("We need permission to save this QR code to your photo library. Open Settings > QR Share, then enable \"Add Photos Only\".", isPresented: $showPermissionsError) {
                        }
                        Button(action: {
                            let ciImage = CIImage(cgImage: qrCodeImage.cgImage!)
                            let context = CIContext()
                            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                                let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
                                let printController = UIPrintInteractionController.shared
                                let printInfo = UIPrintInfo(dictionary:nil)
                                printInfo.outputType = .general
                                printInfo.jobName = "Print QR Code"
                                printController.printInfo = printInfo
                                let myRenderer = MyPrintPageRenderer(text: receivedText, image: image)
                                printController.printPageRenderer = myRenderer
                                printController.present(animated: true, completionHandler: nil)
                            }
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "printer")
                                    .font(.system(size: 20))
                                Text("Print")
                                Spacer()
                            }
                            .frame(height: 60)
                            .padding(.horizontal)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 16)
                    .onLongPressGesture(minimumDuration: 0, pressing: { inProgress in
                        if inProgress {
                            let generator = UIImpactFeedbackGenerator(style: .soft)
                            generator.impactOccurred()
                        }
                    }, perform: {})
                }
            } else {
                Button(action: {
                    dismiss()
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }, label: {
                    HStack {
                        Spacer()
                        Text("Dismiss")
                            .font(.title)
                            .padding(.vertical, 16)
                            .bold()
                        Spacer()
                    }
                })
                .onLongPressGesture(minimumDuration: 0, pressing: { inProgress in
                    if inProgress {
                        let generator = UIImpactFeedbackGenerator(style: .soft)
                        generator.impactOccurred()
                    }
                }, perform: {})
                .buttonStyle(.borderedProminent)
                .padding(16)
                .tint(Color(UIColor(red: 0.11, green: 0.14, blue: 0.79, alpha: 1.0)))
            }
        }
        .background(Color.clear)
        .onAppear {
            withAnimation(.easeIn(duration: 2.0)) {
                isBackgroundVisible = true
            }
            
            loadSharedText { sharedText in
                let originalURL = sharedText
                receivedText = sharedText
                
                if let qrImage = generateQRCode(from: receivedText) {
                    qrCodeImage = qrImage
                    let newCode = QRCode(text: receivedText, originalURL: originalURL, qrCode: qrCodeImage?.pngData())
                    
                    if let userDefaults = UserDefaults(suiteName: "group.com.click.QRShare") {
                        let decoder = JSONDecoder()
                        var history = userDefaults.data(forKey: "history").flatMap { try? decoder.decode([QRCode].self, from: $0) } ?? []
                        history.append(newCode)
                        
                        let encoder = JSONEncoder()
                        if let encodedHistory = try? encoder.encode(history) {
                            userDefaults.set(encodedHistory, forKey: "history")
                            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                        }
                    }
                } else {
                    print("Failed to generate QR code")
                }
            }
        }
        
    }
    
    func save() async throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }
    
    func dismiss() {
        extensionContext?.completeRequest(returningItems: [])
    }
    
    func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        if let qrCode = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledQrCode = qrCode.transformed(by: transform)
            
            let context = CIContext()
            if let cgImage = context.createCGImage(scaledQrCode, from: scaledQrCode.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    func loadSharedText(completion: @escaping (String) -> Void) {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            print("Failed to load shared item")
            return
        }
        
        for itemProvider in extensionItem.attachments ?? [] {
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (item, error) in
                    if let sharedURL = item as? URL {
                        DispatchQueue.main.async {
                            print("Shared URL: \(sharedURL.absoluteString)")
                            completion(sharedURL.absoluteString)
                        }
                    } else if let error = error {
                        print("Failed to load item: \(error)")
                    } else {
                        print("Item is not a URL")
                    }
                }
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                    if let sharedText = item as? String {
                        DispatchQueue.main.async {
                            print("Shared text: \(sharedText)")
                            completion(sharedText)
                        }
                    } else if let error = error {
                        print("Failed to load item: \(error)")
                    } else {
                        print("Item is not a string")
                    }
                }
            } else {
                print("Shared item is neither a URL nor plain text")
            }
        }
    }
}

class MyPrintPageRenderer: UIPrintPageRenderer {
    let myText: String
    let myImage: UIImage
    
    init(text: String, image: UIImage) {
        myText = "\(text)\n\nGenerated by QR Share Pro"
        myImage = image
        super.init()
    }
    
    override var numberOfPages: Int {
        return 1
    }
    
    override func drawContentForPage(at pageIndex: Int, in contentRect: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18.0),
            .paragraphStyle: paragraphStyle
        ]
        
        let imageRect = CGRect(x: contentRect.midX - 100, y: contentRect.midY - 150, width: 200, height: 200)
        myImage.draw(in: imageRect)
        
        let textRect = CGRect(x: contentRect.origin.x, y: imageRect.maxY + 20, width: contentRect.width, height: 100)
        (myText as NSString).draw(in: textRect, withAttributes: attributes)
    }
}
