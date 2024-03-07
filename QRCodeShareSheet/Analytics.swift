//
//  Analytics.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/6/24.
//

import SwiftUI

struct Analytics: View {
    var body: some View {
        VStack {
            VStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .padding(.bottom, 10)
                
                Text("No Analytics Yet")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                Text("temporary placeholder, to be integrated into **History** in v2")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
                    .padding(.bottom, 30)
                
                Button {
                } label: {
                    Label("**Get Pro →**", systemImage: "crown.fill")
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .navigationTitle("Analytics")
    }
}

#Preview {
    Analytics()
}
