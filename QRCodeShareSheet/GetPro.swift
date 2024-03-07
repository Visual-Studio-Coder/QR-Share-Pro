//
//  GetPro.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI
import StoreKit

struct StoreItem: View {
    @ObservedObject var storeKit: StoreKitManager
    @State var isPurchased: Bool = false
    var product: Product
    
    var body: some View {
        VStack {
            if isPurchased {
                Text(Image(systemName: "checkmark"))
                    .bold()
                    .padding(10)
            } else {
                Text(product.displayPrice)
                    .padding(10)
            }
        }
        .onChange(of: storeKit.purchasedPlan) { course in
            Task {
                isPurchased = (try? await storeKit.isPurchased(product)) ?? false
            }
        }
    }
}

struct GetPro: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var storeKit = StoreKitManager()
    
    var body: some View {
        VStack {
            Text("QR Share Pro")
                .fontWeight(.bold)
                .font(.title)
            
            Text("Which plan is right for you?")
                .multilineTextAlignment(.center)
            
            VStack {
                TabView {
                    ForEach(storeKit.storeProducts) { product in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                StoreItem(storeKit: storeKit, product: product)
                            }
                            
                            Text("What's included:")
                                .bold()
                            
                            Section {
                                Label("Lifetime purchase", systemImage: "checkmark")
                                Label("Custom watermark", systemImage: "checkmark")
                                Label("Custom QR code color", systemImage: "checkmark")
                                Label("Custom branding logo", systemImage: "checkmark")
                                Label("Family Sharing, up to 6 people", systemImage: "checkmark")
                            }
                            
                            Button {
                                Task {
                                    try await storeKit.purchase(product)
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("**BUY - $1.99**", systemImage: "cart.fill")
                                    Spacer()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.white)
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("QR Share Pro Max")
                            Spacer()
                            Text("Coming soon")
                        }
                        
                        Text("What's included:")
                            .bold()
                        
                        Section {
                            Label("Lifetime purchase", systemImage: "checkmark")
                            Label("Custom watermark", systemImage: "checkmark")
                            Label("Custom QR code color", systemImage: "checkmark")
                            Label("Custom branding logo", systemImage: "checkmark")
                            Label("Family Sharing, up to 6 people", systemImage: "checkmark")
                        }
                        
                        Button {
                        } label: {
                            HStack {
                                Spacer()
                                Label("**COMING SOON**", systemImage: "cart.fill")
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
            .padding(.horizontal)
            
            Button("Already have QR Share Pro?", action: {
                Task {
                    try? await AppStore.sync()
                }
            })
        }
        .navigationBarTitle("QR Share Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
            }
        }
    }
}

#Preview {
    GetPro()
}
