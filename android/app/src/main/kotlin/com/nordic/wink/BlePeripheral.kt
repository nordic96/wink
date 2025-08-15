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
    private val TAG = "BlePeripheral"

    private val serviceUUID = java.util.UUID.fromString(context.getString(R.string.service_uuid))
    private val pingCharUUID    = java.util.UUID.fromString(context.getString(R.string.ping_char_uuid))

    private val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val btAdapter: BluetoothAdapter? = btManager.adapter
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = btAdapter?.bluetoothLeAdvertiser

    private var usernameValue: ByteArray = "Unknown".toByteArray()
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            Log.d(TAG, "Advertising started (Android)")
            super.onStartSuccess(settingsInEffect)
        }
        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "Advertising failed: $errorCode")
            super.onStartFailure(errorCode)
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startPeripheral" -> {
                    val name = (call.argument<String>("username") ?: "Unknown").trim()
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

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(
            device: BluetoothDevice?,
            status: Int,
            newState: Int
        ) {
            super.onConnectionStateChange(device, status, newState)
            Log.d(TAG, "GATT State: $newState status: $status")
        }

        @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            if (characteristic.uuid == pingCharUUID) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, "Pong".toByteArray())
                Log.d(TAG, "Read request from ${device.address}")
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            if (characteristic?.uuid == pingCharUUID) {
                val message = value?.toString(Charsets.UTF_8)
                Log.d(TAG, "Received write from ${device?.address}: $message")
                characteristic.value = "Pong from Android".toByteArray()
                gattServer?.notifyCharacteristicChanged(device, characteristic, false)
            }

            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }
        }
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    private fun startGatt(name: String) {
        usernameValue = name.toByteArray()

        gattServer = btManager.openGattServer(context, gattServerCallback)

        val service = BluetoothGattService(serviceUUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val characteristic = BluetoothGattCharacteristic(
            pingCharUUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_WRITE or BluetoothGattCharacteristic.PERMISSION_READ
        )
        service.addCharacteristic(characteristic)
        gattServer?.addService(service)
        Log.d(TAG, "GATT Server started with characteristics...")
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
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(pUuid)
            .build()
        advertiser?.startAdvertising(settings, data, advertiseCallback)
        Log.d(TAG, data.toString())

        startGatt(name)
    }

    @SuppressLint("MissingPermission")
    private fun stopAdvertising() {
        advertiser?.stopAdvertising(advertiseCallback)
        gattServer?.close()
        Log.d(TAG, "Stopped Advertising")
    }
}
