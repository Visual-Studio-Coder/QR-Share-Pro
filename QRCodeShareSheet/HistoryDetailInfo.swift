//
//  HistoryDetailInfo.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/25/24.
//

import SwiftUI
import MapKit

struct HistoryDetailInfo: View {
    @Environment(\.presentationMode) var presentationMode: Binding
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var qrCodeStore: QRCodeStore
    
    @State private var originalText = ""
    @State private var showingAboutAppSheet = false
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showSavedAlert = false
    @State private var showingLocation = false
    @State private var showingFullURLSheet = false
    @State private var showingAllTextSheet = false
    @State private var qrCodeImage: UIImage = UIImage()
    @State private var locationName: String?
    
    private let monitor = NetworkMonitor()
    
    @State var qrCode: QRCode
    
    func save() async throws {
        qrCodeStore.save(history: qrCodeStore.history)
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
                        
                        TextField("Create your own QR code...", text: $qrCode.text)
                            .padding()
                            .background(.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .keyboardType(.webSearch)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(.horizontal)
                        
                        Section {
                            Button {
                                qrCode.text = originalText
                            } label: {
                                Image(systemName: "arrow.circlepath")
                            }
                            .disabled(qrCode.text == originalText)
                            
                            Button {
                                UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                showSavedAlert = true
                            } label: {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                                    .foregroundStyle(.white)
                                    .opacity(qrCode.text.isEmpty ? 0.3 : 1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(colorScheme == .dark ? 0.7 : 1))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .disabled(qrCode.text.isEmpty)
                            .padding(.horizontal)
                        }
                    }
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
                    
                    VStack(alignment: .leading) {
                        if qrCode.text.isValidURL() {
                            HStack {
                                AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: qrCode.text)!.host!).ico")) { i in
                                    i
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                } placeholder: {
                                    ProgressView()
                                }
                                .onTapGesture {
                                    showingFullURLSheet = true
                                }
                                
                                Text(URL(string: qrCode.text)!.host!.replacingOccurrences(of: "www.", with: ""))
                                    .font(.largeTitle)
                                    .bold()
                                    .lineLimit(1)
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = qrCode.text
                                        } label: {
                                            Label("Copy URL", systemImage: "doc.on.doc")
                                                .tint(Color.accentColor)
                                        }
                                        
                                        Button {
                                            showingFullURLSheet = true
                                        } label: {
                                            Label("Show Full URL", systemImage: "arrow.up.right")
                                                .tint(Color.accentColor)
                                        }
                                    }
                                    .onTapGesture {
                                        showingFullURLSheet = true
                                    }
                                
                                Spacer()
                                
                                Button {
                                    if let url = URL(string: qrCode.text) {
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
                                    Text(qrCode.text)
                                        .lineLimit(2)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                                .onTapGesture {
                                    showingFullURLSheet = true
                                }
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = qrCode.text
                                    } label: {
                                        Label("Copy URL", systemImage: "doc.on.doc")
                                            .tint(Color.accentColor)
                                    }
                                    
                                    Button {
                                        showingFullURLSheet = true
                                    } label: {
                                        Label("Show Full URL", systemImage: "arrow.up.right")
                                            .tint(Color.accentColor)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .sheet(isPresented: $showingFullURLSheet) {
                                NavigationStack {
                                    List {
                                        Section {
                                            Button {
                                                if let url = URL(string: qrCode.text) {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                Label("Open URL", systemImage: "safari")
                                                    .tint(Color.accentColor)
                                            }
                                        }
                                        
                                        Section {
                                            Button {
                                                UIPasteboard.general.string = qrCode.text
                                            } label: {
                                                Label("Copy URL", systemImage: "doc.on.doc")
                                                    .tint(Color.accentColor)
                                            }
                                            
                                            Text(qrCode.text)
                                                .contextMenu {
                                                    Button {
                                                        UIPasteboard.general.string = qrCode.text
                                                    } label: {
                                                        Label("Copy URL", systemImage: "doc.on.doc")
                                                            .tint(Color.accentColor)
                                                    }
                                                }
                                        }
                                    }
                                    .navigationTitle(URL(string: qrCode.text)!.host!)
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("Done") {
                                                showingFullURLSheet = false
                                            }
                                            .tint(Color.accentColor)
                                        }
                                    }
                                }
                            }
                        } else {
                            HStack {
                                Text(qrCode.text)
                                    .bold()
                                    .lineLimit(1)
                                    .font(.largeTitle)
                                    .onTapGesture {
                                        showingAllTextSheet = true
                                    }
                                
                                Spacer()
                                
                                Button {
                                    showingAllTextSheet = true
                                } label: {
                                    HStack {
                                        Text("Show Full Text")
                                        
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
                                                UIPasteboard.general.string = qrCode.text
                                            } label: {
                                                Label("Copy Text", systemImage: "doc.on.doc")
                                                    .tint(Color.accentColor)
                                            }
                                            
                                            Text(qrCode.text)
                                                .contextMenu {
                                                    Button {
                                                        UIPasteboard.general.string = qrCode.text
                                                    } label: {
                                                        Label("Copy Text", systemImage: "doc.on.doc")
                                                            .tint(Color.accentColor)
                                                    }
                                                }
                                        } footer: {
                                            Text(qrCode.text.count == 1 ? "1 character" : "\(qrCode.text.count) characters")
                                        }
                                    }
                                    .navigationTitle(qrCode.text)
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("Done") {
                                                showingAllTextSheet = false
                                            }
                                            .tint(Color.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.horizontal)
                            .padding(.bottom, 5)
                        
                        if qrCode.wasScanned && !qrCode.scanLocation.isEmpty {
                            if monitor.isActive {
                                Button {
                                    withAnimation {
                                        showingLocation.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text("SCAN LOCATION")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Image(systemName: showingLocation ? "chevron.down" : "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                                .onAppear {
                                    let geocoder = CLGeocoder()
                                    let location = CLLocation(latitude: qrCode.scanLocation[0], longitude: qrCode.scanLocation[1])
                                    geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
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
                                    
                                    Map(coordinateRegion: .constant(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: qrCode.scanLocation[0], longitude: qrCode.scanLocation[1]), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))), interactionModes: [.all], annotationItems: annotation) {
                                        MapMarker(coordinate: $0.coordinate, tint: .accentColor)
                                    }
                                    .aspectRatio(16 / 9, contentMode: .fit)
                                    
                                    Text(locationName ?? "UNKNOWN LOCATION")
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)
                                }
                            } else {
                                Text("You're offline. Unable to show Apple Maps.")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                                .padding(.top, 5)
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
        .onAppear {
            Task {
                originalText = qrCode.text
                generateQRCode(from: qrCode.text)
            }
        }
        .navigationTitle(qrCode.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if qrCode.text.isValidURL() {
                    ShareLink(item: URL(string: qrCode.text)!) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    let qrCodeImage = Image(uiImage: qrCodeImage)
                    
                    ShareLink(item: qrCodeImage, preview: SharePreview(qrCode.text, image: qrCodeImage)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
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
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        if isEditing {
                            if let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
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
                    Text(isEditing ? "Done" : "Edit")
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
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        NavigationStack {
            HistoryDetailInfo(qrCode: QRCode(text: "https://duckduckgo.com/", scanLocation: [51.507222, -0.1275], wasScanned: true))
                .environmentObject(qrCodeStore)
        }
    }
}
