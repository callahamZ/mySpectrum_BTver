import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'; // New import for Bluetooth
import 'dart:typed_data';
import 'package:usb_serial/transaction.dart';
import 'database_service.dart';
import 'dart:async';

// Define an enum for connection types
enum ConnectionType { usb, bluetooth, none }

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();

  factory ConnectionService() {
    return _instance;
  }

  ConnectionService._internal();

  UsbPort? _usbSerialPort;
  BluetoothConnection? _bluetoothConnection; // Bluetooth connection object
  StreamSubscription<String>? _usbSubscription;
  StreamSubscription<Uint8List>? _bluetoothSubscription; // Bluetooth stream
  Transaction<String>? _usbTransaction;

  Function(List<double>, double, double)? onDataReceived;
  Function(String)? onRawDataReceived;
  ConnectionType _currentConnectionType =
      ConnectionType.none; // Track current connection type

  bool get isConnected {
    return _currentConnectionType != ConnectionType.none;
  }

  ConnectionType get currentConnectionType => _currentConnectionType;

  // Connect to USB Serial
  Future<void> connectToUsbSerial(String baudRate) async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      throw Exception('No USB devices found.');
    }

    try {
      _usbSerialPort = await devices[0].create();
      bool openResult = await _usbSerialPort!.open();
      if (!openResult) {
        throw Exception('Failed to open USB serial port.');
      }

      await _usbSerialPort!.setDTR(false);
      await _usbSerialPort!.setRTS(false);

      int baudRateInt = int.parse(baudRate);
      await _usbSerialPort!.setPortParameters(
        baudRateInt,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _currentConnectionType = ConnectionType.usb;

      _usbTransaction = Transaction.stringTerminated(
        _usbSerialPort!.inputStream as Stream<Uint8List>,
        Uint8List.fromList([13, 10]), // Assuming \r\n termination
      );

      _usbSubscription = _usbTransaction!.stream.listen(
        (String line) {
          if (onRawDataReceived != null) {
            onRawDataReceived!(line); // Send raw line to SettingsPage
          }
          _processSerialData(line);
        },
        onError: (error) {
          print("USB serial stream error: $error");
          disconnect();
        },
        onDone: () {
          print("USB serial stream done");
          disconnect();
        },
      );
    } catch (e) {
      disconnect();
      rethrow;
    }
  }

  // Connect to Bluetooth Device
  Future<void> connectToBluetooth(BluetoothDevice device) async {
    try {
      _bluetoothConnection = await BluetoothConnection.toAddress(
        device.address,
      );
      print('Connected to the Bluetooth device');
      _currentConnectionType = ConnectionType.bluetooth;

      _bluetoothSubscription = _bluetoothConnection!.input!.listen(
        (Uint8List data) {
          String line =
              String.fromCharCodes(data).trim(); // Assuming data is text
          if (onRawDataReceived != null) {
            onRawDataReceived!(line); // Send raw line to SettingsPage
          }
          _processSerialData(line);
        },
        onDone: () {
          print('Disconnected by remote device');
          disconnect();
        },
        onError: (error) {
          print('Bluetooth stream error: $error');
          disconnect();
        },
      );
    } catch (e) {
      print('Error connecting to Bluetooth device: $e');
      disconnect();
      rethrow;
    }
  }

  void _processSerialData(String rawData) {
    if (rawData.startsWith('@DataCap')) {
      List<String> values = rawData.substring('@DataCap,'.length).split(',');
      // Now expecting 12 values: F1-F8, Clear, NIR, Lux, Temperature
      if (values.length == 12) {
        try {
          List<double> spektrumData = [];
          // Parse F1-F8
          for (int i = 0; i < 8; i++) {
            spektrumData.add(double.parse(values[i]));
          }
          // Parse Clear and NIR
          spektrumData.add(double.parse(values[8])); // Clear
          spektrumData.add(double.parse(values[9])); // NIR

          double lux = double.parse(values[10]); // Lux is now at index 10
          double temperature = double.parse(
            values[11],
          ); // Temperature is now at index 11

          DatabaseHelper.instance.insertMeasurement(
            timestamp: DateTime.now(),
            spectrumData: spektrumData,
            temperature: temperature,
            lux: lux,
          );

          if (onDataReceived != null) {
            // onDataReceived expects List<double> for spektrumData, double for temperature, double for lux
            onDataReceived!(spektrumData, temperature, lux);
          }
        } catch (e) {
          print("Error parsing serial data: $e from: $rawData");
        }
      } else {
        print(
          "Received data has incorrect number of values: $rawData. Expected 12, got ${values.length}",
        );
      }
    } else {
      print("Received data does not start with @DataCap: $rawData");
    }
  }

  // Disconnect from current connection (USB or Bluetooth)
  Future<void> disconnect() async {
    if (_usbSubscription != null) {
      await _usbSubscription!.cancel();
      _usbSubscription = null;
    }
    if (_usbTransaction != null) {
      _usbTransaction!.dispose();
      _usbTransaction = null;
    }
    if (_usbSerialPort != null) {
      await _usbSerialPort!.close();
      _usbSerialPort = null;
    }

    if (_bluetoothSubscription != null) {
      await _bluetoothSubscription!.cancel();
      _bluetoothSubscription = null;
    }
    if (_bluetoothConnection != null) {
      _bluetoothConnection!.dispose();
      _bluetoothConnection = null;
    }

    _currentConnectionType = ConnectionType.none;
    print("Disconnected from current connection.");
  }

  // Method to send data over the active connection
  Future<void> sendData(String data) async {
    if (_currentConnectionType == ConnectionType.usb &&
        _usbSerialPort != null) {
      try {
        List<int> bytes = data.codeUnits;
        await _usbSerialPort!.write(Uint8List.fromList(bytes));
        print("Sent USB data: $data");
      } catch (e) {
        print("Error sending USB data: $e");
      }
    } else if (_currentConnectionType == ConnectionType.bluetooth &&
        _bluetoothConnection != null &&
        _bluetoothConnection!.isConnected) {
      try {
        _bluetoothConnection!.output.add(Uint8List.fromList(data.codeUnits));
        await _bluetoothConnection!.output.allSent;
        print("Sent Bluetooth data: $data");
      } catch (e) {
        print("Error sending Bluetooth data: $e");
      }
    } else {
      print("No active connection to send data.");
    }
  }
}
