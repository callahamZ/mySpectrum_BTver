import 'package:flutter/material.dart';
import 'package:spectrumapp/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export.')));
      }
      return;
    }

    List<List<dynamic>> csvData = [];
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

      while (spectrumData.length < 10) {
        spectrumData.add(0.0);
      }

      csvData.add([
        measurement[DatabaseHelper.columnId],
        formattedTimestamp,
        measurement[DatabaseHelper.columnTemperature]?.toStringAsFixed(1) ??
            'N/A',
        measurement[DatabaseHelper.columnLux]?.toStringAsFixed(1) ?? 'N/A',
        ...spectrumData.map((e) => e.toStringAsFixed(2)).toList(),
      ]);
    }

    String csv = const ListToCsvConverter().convert(csvData);

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'spectrum_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final File file = File('${tempDir.path}/$fileName');

      await file.writeAsString(csv);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Exported Spectrum Data');

      print('Share menu opened for file: ${file.path}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing data: $e')));
      }
      print('Error sharing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportDataToCsv,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _deleteAllMeasurements,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
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
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Temperature: ${temperature?.toStringAsFixed(1) ?? 'N/A'} °C',
                                ),
                                Text(
                                  'Lux: ${lux?.toStringAsFixed(1) ?? 'N/A'} Lux',
                                ),
                                Text(
                                  'Spectrum Data (F1-F8, Clear, NIR): ${spectrumData.map((e) => e.toStringAsFixed(2)).join(', ')}',
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
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
          ),
        ],
      ),
    );
  }
}
