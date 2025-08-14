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
    
    private var service: CBMutableService!
    private var characteristic: CBMutableCharacteristic!
    
    private var pendingStartUsername: String?
    
    private let serviceUUID = CBUUID(string: "96AB")
    private let charUUID    = CBUUID(string: "00001234-1234-1234-1234-123456789012")
    
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
    
    private func setupService(username: String) {
        characteristic = CBMutableCharacteristic(
            type: charUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )

        service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        
        peripheralManager.add(service)
        print("[ios] service added to peripheralManager", service!)
    }
    
    private func startPeripheral(username: String) {
        if peripheralManager.isAdvertising {
            print("[startPeripheral] already advertising... stopping services")
            stopPeripheral()
        }
        self.username = username
        
        // If not powered on, defer until the state updates
        if peripheralManager.state != .poweredOn {
            print("peripheralManager state", peripheralManager.state.rawValue)
            pendingStartUsername = username
            return
        }

        let shortName = String(username.prefix(20))
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: shortName
        ])
        print("ios started advertising... isAdvertising: ", peripheralManager.isAdvertising)
    }
    
    private func stopPeripheral() {
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        pendingStartUsername = nil
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Bluetooth powered on: username: ", self.username)
            setupService(username: self.username)
            //startPeripheral(username: self.username)
        default:
            // Stop if we lose power or are restricted
            stopPeripheral()
        }
    }
}
