//
//  QRControl.swift
//  QRControl
//
//  Created by Vaibhav Satishkumar on 3/19/25.
//

import WidgetKit
import SwiftUI

// Note: WidgetKit requires a TimelineProvider with TimelineEntry
// This is the absolute minimum implementation required
struct Provider: TimelineProvider {
    struct Entry: TimelineEntry { let date = Date() }
    
    func placeholder(in context: Context) -> Entry { Entry() }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) { completion(Entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        completion(Timeline(entries: [Entry()], policy: .never))
    }
}

struct QRControl: Widget {
    let kind: String = "QRControl"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { _ in
            // Simple QR code UI
            VStack {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Scan QR Code")
                    .font(.caption)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("QR Scanner")
        .description("Quick access to scan QR codes")
        .supportedFamilies([.systemSmall])
    }
}
