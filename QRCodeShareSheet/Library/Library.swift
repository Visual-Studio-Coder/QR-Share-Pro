//
//  Library.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/21/24.
//

import SwiftUI

@MainActor
struct AsyncCachedImage<ImageView: View, PlaceholderView: View>: View {
    var url: URL?
    @ViewBuilder var content: (Image) -> ImageView
    @ViewBuilder var placeholder: () -> PlaceholderView
    
    @State var image: UIImage? = nil
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> ImageView, @ViewBuilder placeholder: @escaping () -> PlaceholderView) {
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
    
    private func downloadPhoto() async -> UIImage? {
        do {
            guard let url else { return nil }
            
            if let cachedResponse = URLCache.shared.cachedResponse(for: .init(url: url)) {
                return UIImage(data: cachedResponse.data)
            } else {
                let (data, response) = try await URLSession.shared.data(from: url)
                
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
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var editMode = false
    
    @State private var searchText = ""
    @State private var searchTag = "All"
    @State private var showingEditButtonDeleteConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var currentQRCode = QRCode(text: "")
    
    @State private var showOfflineText = true
    
    @State private var showingClearHistoryConfirmation = false
    
    private var allSearchTags = ["All", "URL", "Text"]
    
    private let monitor = NetworkMonitor()
    
    func save() async throws {
        qrCodeStore.save(history: qrCodeStore.history)
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
        NavigationStack {
            VStack {
                if qrCodeStore.history.isEmpty {
                    VStack {
                        Spacer()
                        
                        Image(systemName: "clock.arrow.circlepath")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .padding(.bottom, 10)
                        
                        Text("History")
                            .font(.title)
                            .bold()
                            .padding(.bottom, 10)
                        
                        Text("Scan, create, or share a QR code.")
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
                                .bold()
                            
                            Text(searchTag != "All" ? "Check the spelling or remove the filter." : "Check the spelling or try a new search.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    }
                    
                    List {
                        if !monitor.isActive && showOfflineText {
                            Section("Network") {
                                Button {
                                    showOfflineText = false
                                } label: {
                                    HStack {
                                        Label("You're offline.", systemImage: "network.slash")
                                        Spacer()
                                        Image(systemName: "multiply.circle.fill")
                                            .foregroundStyle(Color.gray)
                                    }
                                }
                            }
                        }
                        
                        if !x.isEmpty {
                            Section {
                                if editMode {
                                    Button {
                                        showingClearHistoryConfirmation = true
                                    } label: {
                                        Label("Clear History", systemImage: "trash")
                                    }
                                }
                                
                                ForEach(x) { i in
                                    NavigationLink {
                                        HistoryDetailInfo(qrCode: i)
                                            .environmentObject(qrCodeStore)
                                    } label: {
                                        HStack {
                                            if isValidURL(i.text) {
                                                if !monitor.isActive {
                                                    Image(systemName: "network")
                                                        .foregroundStyle(.white)
                                                        .font(.largeTitle)
                                                        .padding()
                                                        .background(Color.accentColor)
                                                        .frame(width: 50, height: 50)
                                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                                } else {
                                                    AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: i.text)!.host!).ico")) { i in
                                                        i
                                                            .resizable()
                                                            .aspectRatio(1, contentMode: .fit)
                                                            .frame(width: 50, height: 50)
                                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                                    } placeholder: {
                                                        ProgressView()
                                                    }
                                                }
                                            } else {
                                                i.qrCode?.toImage()?
                                                    .resizable()
                                                    .frame(width: 50, height: 50)
                                            }
                                            
                                            VStack(alignment: .leading) {
                                                Text(i.text)
                                                    .bold()
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
                                    .swipeActions(edge: .leading) {
                                        Button {
                                        } label: {
                                            Label("Save", systemImage: i.bookmarked ? "bookmark.slash" : "bookmark")
                                        }
                                        .tint(.indigo)
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
                                .confirmationDialog("Clear History?", isPresented: $showingClearHistoryConfirmation, titleVisibility: .visible) {
                                    Button("Clear History", role: .destructive) {
                                        withAnimation {
                                            qrCodeStore.history = []
                                            
                                            Task {
                                                do {
                                                    try await save()
                                                } catch {
                                                    print(error)
                                                }
                                            }
                                            
                                            showingClearHistoryConfirmation = false
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
                    .searchable(text: $searchText, prompt: "Search History")
                }
            }
            .environment(\.editMode, Binding(get: { editMode ? .active : .inactive }, set: { editMode = ($0 == .active) }))
            .navigationTitle(qrCodeStore.history.isEmpty ? "" : "History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !qrCodeStore.history.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(allSearchTags, id: \.self) { i in
                                Button {
                                    searchTag = i
                                } label: {
                                    if searchTag == i {
                                        Label(i, systemImage: "checkmark")
                                    } else {
                                        Text(i)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: searchTag == "All" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        }
                    }
                }
                
                if !qrCodeStore.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                editMode.toggle()
                            }
                        } label: {
                            Text(editMode ? "Done" : "Edit")
                        }
                    }
                }
            }
            .onDisappear {
                editMode = false
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
