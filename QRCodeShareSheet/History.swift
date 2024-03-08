import SwiftUI

struct History: View {
    @Environment(\.editMode) private var editMode
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var searchText = ""
    @State private var searchTag = "All"
    @State private var showNewQRCodeSheet = false
    @State private var showingSearchSheet = false
    @State private var showingDeleteConfirmation = false
    
    private var allSearchTags = ["All", "URL"]
    
    func save() async throws {
        try await qrCodeStore.save(history: qrCodeStore.history)
    }
    
    private func deleteItems(at offsets: IndexSet) {
        qrCodeStore.history.remove(atOffsets: offsets)
        
        Task {
            do {
                try await save()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    var searchResults: [QRCode] {
        guard !searchText.isEmpty else { return [] }
        
        return qrCodeStore.history.filter { $0.text.lowercased().contains(searchText.lowercased()) }
    }
    
    func isValidURL(_ string: String) -> Bool {
        if let url = URLComponents(string: string) {
            return url.scheme != nil && !url.scheme!.isEmpty
        } else {
            return false
        }
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
                        
                        Text("No QR Codes Yet")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom, 10)
                        
                        Text("Saved QR codes appear here.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 50)
                            .padding(.bottom, 30)
                        
                        Button {
                            showNewQRCodeSheet = true
                        } label: {
                            Label("**New QR Code**", systemImage: "qrcode")
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .sheet(isPresented: $showNewQRCodeSheet) {
                            NavigationView {
                                NewQRCode()
                                    .navigationTitle("New QR Code")
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("Done") {
                                                showNewQRCodeSheet = false
                                            }
                                        }
                                    }
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(qrCodeStore.history.reversed()) { i in
                            NavigationLink {
                                HistoryDetailInfo(qrCode: i)
                                    .environmentObject(qrCodeStore)
                            } label: {
                                HStack {
                                    if isValidURL(i.text) {
                                        Image(systemName: "network")
                                            .padding()
                                            .font(.title)
//                                            .resizable()
                                            .frame(width: 50, height: 50)
                                            .background(.blue)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    } else {
                                        i.qrCode?.toImage()?
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(i.text)
                                            .fontWeight(.bold)
                                        
                                        Text(i.date, format: .dateTime)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .confirmationDialog("Delete QR Code?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                                Button("Delete QR Code", role: .destructive) {
                                    if let idx = qrCodeStore.indexOfQRCode(withID: i.id) {
                                        qrCodeStore.history.remove(at: idx)
                                        
                                        Task {
                                            do {
                                                try await save()
                                            } catch {
                                                print(error)
                                            }
                                        }
                                    }
                                    
                                    showingDeleteConfirmation = false
                                }
                                
                                Button("Cancel", role: .cancel) {
                                    showingDeleteConfirmation = false
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !qrCodeStore.history.isEmpty {
                        Button {
                            showingSearchSheet = true
                        } label: {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !qrCodeStore.history.isEmpty {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingSearchSheet) {
                NavigationView {
                    VStack {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(allSearchTags, id: \.self) { i in
                                    Button {
                                        searchTag = i
                                    } label: {
                                        Text(i)
                                            .padding(.vertical, 13)
                                            .padding(.horizontal, 25)
                                            .background(searchTag == i ? .blue : .gray)
                                            .foregroundStyle(Color.primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                            }
                        }
                        .padding(.leading, 8)
                        
                        List(searchResults) { i in
                            NavigationLink {
                                HistoryDetailInfo(qrCode: i)
                                    .environmentObject(qrCodeStore)
                            } label: {
                                HStack {
                                    i.qrCode?.toImage()?
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text(i.text)
                                            .fontWeight(.bold)
                                        
                                        Text(i.date, format: .dateTime)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText)
                    .overlay {
                        if searchText.isEmpty {
                            VStack {
                                Image(systemName: "magnifyingglass")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 80)
                                    .padding(.bottom, 10)
                                
                                Text("Search")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .padding(.bottom, 10)
                                
                                Text("Search through your library.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 50)
                                    .padding(.bottom, 30)
                            }
                        } else if searchResults.isEmpty {
                            VStack {
                                Image(systemName: "magnifyingglass")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 80)
                                    .padding(.bottom, 10)
                                
                                Text("No Results")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .padding(.bottom, 10)
                                
                                Text(searchTag != "All" ? "Check your spelling or try again." : "Check your spelling or remove the search tag.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 50)
                                    .padding(.bottom, 30)
                            }
                        }
                    }
                    .navigationTitle("Search")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingSearchSheet = false
                            }
                        }
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
