import SwiftUI

@MainActor
struct AsyncCachedImage<ImageView: View, PlaceholderView: View>: View {
    // Input dependencies
    var url: URL?
    @ViewBuilder var content: (Image) -> ImageView
    @ViewBuilder var placeholder: () -> PlaceholderView
    
    // Downloaded image
    @State var image: UIImage? = nil
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> ImageView,
        @ViewBuilder placeholder: @escaping () -> PlaceholderView
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        VStack {
            if let uiImage = image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .onAppear {
                        Task {
                            image = await downloadPhoto()
                        }
                    }
            }
        }
    }
    
    // Downloads if the image is not cached already
    // Otherwise returns from the cache
    private func downloadPhoto() async -> UIImage? {
        do {
            guard let url else { return nil }
            
            // Check if the image is cached already
            if let cachedResponse = URLCache.shared.cachedResponse(for: .init(url: url)) {
                return UIImage(data: cachedResponse.data)
            } else {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Save returned image data into the cache
                URLCache.shared.storeCachedResponse(.init(response: response, data: data), for: .init(url: url))
                
                guard let image = UIImage(data: data) else {
                    return nil
                }
                
                return image
            }
        } catch {
            print("Error downloading: \(error)")
            return nil
        }
    }
}

struct History: View {
    @Environment(\.editMode) private var editMode
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var searchText = ""
    @State private var searchTag = "All"
    @State private var showingEditButtonDeleteConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var currentQRCode = QRCode(text: "")
    
    private var allSearchTags = ["All", "URL", "Text"]
    
    func save() async throws {
        try await qrCodeStore.save(history: qrCodeStore.history)
    }
    
    var searchResults: [QRCode] {
        guard !searchText.isEmpty else { return qrCodeStore.history }
        
        return qrCodeStore.history.filter { $0.text.lowercased().contains(searchText.lowercased()) }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        if let url = URLComponents(string: string) {
            return url.scheme != nil && !url.scheme!.isEmpty
        } else {
            return false
        }
    }
    
    private func getTypeOf(type: String) -> String {
        return isValidURL(type) ? "URL" : "Text"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if qrCodeStore.history.isEmpty {
                    VStack {
                        Spacer()
                        
                        Image(systemName: "books.vertical.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .padding(.bottom, 10)
                        
                        Text("Library")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom, 10)
                        
                        Text("Save QR codes to your **Library**,\nand they'll appear here.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 50)
                            .padding(.bottom, 30)
                        
                        Spacer()
                    }
                } else {
                    let x = searchResults.sorted(by: { $0.date > $1.date }).filter({ searchTag == "All" ? true : getTypeOf(type: $0.text) == searchTag })
                    
                    if x.isEmpty {
                        VStack {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .padding(.bottom, 10)
                                .foregroundStyle(.secondary)
                            
                            Text("No Results")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(searchTag != "All" ? "Check the spelling or remove the filter." : "Check the spelling or try a new search.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    }
                    
                    List {
                        if !x.isEmpty {
                            Section {
                                ForEach(x) { i in
                                    NavigationLink {
                                        HistoryDetailInfo(qrCode: i)
                                            .environmentObject(qrCodeStore)
                                    } label: {
                                        HStack {
                                            if isValidURL(i.text) {
                                                AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: i.text)!.host!).ico")) { i in
                                                    i
                                                        .resizable()
                                                        .aspectRatio(1, contentMode: .fit)
                                                        .frame(width: 50, height: 50)
                                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                                } placeholder: {
                                                    ProgressView()
                                                }
                                            } else {
                                                i.qrCode?.toImage()?
                                                    .resizable()
                                                    .frame(width: 50, height: 50)
                                            }
                                            
                                            VStack(alignment: .leading) {
                                                Text(i.text)
                                                    .fontWeight(.bold)
                                                    .lineLimit(searchText.isEmpty ? 2 : 3)
                                                
                                                Text(i.date, format: .dateTime)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            currentQRCode = i
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            currentQRCode = i
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                                .onDelete { indexSet in
//                                    qrCodeStore.history.remove(atOffsets: indexSet)
//                                    
//                                    Task {
//                                        do {
//                                            try await save()
//                                        } catch {
//                                            print(error)
//                                        }
//                                    }
                                }
                                .confirmationDialog("Delete QR Code?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                                    Button("Delete QR Code", role: .destructive) {
                                        if let idx = qrCodeStore.indexOfQRCode(withID: currentQRCode.id) {
                                            withAnimation {
                                                qrCodeStore.history.remove(at: idx)
                                                
                                                Task {
                                                    do {
                                                        try await save()
                                                    } catch {
                                                        print(error)
                                                    }
                                                }
                                                
                                                showingDeleteConfirmation = false
                                            }
                                        }
                                    }
                                }
                            } header: {
                                if searchTag == "URL" {
                                    Text(x.count == 1 ? "1 URL" : "\(x.count) URLs")
                                } else if searchTag == "Text" {
                                    Text(x.count == 1 ? "1 QR Code Found" : "\(x.count) QR Codes Found")
                                } else {
                                    Text(x.count == 1 ? "1 QR Code" : "\(x.count) QR Codes")
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search Library")
                }
            }
            .navigationTitle(qrCodeStore.history.isEmpty ? "" : "Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(allSearchTags, id: \.self) { i in
                            Button {
                                searchTag = i
                            } label: {
                                HStack {
                                    Text(i)
                                    
                                    if searchTag == i {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: searchTag == "All" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !qrCodeStore.history.isEmpty {
                        EditButton()
                    }
                }
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        History()
            .environmentObject(qrCodeStore)
    }
}
