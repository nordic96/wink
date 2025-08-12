// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:uuid/uuid.dart';

import 'ble_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleService _bleService = BleService();
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  String _currentUserId = const Uuid().v4();
  bool _isAdvertising = false;
  bool _isScanning = false;
  final Map<String, ScanResult> _nearbyDevices = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initBle();
  }

  Future<void> _initBle() async {
    setState(() {
      _isLoading = true;
    });

    _blePeripheral.isAdvertising.then((isAdvertising) {
      setState(() {
        _isAdvertising = isAdvertising;
      });
    });

    // Request permissions. The plugin now has dedicated functions for this.
    if (!await FlutterBluePlus.isSupported) {
      await _bleService.requestPermissions();
    }

    await _bleService.initialiseBle();

    _bleService.scanResults.listen((results) {
      for (ScanResult r in results) {
        print(r);
        if (r.advertisementData.serviceUuids.contains(
          Guid("4a1d48c9-0448-42f8-9588-e21160a221f0"),
        )) {
          setState(() {
            _nearbyDevices[r.device.remoteId.str] = r;
          });
        }
      }
    });

    _bleService.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bluetooth is OFF. Please enable it.")),
        );
      }
    });

    FlutterBluePlus.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });

    _blePeripheral.onPeripheralStateChanged?.listen((state) {
      if (state == PeripheralState.advertising) {
        setState(() {
          _isAdvertising = true;
        });
      } else {
        setState(() {
          _isAdvertising = false;
        });
      }
    });

    setState(() {
      _isLoading = false;
    });
  }

  // --- UI Actions ---
  Future<void> _startScan() async {
    setState(() {
      _isLoading = true;
    });
    _nearbyDevices.clear();
    await _bleService.startScan();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _stopScan() async {
    setState(() {
      _isLoading = true;
    });
    await _bleService.stopScan();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _startAdvertising() async {
    setState(() {
      _isLoading = true;
    });
    await _bleService.startAdvertise(_currentUserId);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _stopAdvertising() async {
    setState(() {
      _isLoading = true;
    });
    await _bleService.stopAdvertise();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _connectAndPing(BluetoothDevice device) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _bleService.sendPing(device, _currentUserId);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to ping device: $e")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximity Ping App'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCurrentUserSection(),
                const SizedBox(height: 20),
                _buildScanAdvertiseControls(),
                const SizedBox(height: 20),
                Expanded(child: _buildNearbyDevicesList()),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Your Proximity ID:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _currentUserId,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              _isAdvertising ? 'Advertising...' : 'Not Advertising',
              style: TextStyle(
                fontSize: 16,
                color: _isAdvertising ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanAdvertiseControls() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(
                    _isScanning ? Icons.stop : Icons.bluetooth_searching,
                  ),
                  label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning
                        ? Colors.redAccent
                        : Colors.lightBlueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isAdvertising
                      ? _stopAdvertising
                      : _startAdvertising,
                  icon: Icon(_isAdvertising ? Icons.stop : Icons.share),
                  label: Text(
                    _isAdvertising ? 'Stop Advertise' : 'Start Advertise',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAdvertising
                        ? Colors.redAccent
                        : Colors.lightGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _isScanning ? 'Scanning for nearby users...' : 'Scan stopped',
              style: TextStyle(
                color: _isScanning ? Colors.blue[700] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyDevicesList() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Nearby Proximity Users:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            _nearbyDevices.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Text(
                        'No nearby users found yet. Start scanning!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _nearbyDevices.length,
                      itemBuilder: (context, index) {
                        final result = _nearbyDevices.values.elementAt(index);
                        final device = result.device;
                        final userIdBytes =
                            result.advertisementData.serviceData[Guid(
                              "4a1d48c9-0448-42f8-9588-e21160a221f0",
                            )];
                        final String remoteUserId = userIdBytes != null
                            ? String.fromCharCodes(userIdBytes)
                            : 'Unknown ID';
                        final String distanceEstimate = _estimateDistance(
                          result.rssi,
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blueGrey,
                            ),
                            title: Text(remoteUserId),
                            subtitle: Text(
                              '${device.localName.isNotEmpty ? device.localName : 'No Name'} (${device.remoteId.str.substring(0, 8)}...)',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${result.rssi} dBm',
                                  style: TextStyle(
                                    color: result.rssi > -70
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                Text(
                                  distanceEstimate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showPingConfirmation(
                              context,
                              device,
                              remoteUserId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _estimateDistance(int rssi) {
    if (rssi > -60) {
      return 'Very Close (<1m)';
    } else if (rssi > -70) {
      return 'Close (1-3m)';
    } else if (rssi > -80) {
      return 'Medium (3-8m)';
    } else {
      return 'Far (>8m)';
    }
  }

  void _showPingConfirmation(
    BuildContext context,
    BluetoothDevice device,
    String remoteUserId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('Send Ping?'),
          content: Text('Do you want to send a "ping" to $remoteUserId?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _connectAndPing(device);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Ping!'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _bleService.stopScan();
    _bleService.stopAdvertise();
    super.dispose();
  }
}
