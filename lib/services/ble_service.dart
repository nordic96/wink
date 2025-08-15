import 'dart:async';

import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' hide Logger;
import 'package:permission_handler/permission_handler.dart';

// A unique Service UUID for our application.
final Uuid serviceUuid = Uuid.parse(dotenv.get("SERVICE_UUID"));
final Uuid pingUuid = Uuid.parse(dotenv.get("PING_CHAR_UUID"));
final String methodChannelName = dotenv.env["METHOD_CHANNEL_NAME"]!;

class BleService with ChangeNotifier {
  final Logger logger = Logger();
  final _peripheralChannel = MethodChannel(methodChannelName);

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<BleStatus>? _statusSubscription;

  final Set<DiscoveredDevice> _discoveredDevices = {};
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices.toList();

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  BleStatus _scannerStatus = BleStatus.unknown;
  BleStatus get scannerStatus => _scannerStatus;

  BleService() {
    _statusSubscription = _ble.statusStream.listen((status) {
      _scannerStatus = status;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _statusSubscription?.cancel();
    stopAdvertising();
    //_advertisingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    await _requestPermissions();

    _discoveredDevices.clear();
    notifyListeners();

    _scanSubscription = _ble
        .scanForDevices(
          // TODO: comment/uncomment to test scanning functionality
          //withServices: [serviceUuid],
          withServices: [],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) {
            final knownDeviceIndex = _discoveredDevices.toList().indexWhere(
              (d) => d.id == device.id,
            );
            if (knownDeviceIndex < 0) {
              _discoveredDevices.add(device);
              // TODO: comment/uncomment to test ping function
              connectAndPing(device.id);
              notifyListeners();
            }
          },
          onError: (e) {
            logger.e("Scan Error: $e");
          },
        );
    _isScanning = true;
    notifyListeners();
    logger.i("Started Scanning");
  }

  void stopScan() {
    _scanSubscription?.cancel();
    discoveredDevices.clear();
    _isScanning = false;
    notifyListeners();
    logger.i("Stopped Scanning");
  }

  Future<void> startAdvertising() async {
    if (_isAdvertising) return;
    try {
      await _peripheralChannel.invokeMethod("startPeripheral", {
        "username": "testusername",
      });
    } catch (e) {
      logger.e("Error while invoking startPeripheral via channeling: $e");
    }
    _isAdvertising = true;
    notifyListeners();
    logger.i("Started Advertising...");
  }

  Future<void> stopAdvertising() async {
    try {
      await _peripheralChannel.invokeMethod("stopPeripheral");
    } catch (e) {
      logger.e("Error while stopping advertising via channel: $e");
    }
    _isAdvertising = false;
    notifyListeners();
    logger.i(
      "Stopped Advertising... Scanned total ${_discoveredDevices.length} devices..",
    );
  }

  Future<void> connectAndPing(String deviceId) async {
    final connectionStream = _ble.connectToDevice(id: deviceId);

    await for (final update in connectionStream) {
      if (update.connectionState == DeviceConnectionState.connected) {
        logger.d("✅ Connected to $deviceId");

        await _ble.discoverAllServices(deviceId);
        final services = await _ble.getDiscoveredServices(deviceId);

        final service = services.firstWhere(
          (s) => s.id == serviceUuid,
          orElse: () => throw Exception("Service not found"),
        );

        final characteristic = service.characteristics.firstWhere(
          (c) => c.id == pingUuid,
          orElse: () => throw Exception("Ping characteristic not found"),
        );
        logger.d(characteristic);

        final qualifiedChar = QualifiedCharacteristic(
          characteristicId: pingUuid,
          serviceId: serviceUuid,
          deviceId: deviceId,
        );

        final message = "PING-${DateTime.now().millisecondsSinceEpoch}";
        await _ble.writeCharacteristicWithoutResponse(
          qualifiedChar,
          value: message.codeUnits,
        );
        notifyListeners();
        logger.d("📤 Sent ping: $message");
        break;
      }
    }
  }
}
