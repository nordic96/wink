import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wink/services/ble_service.dart';

void main() {
  runApp(const MaterialApp(home: HomePage()));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BleService(),
      child: Consumer<BleService>(
        builder: (context, bleService, child) => Scaffold(
          appBar: AppBar(title: const Text('BLE Scanner & Advertiser')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Control Panel ---
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(
                          'Status: ${bleService.scannerStatus}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // --- Scan Button ---
                            ElevatedButton.icon(
                              onPressed: bleService.isScanning
                                  ? bleService.stopScan
                                  : bleService.startScan,
                              icon: Icon(
                                bleService.isScanning
                                    ? Icons.stop
                                    : Icons.search,
                              ),
                              label: Text(
                                bleService.isScanning
                                    ? 'Stop Scan'
                                    : 'Start Scan',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: bleService.isScanning
                                    ? Colors.redAccent
                                    : Colors.green,
                              ),
                            ),
                            // --- Advertise Button ---
                            ElevatedButton.icon(
                              onPressed: bleService.isAdvertising
                                  ? bleService.stopAdvertising
                                  : bleService.startAdvertising,
                              icon: Icon(
                                bleService.isAdvertising
                                    ? Icons.stop_circle_outlined
                                    : Icons.sensors,
                              ),
                              label: Text(
                                bleService.isAdvertising
                                    ? 'Stop Adv'
                                    : 'Advertise',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: bleService.isAdvertising
                                    ? Colors.orange
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- Discovered Devices List ---
                Text(
                  'Discovered Devices',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Divider(),
                Expanded(
                  child: bleService.discoveredDevices.isEmpty
                      ? const Center(child: Text('No devices found yet.'))
                      : ListView.builder(
                          itemCount: bleService.discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = bleService.discoveredDevices[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                leading: const Icon(Icons.bluetooth),
                                title: Text(
                                  device.name.isNotEmpty
                                      ? device.name
                                      : 'Unknown Device',
                                ),
                                subtitle: Text(
                                  'ID: ${device.id}\nRSSI: ${device.rssi} dBm',
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
