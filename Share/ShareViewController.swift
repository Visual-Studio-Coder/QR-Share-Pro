import UIKit
import Social
import SwiftUI
import CoreImage.CIFilterBuiltins
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    var hostingView: UIHostingController<ShareView>!
    
    override func viewDidLoad() {
        isModalInPresentation = true
        
        hostingView = UIHostingController(rootView: ShareView(extensionContext: extensionContext))
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

struct ShareView: View {
    @State private var qrCodeImage: UIImage?
    var extensionContext: NSExtensionContext?
    @State private var isBackgroundVisible = false
    @State private var receivedText: String = ""
    @State private var showAlert = false
    
    var shareLabel: String {
        if URL(string: receivedText) != nil {
            return "Share URL"
        } else {
            return "Share Plaintext"
        }
    }
    
    var body: some View {
        ZStack {
            AnimatedRainbowBackground()
                .transition(.opacity)
            if let qrCodeImage = qrCodeImage {
                VStack {
                    Image(uiImage: qrCodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(10)
                        .padding(16)
                    Button(action: {
                        dismiss()
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }, label: {
                        HStack {
                            Spacer()
                            Text("**Dismiss**")
                                .font(.title)
                                .padding(.vertical, 16)
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
                    
                    HStack {
                        Button(action: {
                            let ciImage = CIImage(cgImage: qrCodeImage.cgImage!)
                            let context = CIContext()
                            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                                let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
                                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                                showAlert = true
                            }
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20))
                                Text("Save to Photos")
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
                    .padding(.horizontal, 16)      .onLongPressGesture(minimumDuration: 0, pressing: { inProgress in
                        if inProgress {
                            let generator = UIImpactFeedbackGenerator(style: .soft)
                            generator.impactOccurred()
                        }
                    }, perform: {})
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            withAnimation(.easeIn(duration: 2.0)) {
                isBackgroundVisible = true
            }
            loadSharedText { sharedText in
                receivedText = sharedText
                if let qrImage = generateQRCode(from: sharedText) {
                    qrCodeImage = qrImage
                } else {
                    print("Failed to generate QR code")
                }
            }
        }
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
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first as? NSItemProvider else {
            print("Failed to load shared item")
            return
        }
        
        if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
            itemProvider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (item, error) in
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
        } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
            itemProvider.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { (item, error) in
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

struct BouncingCircle: View {
    let color: Color
    @State private var position = CGPoint(x: CGFloat.random(in: 0...UIScreen.main.bounds.width), y: CGFloat.random(in: 0...UIScreen.main.bounds.height))
    @State private var direction = CGSize(width: CGFloat.random(in: -1...1), height: CGFloat.random(in: -1...1))
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 400, height: 400)
            .position(position)
            .blur(radius: 60)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    position = CGPoint(x: max(min(position.x + direction.width * 10, UIScreen.main.bounds.width), 0), y: max(min(position.y + direction.height * 10, UIScreen.main.bounds.height), 0))
                    if position.x == 0 || position.x == UIScreen.main.bounds.width {
                        direction.width *= -1
                    }
                    if position.y == 0 || position.y == UIScreen.main.bounds.height {
                        direction.height *= -1
                    }
                }
            }
    }
}

struct AnimatedRainbowBackground: View {
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .indigo, .purple, .pink, .gray, .white, .brown, .cyan, .yellow, .red, .orange, .yellow, .green, .blue, .indigo, .purple, .pink, .gray, .white, .brown, .cyan]
    
    var body: some View {
        ZStack {
            ForEach(colors.indices) { index in
                BouncingCircle(color: colors[index])
                    .animation(Animation.easeInOut(duration: 0.5).delay(Double(index) * 0.1))
            }
        }
    }
}
class MyPrintPageRenderer: UIPrintPageRenderer {
    let myText: String
    let myImage: UIImage

    init(text: String, image: UIImage) {
        myText = "This QR code has the following text: \n\(text)"
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
