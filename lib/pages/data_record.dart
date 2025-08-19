import 'package:flutter/material.dart';
import 'package:spectrumapp/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // This import provides getDownloadsDirectory
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart'; // Ensure this exact import for Permission class

class DataRecordPage extends StatefulWidget {
  const DataRecordPage({super.key});

  @override
  State<DataRecordPage> createState() => _DataRecordPageState();
}

class _DataRecordPageState extends State<DataRecordPage> {
  List<Map<String, dynamic>> _measurements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    setState(() {
      _isLoading = true;
    });
    final data = await DatabaseHelper.instance.getAllMeasurements();
    setState(() {
      _measurements = data;
      _isLoading = false;
    });
  }

  Future<void> _deleteMeasurement(int id) async {
    await DatabaseHelper.instance.deleteMeasurement(id);
    _loadMeasurements(); // Refresh the list
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Measurement deleted.')));
  }

  Future<void> _deleteAllMeasurements() async {
    // Show a confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
            'Are you sure you want to delete all recorded data? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteAllMeasurements();
      _loadMeasurements(); // Refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All measurements deleted.')),
      );
    }
  }

  Future<void> _exportDataToCsv() async {
    if (_measurements.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    // Request storage permission before exporting
    // For Android 10+ (API 29+), Permission.storage often maps to MediaStore access
    // when using getDownloadsDirectory, and might not show a direct "storage" prompt
    // but rather rely on implicit access or a different prompt type if needed.
    var status = await Permission.storage.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission denied. Cannot export data.'),
        ),
      );
      return;
    }
    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Storage permission permanently denied. Please enable it in app settings.',
          ),
        ),
      );
      await openAppSettings(); // Opens app settings for the user to manually grant
      return;
    }

    // Prepare CSV data
    List<List<dynamic>> csvData = [];

    // Add header row
    csvData.add([
      'ID',
      'Timestamp',
      'Temperature (°C)',
      'Lux (Lux)',
      'F1',
      'F2',
      'F3',
      'F4',
      'F5',
      'F6',
      'F7',
      'F8',
      'Clear',
      'NIR',
    ]);

    // Add data rows
    for (var measurement in _measurements) {
      final timestamp = DateTime.parse(
        measurement[DatabaseHelper.columnTimestamp],
      );
      final formattedTimestamp = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(timestamp);
      final spectrumDataString =
          measurement[DatabaseHelper.columnSpectrumData] as String?;
      List<double> spectrumData = [];
      if (spectrumDataString != null && spectrumDataString.isNotEmpty) {
        spectrumData =
            spectrumDataString.split(',').map((e) => double.parse(e)).toList();
      }

      // Ensure spectrumData has 10 elements, pad with 0.0 if less
      while (spectrumData.length < 10) {
        spectrumData.add(0.0);
      }

      csvData.add([
        measurement[DatabaseHelper.columnId],
        formattedTimestamp,
        measurement[DatabaseHelper.columnTemperature]?.toStringAsFixed(1) ??
            'N/A',
        measurement[DatabaseHelper.columnLux]?.toStringAsFixed(1) ?? 'N/A',
        // Add all 10 spectrum data channels
        ...spectrumData.map((e) => e.toStringAsFixed(2)).toList(),
      ]);
    }

    // Convert list of lists to CSV string
    String csv = const ListToCsvConverter().convert(csvData);

    try {
      // Get the Downloads directory (user-accessible public directory)
      final Directory? directory =
          await getDownloadsDirectory(); // Corrected function call

      if (directory == null) {
        throw Exception(
          "Could not get Downloads directory. It might not be supported on this platform or device.",
        );
      }

      final String fileName =
          'spectrum_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final File file = File('${directory.path}/$fileName');

      // Ensure the directory exists (e.g., if 'Download' folder was somehow deleted)
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Write the CSV content to the file
      await file.writeAsString(csv);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Data exported to ${file.path}')));
      print('CSV exported to: ${file.path}');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting data: $e')));
      print('Error exporting data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _measurements.isEmpty
              ? const Center(child: Text('No data recorded yet.'))
              : ListView.builder(
                itemCount: _measurements.length,
                itemBuilder: (context, index) {
                  final measurement = _measurements[index];
                  final timestamp = DateTime.parse(
                    measurement[DatabaseHelper.columnTimestamp],
                  );
                  final spectrumData =
                      measurement[DatabaseHelper.columnSpectrumData]
                          ?.split(',')
                          .map((e) => double.parse(e))
                          .toList() ??
                      [];
                  final temperature =
                      measurement[DatabaseHelper.columnTemperature];
                  final lux = measurement[DatabaseHelper.columnLux];

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Temperature: ${temperature?.toStringAsFixed(1) ?? 'N/A'} °C',
                          ),
                          Text('Lux: ${lux?.toStringAsFixed(1) ?? 'N/A'} Lux'),
                          Text(
                            'Spectrum Data (F1-F8, Clear, NIR): ${spectrumData.map((e) => e.toStringAsFixed(2)).join(', ')}',
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed:
                                  () => _deleteMeasurement(
                                    measurement[DatabaseHelper.columnId],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _exportDataToCsv,
            label: const Text('Export Data'),
            icon: const Icon(Icons.download),
            backgroundColor: Colors.blue,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: _deleteAllMeasurements,
            label: const Text('Delete All Data'),
            icon: const Icon(Icons.delete_forever),
            backgroundColor: Colors.red,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
