import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

// A unique Service UUID for our application.
// You can generate your own using an online UUID generator.
final Uuid serviceUuid = Uuid.parse("12345678-1234-1234-1234-123456789012");

class BleService with ChangeNotifier {
  //Custom Added Peripheral Channel residing natively
  final _peripheralChannel = const MethodChannel(
    "com.nordic.wink/ble_peripheral",
  );

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<BleStatus>? _statusSubscription;
  //StreamSubscription? _advertisingSubscription;

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
          withServices: [serviceUuid],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) {
            final knownDeviceIndex = _discoveredDevices.toList().indexWhere(
              (d) => d.id == device.id,
            );
            if (knownDeviceIndex < 0) {
              _discoveredDevices.add(device);
              notifyListeners();
            }
          },
          onError: (e) {
            print("Scan Error: $e");
          },
        );
    _isScanning = true;
    notifyListeners();
    print("Started Scanning");
  }

  void stopScan() {
    _scanSubscription?.cancel();
    discoveredDevices.clear();
    _isScanning = false;
    notifyListeners();
    print("Stopped Scanning");
  }

  Future<void> startAdvertising() async {
    print("startAdvertising(): isAdvertising: $_isAdvertising");
    if (_isAdvertising) return;
    try {
      await _peripheralChannel.invokeMethod("startPeripheral", {
        "username": "testusername",
      });
    } catch (e) {
      print("Error while invoking startPeripheral via channeling: $e");
    }
    _isAdvertising = true;
    notifyListeners();
    print("Started Advertising...");
  }

  Future<void> stopAdvertising() async {
    print("stopAdvertising(): isAdvertising: $_isAdvertising");
    try {
      await _peripheralChannel.invokeMethod("stopPeripheral");
    } catch (e) {
      print("Error while stopping advertising via channel: $e");
    }
    _isAdvertising = false;
    notifyListeners();
    print("Stopped Advertising...");
  }
}
