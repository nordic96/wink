import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

const String _serviceUuid =
    "4a1d48c9-0448-42f8-9588-e21160a221f0"; // Replace with your own!
// const String _userIdCharacteristicUuid =
//     "1e3c8d10-85f0-41a4-9e32-a1b7e09c7d00"; // Replace with your own!
const String _pingCharacteristicUuid =
    "9f2a7b3c-1d4e-4f5a-8b6c-7e8d9f0a1b2c"; // Replace with your own!

class BleService {
  static final BleService _instance = BleService._internal();
  static final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  factory BleService() => _instance;
  BleService._internal();

  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  final Map<String, BluetoothDevice> _connectedDevices = {};

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statusList = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location, // Location is often needed for BLE scanning
    ].request();
    bool granted = statusList.values.every((s) => s.isGranted);
    if (!granted) {
      print("Bluetooth or Location permissions not granted");
    }
    return granted;
  }

  Future<void> initialiseBle() async {
    adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        print('Bluetooth OFF');
      } else if (state == BluetoothAdapterState.on) {
        print('Bluetooth ON');
      }
    });
  }

  Future<void> startScan() async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      print("Bluetooth not enabled");
      return;
    }

    if (!(await requestPermissions())) {
      print("Permissions not granted for scanning");
    }

    try {
      print("starting BLE Scan...");
      await FlutterBluePlus.startScan(
        withServices: [Guid(_serviceUuid)],
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      print("Error starting scan: $e");
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      print("BLE Scan stopped");
    } catch (e) {
      print("Error stopping Scan... $e");
    }
  }

  // --Advertising--
  Future<void> startAdvertise(String userId) async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      return;
    }
    if (!(await FlutterBluePlus.isSupported)) {
      await requestPermissions();
      return;
    }

    List<int> userIdBytes = userId.codeUnits;
    print(userIdBytes);
    final AdvertiseData advertiseData = AdvertiseData(
      serviceUuid: Guid(_serviceUuid).str,
      localName: 'test',
      manufacturerId: 1234,
      includeDeviceName: true,
      serviceData: _serviceUuid.codeUnits,
    );

    final advertiseSettings = AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeLowLatency,
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
      timeout: 0,
      connectable: true,
    );
    try {
      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );
      print('BLE advertising started with FlutterBlePeripheral');
    } catch (e) {
      print('Error while starting blePeripheral $e');
    }
  }

  Future<void> stopAdvertise() async {
    try {
      await _blePeripheral.stop();
      print("BLE stopped");
    } catch (e) {
      print("Error while stopping advertising: $e");
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      device.connectionState.listen((BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.connected) {
          _connectedDevices[device.remoteId.str] = device;
          print("Connected to ${device.platformName}");
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectedDevices.remove(device.remoteId.str);
          print("Disconnected from ${device.platformName}");
        }
      });

      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
      print("Connection initiated to ${device.platformName}");

      List<BluetoothService> services = await device.discoverServices();
      print("Discovered ${services.length} services on ${device.platformName}");
    } catch (e) {
      print("Error while connecting to device $e");
      device.disconnect();
    }
  }

  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      device.disconnect();
    } catch (e) {
      print("Error disconnecting $e");
    }
  }

  Future<void> sendPing(BluetoothDevice device, String senderUserId) async {
    try {
      if (device.connectionState.first != BluetoothConnectionState.connected) {
        print("Device not connected, attemping to connect...");
        await connectToDevice(device);
        await Future.delayed(const Duration(microseconds: 500));
      }

      List<BluetoothService> services = await device.discoverServices();
      final pingCharacteristic = services
          .firstWhere(
            (s) => s.uuid == Guid(_serviceUuid),
            orElse: () => throw Exception('Service not found'),
          )
          .characteristics
          .firstWhere(
            (c) => c.uuid == Guid(_pingCharacteristicUuid),
            orElse: () => throw Exception('Characteristic not found'),
          );

      if (pingCharacteristic.properties.write) {
        await pingCharacteristic.write(
          senderUserId.codeUnits,
          withoutResponse: pingCharacteristic.properties.writeWithoutResponse,
        );
        print(
          "Successfully sent PING to ${device.platformName} from $senderUserId",
        );
      } else {
        print("Ping characteristics is not writable on ${device.platformName}");
      }
    } catch (e) {
      print("Error while ping : $e");
    }
  }
}
