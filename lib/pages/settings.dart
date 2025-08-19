import 'package:flutter/material.dart';
import 'package:spectrumapp/services/connection_service.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // USB Serial related
  late Future<List<UsbDevice>> _usbPortListFuture;
  String? _selectedBaudRate = '115200';
  final List<String> _baudRates = ['9600', '115200', '19200'];

  // Bluetooth related
  List<BluetoothDevice> _bluetoothDevices = [];
  BluetoothDevice? _selectedBluetoothDevice;
  bool _isDiscovering = false;

  final ConnectionService _connectionService = ConnectionService();
  final List<String> _rawDataBuffer = [];
  final int _maxBufferLines = 100;

  // New state variables for AS7341 LED Flash
  bool _isFlashOn = false;
  double _brightnessLevel = 20.0;

  @override
  void initState() {
    super.initState();
    _refreshUsbPortList();
    _connectionService.onRawDataReceived = (String rawData) {
      setState(() {
        _rawDataBuffer.add(rawData);
        if (_rawDataBuffer.length > _maxBufferLines) {
          _rawDataBuffer.removeAt(0);
        }
      });
    };
  }

  @override
  void dispose() {
    _connectionService.onRawDataReceived = null;
    super.dispose();
  }

  // USB Serial Methods
  Future<void> _refreshUsbPortList() async {
    setState(() {
      _usbPortListFuture = Future.delayed(
        const Duration(milliseconds: 500),
        () => UsbSerial.listDevices(),
      );
    });
  }

  Future<void> _connectToUsbSerial() async {
    try {
      await _connectionService.connectToUsbSerial(_selectedBaudRate!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cable Serial port connected.')),
      );
      setState(() {
        _rawDataBuffer.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to Cable Serial: $e')),
      );
    }
  }

  // Bluetooth Methods
  Future<void> _requestBluetoothPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();

    if (statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true &&
        statuses[Permission.locationWhenInUse]?.isGranted == true) {
      print("Bluetooth and Location permissions granted.");
      _startDiscovery();
    } else {
      print("Bluetooth or Location permissions denied.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bluetooth and Location permissions are required to scan for devices.',
          ),
        ),
      );
    }
  }

  void _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _bluetoothDevices = []; // Clear previous list
      _selectedBluetoothDevice = null; // Clear selected device on new discovery
    });

    bool? isEnabled = await FlutterBluetoothSerial.instance.isOn;
    if (isEnabled == null || !isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable Bluetooth on your device.'),
        ),
      );
      setState(() {
        _isDiscovering = false;
      });
      return;
    }

    FlutterBluetoothSerial.instance
        .startDiscovery()
        .listen((r) {
          setState(() {
            final existingIndex = _bluetoothDevices.indexWhere(
              (element) => element.address == r.device.address,
            );
            if (existingIndex >= 0) {
              _bluetoothDevices[existingIndex] = r.device;
            } else {
              _bluetoothDevices.add(r.device);
            }
          });
        })
        .onDone(() {
          setState(() {
            _isDiscovering = false;
          });
        });
  }

  Future<void> _connectToBluetooth() async {
    if (_selectedBluetoothDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Bluetooth device.')),
      );
      return;
    }
    try {
      await _connectionService.connectToBluetooth(_selectedBluetoothDevice!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connected to ${_selectedBluetoothDevice!.name ?? _selectedBluetoothDevice!.address}',
          ),
        ),
      );
      setState(() {
        _rawDataBuffer.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to Bluetooth: $e')),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      await _connectionService.disconnect();
      setState(() {
        _rawDataBuffer.clear();
        _selectedBluetoothDevice = null; // Clear selected device on disconnect
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Disconnected.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error disconnecting: $e')));
    }
  }

  // New method to handle sending the LED Flash configuration
  void _setLEDParameters() {
    // Determine the boolean value (1 for ON, 0 for OFF)
    final flashValue = _isFlashOn ? 1 : 0;
    // Format the brightness level, rounding to the nearest integer
    final brightnessValue = _brightnessLevel.round();
    // Construct the final serial data string
    final dataToSend = "@SetLED,$flashValue,$brightnessValue\n";

    // Call the sendData method from the connection service
    _connectionService.sendData(dataToSend);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sent command: $dataToSend')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Connection Status",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    _connectionService.isConnected
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color:
                      _connectionService.isConnected
                          ? Colors.green
                          : Colors.red,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectionService.isConnected
                        ? Icons.check_circle
                        : Icons.cancel,
                    color:
                        _connectionService.isConnected
                            ? Colors.green
                            : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _connectionService.isConnected
                        ? 'Connected via ${_connectionService.currentConnectionType.name.toUpperCase()}'
                        : 'Disconnected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          _connectionService.isConnected
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              "Bluetooth Connection",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            // Updated Bluetooth section to place the refresh icon inside the container
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(50, 0, 0, 0),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Available Devices",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // The Bluetooth refresh icon is now here, inside the container
                      GestureDetector(
                        onTap:
                            _isDiscovering
                                ? null
                                : _requestBluetoothPermissions,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isDiscovering ? Colors.grey : Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child:
                                _isDiscovering
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Icon(
                                      Icons.bluetooth_searching,
                                      color: Colors.white,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(
                    height: 150,
                    child:
                        _bluetoothDevices.isEmpty && !_isDiscovering
                            ? const Center(
                              child: Text(
                                "No devices found. Tap refresh to scan.",
                              ),
                            )
                            : ListView.builder(
                              physics:
                                  const AlwaysScrollableScrollPhysics(), // Always show scroll indicator
                              itemCount: _bluetoothDevices.length,
                              itemBuilder: (context, index) {
                                BluetoothDevice device =
                                    _bluetoothDevices[index];
                                return ListTile(
                                  title: Text(device.name ?? "Unknown Device"),
                                  subtitle: Text(device.address),
                                  trailing:
                                      device.isConnected
                                          ? const Icon(
                                            Icons.bluetooth_connected,
                                            color: Colors.green,
                                          )
                                          : null,
                                  selected:
                                      _selectedBluetoothDevice?.address ==
                                      device.address,
                                  selectedTileColor:
                                      Colors
                                          .blue
                                          .shade100, // Highlight color for selected tile
                                  onTap: () {
                                    setState(() {
                                      _selectedBluetoothDevice = device;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Selected: ${device.name ?? device.address}',
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed:
                  _connectionService.isConnected
                      ? _disconnect
                      : _connectToBluetooth,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _connectionService.isConnected ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                _connectionService.isConnected
                    ? "Disconnect"
                    : "Connect Bluetooth",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 30, thickness: 1),
            const Text(
              "Cable Serial Connection (USB OTG)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromARGB(50, 0, 0, 0),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Available Ports",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Divider(),
                              FutureBuilder<List<UsbDevice>>(
                                future: _usbPortListFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Text("Loading...");
                                  } else if (snapshot.hasError) {
                                    return Text('Error: ${snapshot.error}');
                                  } else if (snapshot.hasData &&
                                      snapshot.data!.isNotEmpty) {
                                    final serialPortList = snapshot.data!;
                                    final device = serialPortList[0];
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(device.productName ?? "unknown"),
                                        Text("--> ${device.deviceName}"),
                                      ],
                                    );
                                  } else {
                                    return const Text("None");
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _refreshUsbPortList,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(left: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.refresh,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              child: const Text(
                "*OTG connection must be enabled in smartphone settings",
                style: TextStyle(fontSize: 10),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(50, 0, 0, 0),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text(
                    "Baud Rate :",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedBaudRate,
                      isExpanded: true,
                      items:
                          _baudRates.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedBaudRate = newValue!;
                        });
                      },
                      hint: const Text("Select Baud Rate"),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed:
                  _connectionService.isConnected
                      ? _disconnect
                      : _connectToUsbSerial,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _connectionService.isConnected ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                _connectionService.isConnected
                    ? "Disconnect"
                    : "Connect Cable Serial",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // New AS7341 LED Flash Settings section
            const Padding(
              padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                "AS7341 LED Flash Settings",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(50, 0, 0, 0),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Flash ON/OFF",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: _isFlashOn,
                        onChanged: (bool value) {
                          setState(() {
                            _isFlashOn = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        "Brightness Level",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Slider(
                          value: _brightnessLevel,
                          min: 10,
                          max: 100,
                          divisions: 90,
                          label: _brightnessLevel.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              _brightnessLevel = value;
                            });
                          },
                        ),
                      ),
                      Text(
                        _brightnessLevel.round().toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _setLEDParameters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      "Set",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 20.0, bottom: 10.0),
              child: Text(
                "Raw Data Stream",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.grey),
              ),
              child: ListView.builder(
                reverse: true,
                itemCount: _rawDataBuffer.length,
                itemBuilder: (context, index) {
                  return Text(
                    _rawDataBuffer[_rawDataBuffer.length - 1 - index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
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
}
