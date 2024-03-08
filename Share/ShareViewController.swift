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
    
    var body: some View {
        ZStack {
            AnimatedRainbowBackground()
            
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
                    }, label: {
                        HStack {
                            Spacer()
                            Text("**Dismiss**")
                                .font(.title)
                                .padding(.vertical, 16)
                            Spacer()
                        }
                    })
                    .buttonStyle(.borderedProminent)
                    .padding(16)
                    .tint(Color(UIColor(red: 0.11, green: 0.14, blue: 0.79, alpha: 1.0)))
                }
            }
        }
        .onAppear {
            loadSharedText { sharedText in
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

        if let outputImage = filter.outputImage {
            let context = CIContext()
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
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

struct AnimatedRainbowBackground: View {
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .indigo, .purple]
    @State private var colorCycle = 0.0

    var body: some View {
        LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
            .hueRotation(Angle(degrees: colorCycle))
            .onAppear {
                withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                    colorCycle = 360
                }
            }
    }
}
