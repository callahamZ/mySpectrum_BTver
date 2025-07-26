import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart'; // REMOVED
// import 'firebase_options.dart'; // REMOVED
import 'package:spectrumapp/services/connection_service.dart'; // CHANGED import
import 'data_record.dart';
import 'settings.dart';
import 'home_page.dart';
import 'compare_mode.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  // Renamed from isFirebaseMode to isBluetoothMode
  bool isBluetoothMode = true; // True for Bluetooth, false for Cable Serial

  final ConnectionService _connectionService = ConnectionService(); // CHANGED

  void toggleConnectionMode() {
    // Renamed
    setState(() {
      isBluetoothMode = !isBluetoothMode;
      // Update the snackbar message to reflect Bluetooth/Cable Serial
      if (!_connectionService.isConnected && !isBluetoothMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No Cable Serial Port Detected; Go to settings to set it up',
            ),
          ),
        );
      } else if (!_connectionService.isConnected && isBluetoothMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No Bluetooth Device Connected; Go to settings to set it up',
            ),
          ),
        );
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return HomePageContent(
          key: ValueKey(isBluetoothMode),
          isBluetoothMode: isBluetoothMode, // CHANGED
          toggleConnectionMode: toggleConnectionMode, // CHANGED
        );
      case 1:
        return CompareModePage(
          key: ValueKey(isBluetoothMode),
          isBluetoothMode: isBluetoothMode, // CHANGED
          toggleConnectionMode: toggleConnectionMode, // CHANGED
        );
      case 2:
        return DataRecordPage();
      case 3:
        return SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 233, 233, 233),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 18, color: Colors.black),
            children: <TextSpan>[
              TextSpan(
                text: 'My',
                style: TextStyle(fontWeight: FontWeight.normal),
              ),
              TextSpan(
                text: 'Spectrum',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: _getBody(), // Use a function to dynamically build the body
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.compare),
            label: 'Compare Mode',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Data Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
