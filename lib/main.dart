import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

final _serviceUuid = Uuid.parse("180a");
final _charUuid = Uuid.parse("abcd");

void main() {
  runApp(const MaterialApp(home: HomePage()));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ble = FlutterReactiveBle();
  final _peripheralChannel = const MethodChannel(
    "com.nordic.wink/ble_peripheral",
  );
  final _usernameController = TextEditingController(text: "WinkUser");

  bool _isAdvertising = false;
  bool _isScanning = false;
  final List<_Peer> _peers = [];
  StreamSubscription<DiscoveredDevice>? _scanSub;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Ask for location (pre-Android 12), Bluetooth (Android 12+), Bluetooth on iOS auto-prompts
    await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _startPeripheral() async {
    await _peripheralChannel.invokeMethod("startPeripheral", {
      "username": _usernameController.text.trim(),
    });
    setState(() => _isAdvertising = true);
  }

  Future<void> _stopPeripheral() async {
    await _peripheralChannel.invokeMethod("stopPeripheral");
    setState(() => _isAdvertising = false);
  }

  void _startScan() {
    if (_isScanning) return;
    setState(() {
      _peers.clear();
      _isScanning = true;
    });

    _scanSub = _ble
        .scanForDevices(
          withServices: [_serviceUuid],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) async {
            if (_peers.any((p) => p.id == device.id)) return;

            // Immediately try to connect and read username characteristic
            try {
              final connection = _ble.connectToDevice(id: device.id);
              final sub = connection.listen((c) async {
                if (c.connectionState == DeviceConnectionState.connected) {
                  final qc = QualifiedCharacteristic(
                    serviceId: _serviceUuid,
                    characteristicId: _charUuid,
                    deviceId: device.id,
                  );
                  String username = device.name.isNotEmpty
                      ? device.name
                      : device.id;
                  try {
                    final value = await _ble.readCharacteristic(qc);
                    if (value.isNotEmpty) {
                      username = utf8.decode(value, allowMalformed: true);
                    }
                  } catch (_) {}
                  setState(
                    () => _peers.add(_Peer(id: device.id, name: username)),
                  );
                  _stopScan();
                  // sub.cancel();
                  // _ble.disconnectDevice(id: device.id);
                }
              });
            } catch (_) {}
          },
          onError: (e) {
            setState(() => _isScanning = false);
          },
        );
  }

  void _stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    setState(() => _isScanning = false);
    // flutter_reactive_ble stops scan by cancelling subscription
  }

  @override
  void dispose() {
    _stopScan();
    _stopPeripheral();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wink BLE Nearby")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Your username"),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAdvertising
                        ? _stopPeripheral
                        : _startPeripheral,
                    child: Text(
                      _isAdvertising ? "Stop Advertising" : "Start Advertising",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning ? _stopScan : _startScan,
                    child: Text(
                      _isScanning ? "Stop Scanning" : "Start Scanning",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Nearby peers",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _peers.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(_peers[i].name),
                  subtitle: Text(_peers[i].id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Peer {
  final String id;
  final String name;
  _Peer({required this.id, required this.name});
}
