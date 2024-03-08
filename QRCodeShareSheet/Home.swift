//
//  Home.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI

struct Home: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @State private var showingSettingsSheet = false
    @State private var showingGetProSheet = false
    
    @State private var toggleHaptics = true
    
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
                    ScrollView {
                        VStack {
                            NewQRCode()
                                .environmentObject(qrCodeStore)
                                .onTapGesture {
                                    // Dismiss keyboard
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            
//                            Button {
//                            } label: {
//                                HStack {
//                                    Spacer()
//                                    Text("Get Pro →")
//                                        .fontWeight(.bold)
//                                    Spacer()
//                                }
//                            }
//                            .padding()
//                            .background(Color(UIColor.systemGray6))
//                            .cornerRadius(10)
                        }
                    }
                }
                .navigationTitle("New QR Code")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingGetProSheet = true
                        } label: {
                            Label("Upgrade", systemImage: "crown.fill")
                        }
                    }
                    
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
                            Section {
                                NavigationLink {
                                    GetPro()
                                } label: {
                                    Label("**QR Share Pro** - $1.99", systemImage: "crown.fill")
                                }
                            }
                            
                            Section {
                                NavigationLink {
                                    AppIcons()
                                } label: {
                                    Label("App Theme", systemImage: "paintbrush.pointed")
                                }
                                
                                NavigationLink {
                                    AppIcons()
                                } label: {
                                    Label("App Icons", systemImage: "square.grid.3x3.square")
                                }
                            } header: {
                                Text("Theme & App Icon")
                            }
                            
                            Section {
                                Toggle(isOn: $toggleHaptics) {
                                    Label("Play Haptics", systemImage: "wave.3.right")
                                }
                            } header: {
                                Text("General")
                            }
                            
                            Section {
                                HStack {
                                    Label("QR Code Color", systemImage: "paintbrush")
                                    Spacer()
                                    Label("Pro Required", systemImage: "lock")
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack {
                                    Label("QR Code Watermark", systemImage: "water.waves")
                                    Spacer()
                                    Label("Pro Required", systemImage: "lock")
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack {
                                    Label("Branding Logo", systemImage: "briefcase")
                                    Spacer()
                                    Label("Pro Required", systemImage: "lock")
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                Text("Pro Settings")
                            }
                            
                            Section {
                                HStack {
                                    Label("QR Share", systemImage: "qrcode")
                                    Spacer()
                                    Text("Version 0.0.1")
                                        .foregroundStyle(.secondary)
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
                                Text("QR Share")
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
                    }
                }
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        Home()
            .environmentObject(qrCodeStore)
    }
}
