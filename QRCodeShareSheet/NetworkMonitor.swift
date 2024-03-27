//
//  NetworkMonitor.swift
//  QRCodeShareSheet
//

//

import SwiftUI
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "QR Share - Network Monitor")
    
    var isActive = false
    
    init() {
        monitor.pathUpdateHandler = { path in
            self.isActive = path.status == .satisfied
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        monitor.start(queue: queue)
    }
}
