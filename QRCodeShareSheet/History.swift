import SwiftUI

struct History: View {
    @Environment(\.editMode) private var editMode
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var searchText = ""
    @State private var searchTag = "All"
    @State private var showingNewQRCodeSheet = false
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
        guard !searchText.isEmpty else { return qrCodeStore.history }
        
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
                            showingNewQRCodeSheet = true
                        } label: {
                            Label("**New QR Code**", systemImage: "qrcode")
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .sheet(isPresented: $showingNewQRCodeSheet) {
                            NavigationView {
                                NewQRCode()
                                    .navigationTitle("New QR Code")
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("Done") {
                                                showingNewQRCodeSheet = false
                                            }
                                        }
                                    }
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    //                    VStack {
                    //                        ScrollView(.horizontal) {
                    //                            HStack {
                    //                                ForEach(allSearchTags, id: \.self) { i in
                    //                                    Button {
                    //                                        searchTag = i
                    //                                    } label: {
                    //                                        Text(i)
                    //                                            .padding(.vertical, 13)
                    //                                            .padding(.horizontal, 25)
                    //                                            .background(searchTag == i ? .blue : .gray)
                    //                                            .foregroundStyle(Color.primary)
                    //                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    //                                    }
                    //                                }
                    //                            }
                    //                        }
                    //                        .padding(.leading, 8)
                    //                    }
                    
                    List {
                        ForEach(searchResults.reversed()) { i in
                            NavigationLink {
                                HistoryDetailInfo(qrCode: i)
                                    .environmentObject(qrCodeStore)
                            } label: {
                                HStack {
                                    if isValidURL(i.text) {
                                        AsyncImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: i.text)!.host!).ico"))
                                            .padding()
                                            .font(.title)
                                        //                                            .resizable()
                                            .frame(width: 50, height: 50)
                                        //                                            .background(.blue)
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
                    .searchable(text: $searchText)
                    .overlay {
                        if searchResults.isEmpty {
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
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
