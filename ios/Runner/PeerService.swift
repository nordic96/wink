//
//  PeerService.swift
//  Runner
//
//  Created by Gi Hun Ko on 13/8/25.
//

import Foundation
import MultipeerConnectivity
import Flutter

class PeerService: NSObject, FlutterPlugin, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {

    // Multipeer objects
    private var peerID: MCPeerID!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var session: MCSession!
    
    // Flutter event channel sink
    private var events: FlutterEventSink?
    
    // Service type must be:
    // - lowercase letters/numbers only
    // - ≤ 15 chars
    // - identical for advertiser & browser
    private let serviceType: String = "winkpeer"

    // MARK: - Flutter Plugin Registration
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.nordic.wink", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.nordic.wink/events", binaryMessenger: registrar.messenger())
        let instance = PeerService()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - Init
    override init() {
        super.init()
        // Use device name as default peer ID so it's always set
        peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    }

    // MARK: - Handle Flutter Calls
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            
        case "startAdvertising":
            startAdvertising(username: (call.arguments as? [String: Any])?["username"] as? String)
            result(nil)
            
        case "startDiscovery":
            startDiscovery()
            result(nil)
            
        case "stopAll":
            stopAll()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Core Functions
    private func startAdvertising(username: String?) {
        stopAdvertising() // ensure no duplicates

        // Optionally use custom username if provided
        if let uname = username, !uname.isEmpty {
            peerID = MCPeerID(displayName: uname)
            session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        }
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        print("[PeerService] Advertising started with serviceType: \(serviceType)")
    }

    private func startDiscovery() {
        stopBrowsing() // ensure no duplicates
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        print("[PeerService] Browsing started with serviceType: \(serviceType)")
    }

    private func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    private func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    private func stopAll() {
        stopAdvertising()
        stopBrowsing()
    }

    // MARK: - Advertiser Delegate
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("[PeerService] Received invitation from \(peerID.displayName)")
        invitationHandler(true, session)
    }

    // MARK: - Browser Delegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        print("[PeerService] Found peer: \(peerID.displayName)")
        events?(peerID.displayName) // send peer name to Flutter
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[PeerService] Lost peer: \(peerID.displayName)")
    }
}

// MARK: - Flutter Stream Handler
extension PeerService: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.events = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.events = nil
        return nil
    }
}
