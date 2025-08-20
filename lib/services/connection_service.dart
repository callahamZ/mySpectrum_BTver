import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';
import 'package:usb_serial/transaction.dart';
import 'database_service.dart';
import 'dart:async';

enum ConnectionType { usb, bluetooth, none }

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();

  factory ConnectionService() {
    return _instance;
  }

  ConnectionService._internal() {
    // Corrected USB detachment event constant
    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        print("USB device detached. Disconnecting...");
        disconnect();
      }
    });
  }

  UsbPort? _usbSerialPort;
  BluetoothConnection? _bluetoothConnection;
  StreamSubscription<String>? _usbSubscription;
  StreamSubscription<Uint8List>? _bluetoothSubscription;
  Transaction<String>? _usbTransaction;

  Function(List<double>, double, double)? onDataReceived;
  Function(String)? onRawDataReceived;
  Function(ConnectionType)? onConnectionStatusChanged;

  ConnectionType _currentConnectionType = ConnectionType.none;

  bool get isConnected {
    return _currentConnectionType != ConnectionType.none;
  }

  ConnectionType get currentConnectionType => _currentConnectionType;

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
      if (onConnectionStatusChanged != null) {
        onConnectionStatusChanged!(_currentConnectionType);
      }

      _usbTransaction = Transaction.stringTerminated(
        _usbSerialPort!.inputStream as Stream<Uint8List>,
        Uint8List.fromList([13, 10]),
      );

      _usbSubscription = _usbTransaction!.stream.listen(
        (String line) {
          if (onRawDataReceived != null) {
            onRawDataReceived!(line);
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

  Future<void> connectToBluetooth(BluetoothDevice device) async {
    try {
      _bluetoothConnection = await BluetoothConnection.toAddress(
        device.address,
      );
      print('Connected to the Bluetooth device');
      _currentConnectionType = ConnectionType.bluetooth;
      if (onConnectionStatusChanged != null) {
        onConnectionStatusChanged!(_currentConnectionType);
      }

      _bluetoothSubscription = _bluetoothConnection!.input!.listen(
        (Uint8List data) {
          String line = String.fromCharCodes(data).trim();
          if (onRawDataReceived != null) {
            onRawDataReceived!(line);
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
      if (values.length == 12) {
        try {
          List<double> spektrumData = [];
          for (int i = 0; i < 8; i++) {
            spektrumData.add(double.parse(values[i]));
          }
          spektrumData.add(double.parse(values[8]));
          spektrumData.add(double.parse(values[9]));

          double lux = double.parse(values[10]);
          double temperature = double.parse(values[11]);

          DatabaseHelper.instance.insertMeasurement(
            timestamp: DateTime.now(),
            spectrumData: spektrumData,
            temperature: temperature,
            lux: lux,
          );

          if (onDataReceived != null) {
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

    if (_currentConnectionType != ConnectionType.none) {
      _currentConnectionType = ConnectionType.none;
      if (onConnectionStatusChanged != null) {
        onConnectionStatusChanged!(_currentConnectionType);
      }
      print("Disconnected from current connection.");
    }
  }

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
