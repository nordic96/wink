package com.nordic.wink

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import androidx.annotation.RequiresPermission
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

@SuppressLint("MissingPermission")
class BlePeripheral(
    private val context: Context,
    messenger: BinaryMessenger
) {
    private val channel = MethodChannel(messenger, "com.nordic.wink/ble_peripheral")

    private val serviceUUID = java.util.UUID.fromString(context.getString(R.string.service_uuid))
    private val charUUID    = java.util.UUID.fromString("00001234-1234-1234-1234-123456789012")

    private val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val btAdapter: BluetoothAdapter? = btManager.adapter
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = btAdapter?.bluetoothLeAdvertiser

    private var usernameValue: ByteArray = "Unknown".toByteArray()
    private var advertiseCallback: AdvertiseCallback? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startPeripheral" -> {
                    val name = (call.argument<String>("username") ?: "Unknown").trim()
                    startGatt(name)
                    startAdvertising(name)
                    result.success(null)
                }
                "stopPeripheral" -> {
                    stopAdvertising()
                    stopGatt()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    private fun startGatt(name: String) {
        usernameValue = name.toByteArray()
        stopGatt()

        gattServer = btManager.openGattServer(context, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(
                device: BluetoothDevice?,
                status: Int,
                newState: Int
            ) {
                Log.d("BlePeripheral", "GATT State: $newState status: $status")
            }

            @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
            override fun onCharacteristicReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic
            ) {
                if (characteristic.uuid == charUUID) {
                    val value = if (offset == 0) usernameValue else byteArrayOf()
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                } else {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                }
            }
        })

        val service = BluetoothGattService(serviceUUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val characteristic = BluetoothGattCharacteristic(
            charUUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        service.addCharacteristic(characteristic)
        gattServer?.addService(service)
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    private fun stopGatt() {
        try { gattServer?.close() } catch (_: Exception) {}
        gattServer = null
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising(name: String) {
        stopAdvertising()

        try { btAdapter?.name = name.take(20) } catch (_: Exception) {}

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .build()

        val pUuid = ParcelUuid(serviceUUID)
        val serviceData = "Data"
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(pUuid)
            .build()

        if (advertiser == null) {
            advertiser = btAdapter?.bluetoothLeAdvertiser
        }

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                Log.d("BlePeripheral", "Advertising started (Android)")
                super.onStartSuccess(settingsInEffect)
            }
            override fun onStartFailure(errorCode: Int) {
                Log.e("BlePeripheral", "Advertising failed: $errorCode")
                super.onStartFailure(errorCode)
            }
        }
        Log.d("BlePeripheral", data.toString());
        advertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    @SuppressLint("MissingPermission")
    private fun stopAdvertising() {
        try {
            advertiseCallback?.let { advertiser?.stopAdvertising(it) }
        } catch (_: Exception) {}
        advertiseCallback = null
    }
}
