import MapKit
import Photos
import SwiftUI
import Foundation

func fetchTitle(from url: URL, completion: @escaping (String?) -> Void) {
    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        if let data = data,
           let html = String(data: data, encoding: .utf8),
           let titleRange = html.range(of: "<title>(.*?)</title>", options: .regularExpression),
           !titleRange.isEmpty {
            var title = String(html[titleRange]).replacingOccurrences(of: "<title>", with: "").replacingOccurrences(of: "</title>", with: "")
            
            if let data = title.data(using: .utf8),
               let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                title = attributedString.string
            }
            
            // Remove non-ASCII characters
            title = title.asciiDecoded
            
            completion(title)
        } else {
            completion(nil)
        }
    }
    task.resume()
}

struct HistoryDetailInfo: View {
    @Environment(\.presentationMode) var presentationMode: Binding
    @Environment(\.colorScheme) var colorScheme
    
    @AppStorage("showWebsiteFavicons") private var showWebsiteFavicons = AppSettings.showWebsiteFavicons
    
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var title: String?
    @State private var originalText = ""
    @State private var showingAboutAppSheet = false
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var showSavedAlert = false
    @State private var showExceededLimitAlert = false
    @State private var showingLocation = false
    @State private var showingFullURLSheet = false
    @State private var showingFullOriginalURLSheet = false
    @State private var showingAllTextSheet = false
    @State private var qrCodeImage: UIImage = .init()
    @State private var locationName: String?
    @State private var showPermissionsError = false
    
    @State private var copiedText = false
    @State private var copiedCleanURL = false
    @State private var copiedOriginalURL = false
    
    private let monitor = NetworkMonitor()
    
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    @State var qrCode: QRCode
    
    func save() async throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }
    
    // Add this function in your view
    func fetchWebsiteTitle() {
        let urlString = qrCode.text.extractFirstURL()
        if let url = URL(string: urlString) {
            fetchTitle(from: url) { title in
                DispatchQueue.main.async {
                    self.title = title
                }
            }
        }
    }
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    func generateQRCode(from string: String) {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let qrCode = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledQrCode = qrCode.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledQrCode, from: scaledQrCode.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    var body: some View {
        VStack {
            if isEditing {
                NavigationStack {
                    ScrollView {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .draggable(Image(uiImage: qrCodeImage))
                            .contextMenu {
                                if !qrCode.text.isEmpty {
                                    Button {
                                        if qrCode.text.count > 3000 {
                                            showExceededLimitAlert = true
                                        } else {
                                            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                                if status == .denied {
                                                    showPermissionsError = true
                                                } else {
                                                    UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                                    showSavedAlert = true
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                                    }
                                }
                            }
                        
                        HStack {
                            Spacer()
                            
                            Text("\(qrCode.text.count)/3000 characters")
                                .foregroundStyle(qrCode.text.count > 3000 ? .red : .secondary)
                                .bold()
                        }
                        .padding(.top, 3)
                        .padding(.trailing)
                        
                        TextField("Create your own QR code...", text: $qrCode.text)
                            .padding()
                            .background(.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .keyboardType(.alphabet)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(.horizontal)
                            .onSubmit {
                                if qrCode.text.count > 3000 {
                                    showExceededLimitAlert = true
                                } else if !qrCode.text.extractFirstURL().isEmpty {
                                    if qrCode.text != originalText, let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                                        qrCode.date = Date.now
                                        qrCode.wasEdited = true
                                        qrCodeStore.history[idx] = qrCode
                                        
                                        Task {
                                            do {
                                                try await save()
                                            } catch {
                                                print(error.localizedDescription)
                                            }
                                        }
                                    }
                                    
                                    isEditing.toggle()
                                }
                            }
                            .alert("You'll need to remove \(qrCode.text.count - 3000) characters first!", isPresented: $showExceededLimitAlert) {}
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            } else {
                ScrollView {
                    Image(uiImage: qrCodeImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .opacity((showingFullURLSheet || showingAllTextSheet) ? 0.3 : 1)
                        .transition(.opacity)
                        .animation(Animation.easeInOut(duration: 0.3), value: showingFullURLSheet || showingAllTextSheet)
                        .draggable(Image(uiImage: qrCodeImage))
                        .contextMenu {
                            Button {
                                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                    if status == .denied {
                                        showPermissionsError = true
                                    } else {
                                        UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                        showSavedAlert = true
                                    }
                                }
                            } label: {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                        }
                    
                    VStack(alignment: .leading) {
                        if qrCode.text.extractFirstURL().isValidURL() {
                            HStack {
                                if showWebsiteFavicons {
                                    AsyncCachedImage(url: URL(string: qrCode.text.extractFirstURL())) { i in
                                        i
                                            .interpolation(.none)
                                            .resizable()
                                            .aspectRatio(1, contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    } placeholder: {
                                        ProgressView()
                                            .controlSize(.large)
                                            .frame(width: 50, height: 50)
                                    }
                                    .onTapGesture {
                                        showingFullURLSheet = true
                                    }
                                }
                                
                                Text(title ?? URL(string: qrCode.text.extractFirstURL())!.host!.removeTrackers())
                                    .bold()
                                    .lineLimit(2)
                                    .draggable(title ?? URL(string: qrCode.text.extractFirstURL())!.host!.removeTrackers())
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                        } label: {
                                            Label("Copy URL", systemImage: "doc.on.doc")
                                        }
                                        
                                        Button {
                                            if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            Label("Open URL", systemImage: "safari")
                                        }
                                        
                                        Divider()
                                        
                                        Button {
                                            showingFullURLSheet = true
                                        } label: {
                                            Label("Show Full URL", systemImage: "arrow.up.right")
                                        }
                                    }
                                    .onTapGesture {
                                        showingFullURLSheet = true
                                    }
                                    .onAppear {
                                        fetchWebsiteTitle()
                                    }
                                
                                Spacer()
                                
                                Button {
                                    if let url = URL(string: qrCode.text.extractFirstURL()) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Open", systemImage: "safari")
                                        .padding(8)
                                        .foregroundStyle(.white)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                        .bold()
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(qrCode.text.extractFirstURL())
                                        .lineLimit(2)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .draggable(qrCode.text.extractFirstURL())
                                        .contextMenu {
                                            Button {
                                                UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                            } label: {
                                                Label("Copy URL", systemImage: "doc.on.doc")
                                            }
                                            
                                            Button {
                                                if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                Label("Open URL", systemImage: "safari")
                                            }
                                            
                                            Divider()
                                            
                                            Button {
                                                showingFullURLSheet = true
                                            } label: {
                                                Label("Show Full URL", systemImage: "arrow.up.right")
                                            }
                                        }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                                .onTapGesture {
                                    showingFullURLSheet = true
                                }
                            }
                            .padding(.horizontal)
                            .sheet(isPresented: $showingFullURLSheet) {
                                NavigationStack {
                                    List {
                                        Section {
                                            Button {
                                                if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                Label("Open URL", systemImage: "safari")
                                                    .foregroundStyle(accentColorManager.accentColor)
                                            }
                                        }
                                        
                                        if qrCode.text.extractFirstURL() != qrCode.originalURL {
                                            Section {
                                                Button {
                                                    withAnimation {
                                                        copiedOriginalURL = false
                                                        copiedCleanURL = true
                                                    }
                                                    
                                                    UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                                } label: {
                                                    Label(copiedCleanURL ? "Copied URL" : "Copy URL", systemImage: copiedCleanURL ? "checkmark" : "doc.on.doc")
                                                        .foregroundStyle(accentColorManager.accentColor)
                                                }
                                                .onChange(of: copiedCleanURL) { _ in
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                        withAnimation {
                                                            copiedCleanURL = false
                                                        }
                                                    }
                                                }
                                                
                                                Menu {
                                                    Button {
                                                        UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                                    } label: {
                                                        Label("Copy URL", systemImage: "doc.on.doc")
                                                    }
                                                    
                                                    Button {
                                                        if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                            UIApplication.shared.open(url)
                                                        }
                                                    } label: {
                                                        Label("Open URL", systemImage: "safari")
                                                    }
                                                } label: {
                                                    Text(qrCode.text.extractFirstURL())
                                                        .foregroundStyle(.primary)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .contextMenu {
                                                    Button {
                                                        UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                                    } label: {
                                                        Label("Copy URL", systemImage: "doc.on.doc")
                                                    }
                                                    
                                                    Button {
                                                        if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                            UIApplication.shared.open(url)
                                                        }
                                                    } label: {
                                                        Label("Open URL", systemImage: "safari")
                                                    }
                                                }
                                            } header: {
                                                Text("Sanitized URL")
                                            } footer: {
                                                Text("QR Share Pro removes tracking parameters from links and finds the final redirect of every URL, so you can feel safe clicking on links.")
                                            }
                                        }
                                        
                                        Section {
                                            Button {
                                                withAnimation {
                                                    copiedCleanURL = false
                                                    copiedOriginalURL = true
                                                }
                                                
                                                UIPasteboard.general.string = qrCode.originalURL
                                            } label: {
                                                Label(copiedOriginalURL ? "Copied URL" : "Copy URL", systemImage: copiedOriginalURL ? "checkmark" : "doc.on.doc")
                                                    .foregroundStyle(accentColorManager.accentColor)
                                            }
                                            .onChange(of: copiedOriginalURL) { _ in
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                    withAnimation {
                                                        copiedOriginalURL = false
                                                    }
                                                }
                                            }
                                            
                                            Menu {
                                                Button {
                                                    UIPasteboard.general.string = qrCode.originalURL
                                                } label: {
                                                    Label("Copy URL", systemImage: "doc.on.doc")
                                                }
                                                
                                                Button {
                                                    if let url = URL(string: qrCode.originalURL.extractFirstURL()) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                } label: {
                                                    Label("Open URL", systemImage: "safari")
                                                }
                                            } label: {
                                                Text(qrCode.originalURL)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .contextMenu {
                                                Button {
                                                    UIPasteboard.general.string = qrCode.originalURL
                                                } label: {
                                                    Label("Copy URL", systemImage: "doc.on.doc")
                                                }
                                                
                                                Button {
                                                    if let url = URL(string: qrCode.originalURL) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                } label: {
                                                    Label("Open URL", systemImage: "safari")
                                                }
                                            }
                                        } header: {
                                            if qrCode.text.extractFirstURL() != qrCode.originalURL {
                                                Text("Original Text From QR Code")
                                            } else if qrCode.text != qrCode.originalURL {
                                                Text("Original URL")
                                            } else {
                                                Text("")
                                            }
                                        }
                                    }
                                    .navigationTitle(URL(string: qrCode.text.extractFirstURL())!.prettify().host!.replacingOccurrences(of: "www.", with: ""))
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("Done") {
                                                showingFullURLSheet = false
                                            }
                                            .tint(accentColorManager.accentColor)
                                        }
                                    }
                                }
                                .presentationDetents([.medium, .large])
                            }
                        } else if let url = URL(string: qrCode.text.extractFirstURL()), UIApplication.shared.canOpenURL(url) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .onTapGesture {
                                        showingFullURLSheet = true
                                    }
                                
                                Text(URL(string: url.absoluteString)?.host?.replacingOccurrences(of: "www.", with: "") ?? qrCode.text.extractFirstURL())
                                    .bold()
                                    .lineLimit(2)
                                    .draggable(URL(string: url.absoluteString)?.host?.replacingOccurrences(of: "www.", with: "") ?? qrCode.text.extractFirstURL())
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                        } label: {
                                            Label("Copy Deep Link", systemImage: "doc.on.doc")
                                        }
                                        
                                        Button {
                                            if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            Label("Open Deep Link", systemImage: "safari")
                                        }
                                        
                                        Divider()
                                        
                                        Button {
                                            showingFullURLSheet = true
                                        } label: {
                                            Label("Show Full URL", systemImage: "arrow.up.right")
                                        }
                                    }
                                    .onTapGesture {
                                        showingFullURLSheet = true
                                    }
                                
                                Spacer()
                                
                                Button {
                                    if let url = URL(string: qrCode.text.extractFirstURL()) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Open", systemImage: "link")
                                        .padding(8)
                                        .foregroundStyle(.white)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                        .bold()
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(qrCode.text.extractFirstURL())
                                        .lineLimit(2)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .draggable(qrCode.text.extractFirstURL())
                                        .contextMenu {
                                            Button {
                                                UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                            } label: {
                                                Label("Copy Deep Link", systemImage: "doc.on.doc")
                                            }
                                            
                                            Button {
                                                if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                Label("Open Deep Link", systemImage: "safari")
                                            }
                                            
                                            Divider()
                                            
                                            Button {
                                                showingFullURLSheet = true
                                            } label: {
                                                Label("Show Full URL", systemImage: "arrow.up.right")
                                            }
                                        }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                                .onTapGesture {
                                    showingFullURLSheet = true
                                }
                            }
                            .padding(.horizontal)
                            .sheet(isPresented: $showingFullURLSheet) {
                                NavigationStack {
                                    List {
                                        Section {
                                            Button {
                                                if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                Label("Open Deep Link", systemImage: "link")
                                                    .foregroundStyle(accentColorManager.accentColor)
                                            }
                                        }
                                        Section {
                                            Button {
                                                withAnimation {
                                                    copiedOriginalURL = true
                                                }
                                                
                                                UIPasteboard.general.string = qrCode.originalURL
                                            } label: {
                                                Label(copiedOriginalURL ? "Copied Deep Link" : "Copy Deep Link", systemImage: copiedOriginalURL ? "checkmark" : "doc.on.doc")
                                                    .foregroundStyle(accentColorManager.accentColor)
                                            }
                                            .onChange(of: copiedOriginalURL) { _ in
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                    withAnimation {
                                                        copiedOriginalURL = false
                                                    }
                                                }
                                            }
                                            
                                            Menu {
                                                Button {
                                                    UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                                } label: {
                                                    Label("Copy Deep Link", systemImage: "doc.on.doc")
                                                }
                                                
                                                Button {
                                                    if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                } label: {
                                                    Label("Open Deep Link", systemImage: "link")
                                                }
                                            } label: {
                                                Text(qrCode.text.extractFirstURL())
                                                    .foregroundStyle(.primary)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .contextMenu {
                                                Button {
                                                    UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                                } label: {
                                                    Label("Copy Deep Link", systemImage: "doc.on.doc")
                                                }
                                                
                                                Button {
                                                    if let url = URL(string: qrCode.text.extractFirstURL()) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                } label: {
                                                    Label("Open Deep Link", systemImage: "link")
                                                }
                                            }
                                        } header: {
                                            Text("Deep Link")
                                        }
                                    }
                                    .navigationTitle(URL(string: qrCode.text.extractFirstURL())!.absoluteString)
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("Done") {
                                                showingFullURLSheet = false
                                            }
                                            .tint(accentColorManager.accentColor)
                                        }
                                    }
                                }
                                .presentationDetents([.medium, .large])
                            }
                        } else {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill()
                                        .foregroundColor(colorScheme == .light ? .black : .white)
                                    Image(systemName: "textformat")
                                        .foregroundColor(colorScheme == .light ? .white : .black)
                                        .scaledToFit()
                                        .padding(2)
                                }
                                .frame(width: 50, height: 50)
                                Text(qrCode.text.extractFirstURL())
                                    .bold()
                                    .lineLimit(2)
                                    .onTapGesture {
                                        showingAllTextSheet = true
                                    }
                                    .draggable(qrCode.text.extractFirstURL())
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                        } label: {
                                            Label("Copy Text", systemImage: "doc.on.doc")
                                        }
                                        
                                        Divider()
                                        
                                        Button {
                                            showingAllTextSheet = true
                                        } label: {
                                            Label("Show Full Text", systemImage: "arrow.up.right")
                                        }
                                    }
                                
                                Spacer()
                                
                                Button {
                                    showingAllTextSheet = true
                                } label: {
                                    HStack {
                                        Text("Show Full Text")
                                            .fixedSize(horizontal: true, vertical: false)
                                        
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .padding(8)
                                    .foregroundStyle(.white)
                                    .background(Color.accentColor)
                                    .clipShape(Capsule())
                                    .bold()
                                }
                            }
                            .padding(.horizontal)
                            .sheet(isPresented: $showingAllTextSheet) {
                                NavigationStack {
                                    List {
                                        Section {
                                            Button {
                                                withAnimation {
                                                    copiedText = true
                                                }
                                                
                                                UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                            } label: {
                                                Label(copiedText ? "Copied Text" : "Copy Text", systemImage: copiedText ? "checkmark" : "doc.on.doc")
                                                    .foregroundStyle(accentColorManager.accentColor)
                                            }
                                            .onChange(of: copiedText) { _ in
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                    withAnimation {
                                                        copiedText = false
                                                    }
                                                }
                                            }
                                            
                                            Menu {
                                                Button {
                                                    UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                                } label: {
                                                    Label("Copy Text", systemImage: "doc.on.doc")
                                                }
                                            } label: {
                                                Text(qrCode.text.extractFirstURL())
                                                    .foregroundStyle(.primary)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .contextMenu {
                                                Button {
                                                    UIPasteboard.general.string = qrCode.text.extractFirstURL()
                                                } label: {
                                                    Label("Copy Text", systemImage: "doc.on.doc")
                                                }
                                            }
                                        } footer: {
                                            Text(qrCode.text.extractFirstURL().count == 1 ? "1 character" : "\(qrCode.text.extractFirstURL().count) characters")
                                        }
                                    }
                                    .navigationTitle(qrCode.text.extractFirstURL())
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("Done") {
                                                showingAllTextSheet = false
                                            }
                                            .tint(accentColorManager.accentColor)
                                        }
                                    }
                                }
                                .presentationDetents([.medium, .large])
                            }
                        }
                        
                        Divider()
                            .padding(.horizontal)
                            .padding(.bottom, 5)
                        
                        if qrCode.wasScanned && !qrCode.scanLocation.isEmpty {
                            if monitor.isActive {
                                Button {
                                    withAnimation(.default) {
                                        showingLocation.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text(locationName ?? "(\(qrCode.scanLocation[0]), \(qrCode.scanLocation[1])")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .rotationEffect(Angle(degrees: showingLocation ? 0 : -90))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                                .onAppear {
                                    let geocoder = CLGeocoder()
                                    let location = CLLocation(latitude: qrCode.scanLocation[0], longitude: qrCode.scanLocation[1])
                                    geocoder.reverseGeocodeLocation(location) { placemarks, error in
                                        if let placemark = placemarks?.first {
                                            var locationString = ""
                                            if let street = placemark.thoroughfare {
                                                locationString += street
                                            }
                                            if let city = placemark.locality {
                                                locationString += ", \(city)"
                                            }
                                            if let state = placemark.administrativeArea {
                                                locationString += ", \(state)"
                                            }
                                            if let country = placemark.country {
                                                locationString += ", \(country)"
                                            }
                                            locationName = locationString.isEmpty ? "UNKNOWN LOCATION" : locationString
                                        } else if let error = error {
                                            print("Failed to get location name: \(error)")
                                        }
                                    }
                                }
                                
                                if showingLocation {
                                    let annotation = [ScanLocation(name: locationName ?? "UNKNOWN LOCATION", coordinate: CLLocationCoordinate2D(latitude: qrCode.scanLocation[0], longitude: qrCode.scanLocation[1]))]
                                    
                                    Map(coordinateRegion: .constant(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: qrCode.scanLocation[0], longitude: qrCode.scanLocation[1]), span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001))), interactionModes: [.all], annotationItems: annotation) {
                                        MapMarker(coordinate: $0.coordinate, tint: .accentColor)
                                    }
                                    .aspectRatio(16 / 9, contentMode: .fit)
                                }
                            } else {
                                Text("You're offline. Unable to show Apple Maps.")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }
                            if !showingLocation {
                                Divider()
                                    .padding(.horizontal)
                                    .padding(.vertical, 5)
                            }
                        }
                        
                        HStack(spacing: 0) {
                            if qrCode.wasEdited {
                                Text("Last edited: ")
                            } else if qrCode.wasCreated {
                                Text("Created on: ")
                            } else if qrCode.wasScanned {
                                Text("Scanned on: ")
                            } else {
                                Text("Generated on: ")
                            }
                            
                            Text(qrCode.date, format: .dateTime)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .alert("We need permission to save this QR code to your photo library.", isPresented: $showPermissionsError) {
            Button("Open Settings", role: .cancel) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(settingsURL)
                {
                    UIApplication.shared.open(settingsURL)
                }
            }
        }
        .onAppear {
            Task {
                if qrCode.text.extractFirstURL().isValidURL() {
                    qrCode.text = URL(string: qrCode.text.extractFirstURL().removeTrackers())!.absoluteString
                    
                    do {
                        try await save()
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                
                generateQRCode(from: qrCode.text.extractFirstURL())
                originalText = qrCode.text.extractFirstURL()
            }
        }
        .accentColor(accentColorManager.accentColor)
        .navigationTitle(!qrCode.text.extractFirstURL().isValidURL() ? qrCode.text.extractFirstURL() : URL(string: qrCode.text.extractFirstURL())!.host!.replacingOccurrences(of: "www.", with: ""))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if qrCode.text.extractFirstURL() != originalText {
                            showingResetConfirmation = true
                        } else {
                            withAnimation {
                                isEditing = false
                            }
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                if qrCode.text.extractFirstURL().isValidURL() {
                    ShareLink(item: URL(string: qrCode.text.extractFirstURL())!) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    let qrCodeImage = Image(uiImage: qrCodeImage)
                    
                    ShareLink(item: qrCodeImage, preview: SharePreview(qrCode.text.extractFirstURL(), image: qrCodeImage)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            if !isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            if qrCode.text.extractFirstURL().count > 3000 {
                                showExceededLimitAlert = true
                            } else {
                                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                    if status == .denied {
                                        showPermissionsError = true
                                    } else {
                                        UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                        showSavedAlert = true
                                    }
                                }
                            }
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }
                        .disabled(qrCode.text.extractFirstURL().isEmpty)
                        
                        Button {
                            if let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                                withAnimation {
                                    qrCodeStore.history[idx].pinned.toggle()
                                    qrCode.pinned.toggle()
                                    
                                    Task {
                                        do {
                                            try await save()
                                        } catch {
                                            print(error.localizedDescription)
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label(qrCode.pinned ? "Unpin" : "Pin", systemImage: qrCode.pinned ? "pin.slash.fill" : "pin")
                        }
                        
                        Button {
                            withAnimation {
                                if isEditing {
                                    if qrCode.text.extractFirstURL() != originalText, let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                                        qrCode.date = Date.now
                                        qrCode.wasEdited = true
                                        qrCodeStore.history[idx] = qrCode
                                        
                                        Task {
                                            do {
                                                try await save()
                                            } catch {
                                                print(error.localizedDescription)
                                            }
                                        }
                                    }
                                }
                                
                                isEditing.toggle()
                            }
                        } label: {
                            Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                        }
                        .disabled(qrCode.text.extractFirstURL().isEmpty)
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            isEditing = false
                        }
                    } label: {
                        Text("Done")
                    }
                }
            }
        }
        .confirmationDialog("Delete QR Code?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete QR Code", role: .destructive) {
                if let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                    qrCodeStore.history.remove(at: idx)
                    
                    Task {
                        do {
                            try await save()
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }
                
                showingDeleteConfirmation = false
                presentationMode.wrappedValue.dismiss()
            }
        }
        .confirmationDialog("Discard Changes?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive) {
                qrCode.text = originalText
                
                withAnimation {
                    isEditing = false
                }
            }
        }
        .alert("Saved to Photos!", isPresented: $showSavedAlert) {}
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        NavigationStack {
            HistoryDetailInfo(qrCode: QRCode(text: "https://duckduckgo.com/", originalURL: "https://duckduckgo.com/", scanLocation: [51.507222, -0.1275], wasScanned: true))
                .environmentObject(qrCodeStore)
        }
    }
}
