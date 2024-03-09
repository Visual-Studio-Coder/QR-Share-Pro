//
//  Home.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI

struct Home: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @EnvironmentObject var storeKit: StoreKitManager
    
    @State private var showingSettingsSheet = false
    @State private var showingGetProSheet = false
    
    @State private var toggleHaptics = true
    @State private var boughtPro = true
    
    private var allThemes = ["Orange", "Yellow"]
    
    //    @State private var animateGradient = false
    
    var body: some View {
        NavigationView {
            ZStack {
                //                RadialGradient(colors: [.gray, .white], center: .center, startRadius: animateGradient ? 400 : 200, endRadius: animateGradient ? 20 : 40)
                ////                    .frame(height: UIScreen.main.bounds.height * 0.2)
                //                    .ignoresSafeArea()
                //                    .onAppear {
                //                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                //                            animateGradient.toggle()
                //                        }
                //                    }
                
                VStack {
                    NewQRCode(boughtPro: boughtPro)
                        .environmentObject(qrCodeStore)
                        .onTapGesture {
                            // Dismiss keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                }
                .navigationTitle("New QR Code")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettingsSheet = true
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                    }
                }
                .sheet(isPresented: $showingSettingsSheet) {
                    NavigationView {
                        List {
                            if !boughtPro {
                                Section {
                                    NavigationLink {
                                        GetPro()
                                            .environmentObject(storeKit)
                                    } label: {
                                        Label("**QR Share Pro** - $1.99", systemImage: "crown.fill")
                                    }
                                }
                            }
                            
                            Section {
                                NavigationLink {
                                    List {
                                        ForEach(allThemes, id: \.self) { i in
                                            Button {
                                            } label: {
                                                HStack {
                                                    //                                                    //                                                    Image(systemName: i.iconURL == "AppIcon" ? "checkmark.circle.fill" : "circle")
                                                    //                                                    //                                                        .font(.title2)
                                                    Text(i)
                                                }
                                            }
                                        }
                                    }
                                    .navigationTitle("App Icons")
                                    .navigationBarTitleDisplayMode(.inline)
                                } label: {
                                    HStack {
                                        Label("App Theme", systemImage: "paintbrush.pointed")
                                        Spacer()
                                        Text("Blue")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                NavigationLink {
                                    AppIcons()
                                } label: {
                                    HStack {
                                        Label("App Icon", systemImage: "square.grid.3x3.square")
                                        Spacer()
                                        Text("Default")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } header: {
                                Text("Theme & App Icon")
                            }
                            
                            Section {
                                Toggle(isOn: $toggleHaptics) {
                                    Label("Play Haptics", systemImage: "wave.3.right")
                                }
                                
                                Toggle(isOn: $toggleHaptics) {
                                    Label("Show Website Favicons", systemImage: "photo.circle")
                                }
                            } header: {
                                Text("General")
                            }
                            
                            Section {
                                HStack {
                                    Label(boughtPro ? "QR Share Pro" : "QR Share", systemImage: "qrcode")
                                    Spacer()
                                    Text("Version 0.0.1")
                                        .foregroundStyle(.secondary)
                                }
                                
                                Toggle(isOn: $boughtPro) {
                                    Label("DEBUG - Enable Pro", systemImage: "hammer")
                                }
                                
                                HStack {
                                    Label("Rate App", systemImage: "star")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack {
                                    Label("Share App", systemImage: "square.and.arrow.up")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                Text(boughtPro ? "QR Share Pro" : "QR Share")
                            } footer: {
                                Text("© Copyright 2024 The [X] Company. All Rights Reserved.")
                            }
                        }
                        .navigationBarTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showingSettingsSheet = false
                                } label: {
                                    Text("Done")
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingGetProSheet) {
                    NavigationView {
                        GetPro()
                            .environmentObject(storeKit)
                    }
                }
            }
        }
        .onChange(of: storeKit.purchasedPlan) { course in
            Task {
                boughtPro = (try? await storeKit.isPurchased(storeKit.storeProducts[0])) ?? false
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        @StateObject var storeKit = StoreKitManager()
        
        Home()
            .environmentObject(qrCodeStore)
            .environmentObject(storeKit)
    }
}
