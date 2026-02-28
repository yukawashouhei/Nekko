//
//  NetworkMonitor.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import Foundation
import Network

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true
    private(set) var connectionType: ConnectionType = .unknown
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.perksh.nekko.networkmonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = Self.determineConnectionType(path)
            }
        }
        monitor.start(queue: queue)
    }

    private static func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }
}
