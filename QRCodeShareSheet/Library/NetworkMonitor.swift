//
//  NetworkMonitor.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/21/24.
//

import SwiftUI
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "QR Share - Network Monitor")
    
    var isActive = false
    var isExpensive = false
    var isConstrained = false
    
    var connectionType = NWInterface.InterfaceType.other
    
    init() {
        monitor.pathUpdateHandler = { path in
            self.isActive = path.status == .satisfied
            self.isExpensive = path.isExpensive
            self.isConstrained = path.isConstrained
            
            let connectionTypes: [NWInterface.InterfaceType] = [.cellular, .wifi, .wiredEthernet]
            self.connectionType = connectionTypes.first(where: path.usesInterfaceType) ?? .other
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        monitor.start(queue: queue)
    }
}
