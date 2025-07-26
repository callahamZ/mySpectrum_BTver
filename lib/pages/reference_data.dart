import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spectrumapp/services/database_service.dart';

class ReferenceDataSelectionPage extends StatefulWidget {
  const ReferenceDataSelectionPage({Key? key}) : super(key: key);

  @override
  State<ReferenceDataSelectionPage> createState() =>
      _ReferenceDataSelectionPageState();
}

class _ReferenceDataSelectionPageState
    extends State<ReferenceDataSelectionPage> {
  late Future<List<Map<String, dynamic>>> _measurementsFuture;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  // Loads all measurements from the local database
  Future<void> _loadMeasurements() async {
    _measurementsFuture = DatabaseHelper.instance.getAllMeasurements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 233, 233, 233),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Select Reference Data",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _measurementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final measurements = snapshot.data!;
            return ListView.builder(
              itemCount: measurements.length,
              itemBuilder: (context, index) {
                final measurement = measurements[index];
                final timestamp = DateTime.parse(
                  measurement[DatabaseHelper.columnTimestamp],
                );
                final spectrumDataString =
                    measurement[DatabaseHelper.columnSpectrumData] as String?;
                final temperature =
                    measurement[DatabaseHelper.columnTemperature] as double?;
                final lux = measurement[DatabaseHelper.columnLux] as double?;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16.0),
                    title: Text(
                      '${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Spectrum Data: ${spectrumDataString != null && spectrumDataString.isNotEmpty ? 'Available' : 'N/A'}',
                        ),
                        Text(
                          'Temperature: ${temperature?.toStringAsFixed(1) ?? 'N/A'}° C',
                        ),
                        Text('Lux: ${lux?.toStringAsFixed(1) ?? 'N/A'} Lux'),
                      ],
                    ),
                    onTap: () {
                      // Return the selected measurement to the previous page
                      Navigator.pop(context, measurement);
                    },
                  ),
                );
              },
            );
          } else {
            return const Center(
              child: Text(
                'No measurements found. Please record some data first.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
        },
      ),
    );
  }
}
