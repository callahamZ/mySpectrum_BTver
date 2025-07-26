import 'package:flutter/material.dart';
import 'package:spectrumapp/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:spectrumapp/services/data_process.dart'; // Import the data processing service

class DataRecordPage extends StatefulWidget {
  const DataRecordPage({Key? key}) : super(key: key);

  @override
  _DataRecordPageState createState() => _DataRecordPageState();
}

class _DataRecordPageState extends State<DataRecordPage> {
  late Future<List<Map<String, dynamic>>> _measurementsFuture;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    _measurementsFuture = DatabaseHelper.instance.getAllMeasurements();
  }

  Future<void> _deleteMeasurement(int id) async {
    await DatabaseHelper.instance.deleteMeasurement(id);
    _loadMeasurements();
    setState(() {});
  }

  Future<void> _deleteAllMeasurements() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Confirm Delete',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to delete all data? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.deleteAllMeasurements();
                _loadMeasurements();
                setState(() {});
                Navigator.of(context).pop();
              },
              child: const Text(
                'Delete All',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 233, 233, 233),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Data Records",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _deleteAllMeasurements,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _measurementsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final measurements = snapshot.data!;
            return ListView.builder(
              itemCount: measurements.length,
              itemBuilder: (context, index) {
                final measurement = measurements[index];
                final spectrumValues =
                    (measurement['spectrumData'] as String?)?.split(',') ?? [];

                // Extract Clear and NIR values if available
                String clearValue = 'N/A';
                String nirValue = 'N/A';
                if (spectrumValues.length >= 10) {
                  clearValue = spectrumValues[8];
                  nirValue = spectrumValues[9];
                }

                // Retrieve raw temperature and lux values
                final rawTemperature =
                    (measurement['temperature'] as double?) ?? 0.0;
                final rawLux = (measurement['lux'] as double?) ?? 0.0;

                // Apply linear regression for calibrated values
                final calibratedTemperature = DataProcessor.processTemperature(
                  rawTemperature,
                );
                final calibratedLux = DataProcessor.processLux(rawLux);

                return Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  padding: const EdgeInsets.all(16.0),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(measurement['timestamp']))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (spectrumValues.length >= 8)
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('F1: ${spectrumValues[0]}'),
                                      Text('F2: ${spectrumValues[1]}'),
                                      Text('F3: ${spectrumValues[2]}'),
                                      Text('F4: ${spectrumValues[3]}'),
                                    ],
                                  ),
                                  SizedBox(width: 20),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('F5: ${spectrumValues[4]}'),
                                      Text('F6: ${spectrumValues[5]}'),
                                      Text('F7: ${spectrumValues[6]}'),
                                      Text('F8: ${spectrumValues[7]}'),
                                    ],
                                  ),
                                ],
                              ),

                            // Display Clear and NIR values
                            Text('Clear: $clearValue'),
                            Text('NIR: $nirValue'),

                            if (spectrumValues.length < 8 &&
                                spectrumValues.isNotEmpty)
                              Text(
                                'Spectrum Data: ${measurement['spectrumData']}',
                              ),
                            if (spectrumValues.isEmpty)
                              const Text('Spectrum Data: -'),
                            // Display calibrated temperature and lux
                            Text(
                              'Temp: ${calibratedTemperature.toStringAsFixed(1)}° C',
                            ),
                            Text('Lux: ${calibratedLux.toStringAsFixed(1)}'),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteMeasurement(measurement['id']);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
