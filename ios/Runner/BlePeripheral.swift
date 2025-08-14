//
//  BlePeripheral.swift
//  Runner
//
//  Created by Gi Hun Ko on 13/8/25.
//
import Foundation
import CoreBluetooth
import Flutter

class BlePeripheral: NSObject, FlutterPlugin, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private var username: String = "Unknown"
    
    private var service: CBMutableService?
    private var characteristic: CBMutableCharacteristic?
    
    private var pendingStartUsername: String?
    
    private let serviceUUID = CBUUID(string: "180a")
    private let charUUID    = CBUUID(string: "abcd")
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.nordic.wink/ble_peripheral", binaryMessenger: registrar.messenger())
        let instance = BlePeripheral()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startPeripheral":
            if let args = call.arguments as? [String: Any],
               let name = args["username"] as? String {
                startPeripheral(username: name)
            } else {
                startPeripheral(username: "Unknown")
            }
            result(nil)
        case "stopPeripheral":
            stopPeripheral()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startPeripheral(username: String) {
        self.username = username

        // If not powered on, defer until the state updates
        if peripheralManager.state != .poweredOn {
            pendingStartUsername = username
            return
        }

        // Rebuild services each time (ensures username value is up to date)
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()

        characteristic = CBMutableCharacteristic(
            type: charUUID,
            properties: [.read],
            value: username.data(using: .utf8),   // read-only static value
            permissions: [.readable]
        )

        service = CBMutableService(type: serviceUUID, primary: true)
        service?.characteristics = [characteristic!]

        peripheralManager.add(service!)
        let shortName = String(username.prefix(20))
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: shortName
        ])
    }
    
    private func stopPeripheral() {
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        pendingStartUsername = nil
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if let name = pendingStartUsername {
                pendingStartUsername = nil
                startPeripheral(username: name)
            }
        default:
            // Stop if we lose power or are restricted
            stopPeripheral()
        }
    }
}
