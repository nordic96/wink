package com.nordic.wink

import android.content.Context
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class PeerService(context: Context, flutterEngine: FlutterEngine) {
    private val connectionsClient = Nearby.getConnectionsClient(context)
    private val serviceId = "com.nordic.wink"

    private var username: String = "Unknown"
    private var eventsSink: EventChannel.EventSink? = null

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nordic.wink")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAdvertising" -> {
                        username = call.argument<String>("username") ?: "Unknown"
                        startAdvertising()
                        result.success(null)
                    }
                    "startDiscovery" -> {
                        startDiscovery()
                        result.success(null)
                    }
                    "stopAll" -> {
                        connectionsClient.stopAllEndpoints()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nordic.wink/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventsSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventsSink = null
                }
            })
    }

    private fun startAdvertising() {
        val advertisingOptions = AdvertisingOptions.Builder().setStrategy(Strategy.P2P_CLUSTER).build()
        connectionsClient.startAdvertising(username, serviceId, connectionLifecycleCallback, advertisingOptions)
    }

    private fun startDiscovery() {
        val discoveryOptions = DiscoveryOptions.Builder().setStrategy(Strategy.P2P_CLUSTER).build()
        connectionsClient.startDiscovery(serviceId, endpointDiscoveryCallback, discoveryOptions)
    }

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            connectionsClient.acceptConnection(endpointId, object : PayloadCallback() {
                override fun onPayloadReceived(endpointId: String, payload: Payload) {}
                override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {}
            })
        }
        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {}
        override fun onDisconnected(endpointId: String) {}
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            eventsSink?.success(info.endpointName)
        }
        override fun onEndpointLost(endpointId: String) {}
    }
}