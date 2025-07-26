import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:spectrumapp/services/database_service.dart';

class FirebaseStreamer extends StatefulWidget {
  final VoidCallback? onDataSaved;

  const FirebaseStreamer({super.key, this.onDataSaved});

  @override
  State<FirebaseStreamer> createState() => _FirebaseStreamerState();
}

class _FirebaseStreamerState extends State<FirebaseStreamer> {
  final DatabaseReference spektrumDatabase = FirebaseDatabase.instance.ref();

  // Flag to prevent processing data on the very first build,
  // before any real data updates have occurred, and to handle initial state.
  bool _isFirstBuild = true;

  // New variable to store the dataFinish state from the previous snapshot.
  // Initialize to false, assuming the initial state from Firebase is false
  // or that we don't want to process on the very first 'true' if it starts true.
  bool _lastKnownDataFinishState = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: spektrumDatabase.onValue,
      builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
        List<double> currentSpektrumDataIntVal = [];
        String currentTempVal = "N/A";
        String currentLuxVal = "N/A";
        bool currentDataFinish =
            false; // Default to false for the current snapshot

        Map<dynamic, dynamic>? rootData;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          rootData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
        }

        // Process data only if rootData is not null
        if (rootData != null) {
          // Get the current dataFinish flag
          if (rootData.containsKey("dataFinish") &&
              rootData["dataFinish"] is bool) {
            currentDataFinish = rootData["dataFinish"];
          }

          // **Crucial Logic Change Here:**
          // Process and store data only if:
          // 1. It's not the very first build of the StreamBuilder (to prevent initial processing).
          // 2. The current `dataFinish` is `true`.
          // 3. The `dataFinish` from the previous snapshot (`_lastKnownDataFinishState`) was `false`.
          //    This condition ensures it only triggers on a false-to-true transition.
          if (!_isFirstBuild &&
              currentDataFinish &&
              !_lastKnownDataFinishState) {
            try {
              // Extract spectrum data
              Map<dynamic, dynamic>? spektrumData = rootData["sensorSpektrum"];
              if (spektrumData != null) {
                for (int i = 1; i <= 8; i++) {
                  String key = 'F$i';
                  if (spektrumData.containsKey(key)) {
                    double value = double.parse(spektrumData[key].toString());
                    currentSpektrumDataIntVal.add(value);
                  }
                }
                // Extract Clear data
                if (spektrumData.containsKey("Clear")) {
                  double clearValue = double.parse(
                    spektrumData["Clear"].toString(),
                  );
                  currentSpektrumDataIntVal.add(clearValue);
                } else {
                  currentSpektrumDataIntVal.add(0.0); // Add default if missing
                }
                // Extract NIR data
                if (spektrumData.containsKey("NIR")) {
                  double nirValue = double.parse(
                    spektrumData["NIR"].toString(),
                  );
                  currentSpektrumDataIntVal.add(nirValue);
                } else {
                  currentSpektrumDataIntVal.add(0.0); // Add default if missing
                }
              }

              // Extract temperature data
              if (rootData["sensorSuhu"] != null &&
                  rootData["sensorSuhu"]["Suhu"] != null) {
                currentTempVal = rootData["sensorSuhu"]["Suhu"].toString();
              }

              // Extract lux data
              if (rootData["sensorCahaya"] != null &&
                  rootData["sensorCahaya"]["Lux"] != null) {
                currentLuxVal = rootData["sensorCahaya"]["Lux"].toString();
              }

              // Insert data into local database
              DatabaseHelper.instance
                  .insertMeasurement(
                    timestamp: DateTime.now(),
                    spectrumData: currentSpektrumDataIntVal,
                    temperature: double.parse(currentTempVal),
                    lux: double.parse(currentLuxVal),
                  )
                  .then((_) {
                    // Notify parent that data has been saved
                    if (widget.onDataSaved != null) {
                      widget.onDataSaved!();
                    }
                  });
              print(
                "Data processed and inserted into local DB because dataFinish transitioned from false to true.",
              );
            } catch (e) {
              print("Error processing data or inserting into DB: $e");
            }
          } else if (!_isFirstBuild) {
            // Optional: Add logging to understand why data processing was skipped
            if (!currentDataFinish) {
              print("Data processing skipped: current dataFinish is false.");
            } else if (_lastKnownDataFinishState) {
              print(
                "Data processing skipped: dataFinish is true, but it was already true in the previous state (no false-to-true transition).",
              );
            }
          }
        }

        // Update flags for the next build cycle:
        // Set _isFirstBuild to false after the initial build.
        _isFirstBuild = false;
        // Store the current dataFinish state for the next comparison.
        _lastKnownDataFinishState = currentDataFinish;

        // FirebaseStreamer no longer builds any UI, it just handles data saving.
        // Return an empty SizedBox or a placeholder.
        return const SizedBox.shrink();
      },
    );
  }
}
