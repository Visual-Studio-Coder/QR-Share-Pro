//
//  QRControl.swift
//  QRControl
//
//  Created by Vaibhav Satishkumar on 3/19/25.
//

import WidgetKit
import SwiftUI

// TimelineProvider with minimal implementation
struct Provider: TimelineProvider {
    struct Entry: TimelineEntry { let date = Date() }
    
    func placeholder(in context: Context) -> Entry { Entry() }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
        completion(Entry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        completion(Timeline(entries: [Entry()], policy: .atEnd))
    }
}

// Main Widget View
struct QRControlView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title at top-left
            HStack {
                Text("QR Share Pro")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Image("QRSharePro")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20.0))
            }
            
            Spacer()
            // Three buttons side by side
            HStack(spacing: 8) {
                // Scan Button
                Link(destination: URL(string: "qrsharepro://scan")!) {
                    VStack(spacing: 4) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18)) // Smaller icon to fit horizontal layout
                            .foregroundColor(.white)
                        Text("Scan")
                            .font(.caption2) // Smaller font to fit
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                
                // New Button
                Link(destination: URL(string: "qrsharepro://new")!) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        Text("New")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
                            )
                    )
                }

                // History Button
                Link(destination: URL(string: "qrsharepro://history")!) {
                    VStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        Text("History")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(10)
        .containerBackground(.background, for: .widget)
    }
}

struct QRControl: Widget {
    let kind: String = "QRControl"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { _ in
            QRControlView()
        }
        .configurationDisplayName("QR Share Pro")
        .description("Quick access to create, scan, and access QR code history.")
        .supportedFamilies([.systemMedium])
    }
}

// Preview Provider
struct QRControl_Previews: PreviewProvider {
    static var previews: some View {
        QRControlView()
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .preferredColorScheme(.dark)
    }
}
