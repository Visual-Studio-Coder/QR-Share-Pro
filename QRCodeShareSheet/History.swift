import SwiftUI

struct History: View {
    @Environment(\.editMode) private var editMode
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var showNewQRCodeSheet = false
    
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
    
    var body: some View {
        NavigationView {
            VStack {
                if qrCodeStore.history.isEmpty {
                    VStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .padding(.bottom, 10)
                        
                        Text("No QR Codes Yet")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom, 10)
                        
                        Text("See who's scanned your QR code, get detailed performance insights, and more.")
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
                    }
                } else {
                    List {
                        ForEach(qrCodeStore.history.reversed()) { i in
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
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
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
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
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
