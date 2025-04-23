/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !os(watchOS)

import Foundation
import Network
import Reachability

public class NetworkMonitor: NetworkMonitorProtocol {
    let monitor: NetworkMonitorProtocol
    
    public init() throws {
        if #available(macOS 10.14, watchOS 5, *) {
            monitor = try NWPathNetworkMonitor()
        } else {
            monitor = try ReachabilityNetworkMonitor()
        }
    }
    
    public func getConnection() -> Connection {
        monitor.getConnection()
    }
}

public extension NetworkMonitor {
    @available(macOS 10.14, watchOS 5, *)
    class NWPathNetworkMonitor: NetworkMonitorProtocol {
        let monitor = NWPathMonitor()
        var connection: Connection = .unavailable
        let monitorQueue = DispatchQueue(label: "OTel-Network-Monitor")
        let lock = NSLock()

        deinit {
            monitor.cancel()
        }

        public init() throws {
            let pathHandler = { (path: NWPath) in
                let availableInterfaces = path.availableInterfaces
                let wifiInterface = self.getWifiInterface(interfaces: availableInterfaces)
                let cellInterface = self.getCellInterface(interfaces: availableInterfaces)
                var availableInterface: Connection = .unavailable
                if cellInterface != nil {
                    availableInterface = .cellular
                }
                if wifiInterface != nil {
                    availableInterface = .wifi
                }
                self.lock.lock()
                switch path.status {
                case .requiresConnection, .satisfied:
                    self.connection = availableInterface
                case .unsatisfied:
                    self.connection = .unavailable
                @unknown default:
                    fatalError()
                }
                self.lock.unlock()

            }
            monitor.pathUpdateHandler = pathHandler
            monitor.start(queue: monitorQueue)
        }
        public func getConnection() -> Connection {
            lock.lock()
            defer {
                lock.unlock()
            }
            return connection

        }

        func getCellInterface(interfaces: [NWInterface]) -> NWInterface? {
            var foundInterface: NWInterface?
            interfaces.forEach { interface in
                if interface.type == .cellular {
                    foundInterface = interface
                }
            }
            return foundInterface
        }
        func getWifiInterface(interfaces: [NWInterface]) -> NWInterface? {
            var foundInterface: NWInterface?
            interfaces.forEach { interface in
                if interface.type == .wifi {
                    foundInterface = interface
                }
            }
            return foundInterface
        }
    }

    class ReachabilityNetworkMonitor: NetworkMonitorProtocol {
        var reachability: Reachability

        public init() throws {
            reachability = try Reachability()
            try reachability.startNotifier()
        }

        deinit {
            reachability.stopNotifier()
        }

        public func getConnection() -> Connection {
            switch reachability.connection {
            case .wifi:
                return .wifi
            case .cellular:
                return .cellular
            case .unavailable, .none:
                return .unavailable
            }
        }
    }
}

#endif
