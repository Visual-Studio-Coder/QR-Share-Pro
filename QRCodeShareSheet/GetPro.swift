//
//  GetPro.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI

struct GetPro: View {
    var body: some View {
        VStack {
            Text("QR Share Pro")
                .fontWeight(.bold)
                .font(.title)
            
            Text("Choose the plan that's right for you.")
            
            VStack {
                Button {} label: {
                    VStack(alignment: .leading) {
                        Text("Pro")
                            .font(.headline)
                        
                        Text("$1.99/year")
                            .font(.subheadline)
                        
                        Text("In-depth analytics, and 600 premium QR codes every month.")
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button {} label: {
                    VStack(alignment: .leading) {
                        Text("Pro Max")
                            .font(.headline)
                        Text("$9.99/year")
                            .font(.subheadline)
                        
                        Text("Even more detailed analytics, with unlimited premium QR codes.")
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    GetPro()
}
