//
//  MyCodes.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI

struct MyCodes: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @State private var showingSettingsSheet = false
    @State private var showingGetProSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    NewQRCode()
                        .environmentObject(qrCodeStore)
                    
                    Divider()
                    
                    VStack {
                        LinearGradient(colors: [.green, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        
                        Text("**QR Share Pro**")
                            .font(.title2)
                        
                        Text("Unlimited QR code customizations for just $1.99.")
                            .multilineTextAlignment(.center)
                        
                        Button {
                            showingGetProSheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Get Pro →")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        .sheet(isPresented: $showingGetProSheet) {
                            NavigationView {
                                GetPro()
                            }
                        }
                    }
                }
                .padding()
                .onTapGesture {
                    // Dismiss keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("My Codes")
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
                            HStack {
                                Label("QR Share", systemImage: "qrcode")
                                Spacer()
                                Text("Version 0.0.1")
                                    .foregroundStyle(.secondary)
                            }
                        } header: {
                            Text("QR Share")
                        }
                        
                        Section {
                            HStack {
                                Label("Custom Color", systemImage: "paintbrush")
                                Spacer()
                                Label("Pro Required", systemImage: "lock")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Label("Watermark", systemImage: "water.waves")
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
                            
                            NavigationLink {
                                GetPro()
                            } label: {
                                Label("Get **QR Share Pro** for $1.99", systemImage: "crown.fill")
                            }
                        } header: {
                            Text("Pro Settings")
                        }
                        
                        Section {
                            Text("Refer a friend who buys **QR Share Pro**, and you'll get it free!")
                            
                            Button {} label: {
                                Text("Share App")
                            }
                        } header: {
                            Text("Share App")
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
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        MyCodes()
            .environmentObject(qrCodeStore)
    }
}
