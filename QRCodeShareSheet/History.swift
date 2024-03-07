import SwiftUI

struct History: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
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
                        } label: {
                            Label("**Create QR Code**", systemImage: "qrcode")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                } else {
                    List {
                        ForEach(qrCodeStore.history) { i in
                            NavigationLink {
                                HistoryDetailInfo(qrCode: i)
                            } label: {
                                HStack {
                                    i.qrCode?.toImage()?
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text(i.name)
                                            .fontWeight(.bold)
                                        
                                        Text(i.tinyURL)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("History")
            //            .toolbar {
            //            }
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
