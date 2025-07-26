import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:spectrumapp/services/connection_service.dart'; // CHANGED import
import 'package:spectrumapp/services/graph_framework.dart';
import 'package:spectrumapp/services/database_service.dart';
// import 'package:spectrumapp/services/firebase_streamer.dart'; // REMOVED
import 'package:spectrumapp/pages/reference_data.dart';
import 'package:spectrumapp/services/data_process.dart';

enum CompareGraphView { rawData, processedData }

class CompareModePage extends StatefulWidget {
  final bool isBluetoothMode; // CHANGED
  final VoidCallback toggleConnectionMode; // CHANGED

  const CompareModePage({
    super.key,
    required this.isBluetoothMode, // CHANGED
    required this.toggleConnectionMode, // CHANGED
  });

  @override
  State<CompareModePage> createState() => _CompareModePageState();
}

class _CompareModePageState extends State<CompareModePage> {
  List<double> _serialSpectrumData = List.filled(8, 0.0);
  List<FlSpot> _currentChartData = [];
  List<FlSpot> _redChartData = [];
  List<double> _currentSpectrumValues = List.filled(10, 0.0);
  List<double> _referenceSpectrumValues = List.filled(10, 0.0);
  List<double> _currentBasicCounts = List.filled(10, 0.0);
  List<double> _currentDataSensorCorr = List.filled(10, 0.0);
  List<double> _referenceBasicCounts = List.filled(10, 0.0);
  List<double> _referenceDataSensorCorr = List.filled(10, 0.0);

  String _referenceTimestamp = "Click to Select";

  CompareGraphView _currentCompareGraphView = CompareGraphView.rawData;

  final ConnectionService _connectionService = ConnectionService(); // CHANGED

  final List<Map<String, String>> _channelCharacteristics = [
    {
      "Channel": "F1",
      "Rentang Jangkauan": "405 - 425 nm",
      "Representasi": "Purple",
    },
    {
      "Channel": "F2",
      "Rentang Jangkauan": "435 - 455 nm",
      "Representasi": "Navy",
    },
    {
      "Channel": "F3",
      "Rentang Jangkauan": "470 - 490 nm",
      "Representasi": "Blue",
    },
    {
      "Channel": "F4",
      "Rentang Jangkauan": "505 - 525 nm",
      "Representasi": "Aqua",
    },
    {
      "Channel": "F5",
      "Rentang Jangkauan": "545 - 565 nm",
      "Representasi": "Green",
    },
    {
      "Channel": "F6",
      "Rentang Jangkauan": "580 - 600 nm",
      "Representasi": "Yellow",
    },
    {
      "Channel": "F7",
      "Rentang Jangkauan": "620 - 640 nm",
      "Representasi": "Orange",
    },
    {
      "Channel": "F8",
      "Rentang Jangkauan": "670 - 690 nm",
      "Representasi": "Red",
    },
    {
      "Channel": "Clear",
      "Rentang Jangkauan": "350 - 980 nm",
      "Representasi": "White",
    },
    {
      "Channel": "NIR",
      "Rentang Jangkauan": "850 - 980 nm",
      "Representasi": "Infrared",
    },
  ];

  @override
  void initState() {
    super.initState();
    _connectionService.onDataReceived =
        _updateReceivedData; // Unified data reception
    _loadLatestLocalData(); // Load data from local DB
    print(
      "CompareModePage: Initializing with _loadLatestLocalData and setting onDataReceived.",
    );
  }

  @override
  void didUpdateWidget(covariant CompareModePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBluetoothMode != oldWidget.isBluetoothMode) {
      _clearAllData(); // Clear data when switching modes
      _loadLatestLocalData(); // Reload from DB based on new mode (if needed)
      print(
        "CompareModePage: Connection mode changed, cleared data and reloaded latest.",
      );
    }
  }

  void _clearAllData() {
    setState(() {
      _serialSpectrumData = List.filled(8, 0.0);
      _currentChartData = [];
      _redChartData = [];
      _currentSpectrumValues = List.filled(10, 0.0);
      _referenceSpectrumValues = List.filled(10, 0.0);
      _currentBasicCounts = List.filled(10, 0.0);
      _currentDataSensorCorr = List.filled(10, 0.0);
      _referenceBasicCounts = List.filled(10, 0.0);
      _referenceDataSensorCorr = List.filled(10, 0.0);
      _referenceTimestamp = "Click to Select";
      print("CompareModePage: All data cleared.");
    });
  }

  // Unified data reception method
  void _updateReceivedData(
    List<double> spektrumData,
    double temperature,
    double lux,
  ) {
    if (mounted) {
      print(
        "CompareModePage: Received data: $spektrumData, Temp: $temperature, Lux: $lux",
      );

      if (spektrumData.length < 10) {
        print(
          "CompareModePage: Warning: Received data has less than 10 channels. Padding with zeros.",
        );
        while (spektrumData.length < 10) {
          spektrumData.add(0.0);
        }
      }

      setState(() {
        _currentSpectrumValues = List.from(spektrumData);

        _currentChartData =
            spektrumData.sublist(0, 8).asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble() + 1, entry.value);
            }).toList();

        _currentBasicCounts = DataProcessor.calculateBasicCount(
          _currentSpectrumValues,
        );
        _currentDataSensorCorr = DataProcessor.calculateDataSensorCorr(
          _currentBasicCounts,
        );
        print("CompareModePage: Data processed and state updated.");
      });
    } else {
      print("CompareModePage: Received data but widget is not mounted.");
    }
  }

  // Renamed from _loadLatestFirebaseData
  Future<void> _loadLatestLocalData() async {
    final latestMeasurement =
        await DatabaseHelper.instance.getLatestMeasurement();
    if (latestMeasurement != null) {
      setState(() {
        final spectrumDataString =
            latestMeasurement[DatabaseHelper.columnSpectrumData] as String?;
        List<double> rawSpectrumData = [];
        if (spectrumDataString != null && spectrumDataString.isNotEmpty) {
          rawSpectrumData =
              spectrumDataString
                  .split(',')
                  .map((e) => double.parse(e))
                  .toList();
          _currentSpectrumValues = rawSpectrumData;

          _currentChartData =
              rawSpectrumData
                  .sublist(0, min(8, rawSpectrumData.length))
                  .asMap()
                  .entries
                  .map((entry) {
                    return FlSpot(entry.key.toDouble() + 1, entry.value);
                  })
                  .toList();

          _currentBasicCounts = DataProcessor.calculateBasicCount(
            rawSpectrumData,
          );
          _currentDataSensorCorr = DataProcessor.calculateDataSensorCorr(
            _currentBasicCounts,
          );
        } else {
          _currentSpectrumValues = List.filled(10, 0.0);
          _currentChartData = [];
          _currentBasicCounts = List.filled(10, 0.0);
          _currentDataSensorCorr = List.filled(10, 0.0);
        }
        print("CompareModePage: Local data loaded and state updated.");
      });
    } else {
      setState(() {
        _currentSpectrumValues = List.filled(10, 0.0);
        _currentChartData = [];
        _currentBasicCounts = List.filled(10, 0.0);
        _currentDataSensorCorr = List.filled(10, 0.0);
      });
      print(
        "CompareModePage: No latest local measurement found, clearing data.",
      );
    }
  }

  Future<void> _selectReferenceData() async {
    final selectedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReferenceDataSelectionPage(),
      ),
    );

    if (selectedData != null && selectedData is Map<String, dynamic>) {
      setState(() {
        final spectrumDataString =
            selectedData[DatabaseHelper.columnSpectrumData] as String?;
        if (spectrumDataString != null && spectrumDataString.isNotEmpty) {
          _referenceSpectrumValues =
              spectrumDataString
                  .split(',')
                  .map((e) => double.parse(e))
                  .toList();

          _referenceBasicCounts = DataProcessor.calculateBasicCount(
            _referenceSpectrumValues,
          );
          _referenceDataSensorCorr = DataProcessor.calculateDataSensorCorr(
            _referenceBasicCounts,
          );

          _redChartData =
              _referenceSpectrumValues
                  .sublist(0, min(8, _referenceSpectrumValues.length))
                  .asMap()
                  .entries
                  .map((entry) {
                    return FlSpot(entry.key.toDouble() + 1, entry.value);
                  })
                  .toList();
        } else {
          _referenceSpectrumValues = List.filled(10, 0.0);
          _redChartData = [];
          _referenceBasicCounts = List.filled(10, 0.0);
          _referenceDataSensorCorr = List.filled(10, 0.0);
        }
        _referenceTimestamp = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(DateTime.parse(selectedData[DatabaseHelper.columnTimestamp]));
        print("CompareModePage: Reference data selected and processed.");
      });
    } else {
      setState(() {
        _referenceSpectrumValues = List.filled(10, 0.0);
        _redChartData = [];
        _referenceBasicCounts = List.filled(10, 0.0);
        _referenceDataSensorCorr = List.filled(10, 0.0);
        _referenceTimestamp = "Nothing";
      });
      print(
        "CompareModePage: No reference data selected, clearing reference data.",
      );
    }
  }

  double _calculateDeltaAvg(
    List<double> currentData,
    List<double> referenceData,
  ) {
    if (currentData.isEmpty ||
        referenceData.isEmpty ||
        currentData.length < 8 ||
        referenceData.length < 8) {
      return 0.0;
    }

    double totalDelta = 0.0;
    for (int i = 0; i < 8; i++) {
      totalDelta += (currentData[i] - referenceData[i]);
    }
    return (totalDelta / 8);
  }

  double _calculateDeltaHighest(
    List<double> currentData,
    List<double> referenceData,
  ) {
    if (currentData.isEmpty ||
        referenceData.isEmpty ||
        currentData.length < 8 ||
        referenceData.length < 8) {
      return 0.0;
    }

    double maxDeltaFx = 0.0;
    bool hasMeaningfulDelta = false;

    for (int i = 0; i < 8; i++) {
      double deltaFx = (currentData[i] - referenceData[i]);
      if (!hasMeaningfulDelta || deltaFx.abs() > maxDeltaFx.abs()) {
        maxDeltaFx = deltaFx;
        hasMeaningfulDelta = true;
      }
    }
    return maxDeltaFx;
  }

  double _calculateDeltaFx(
    int index,
    List<double> currentData,
    List<double> referenceData,
  ) {
    if (index < 0 ||
        index >= currentData.length ||
        index >= referenceData.length ||
        currentData.isEmpty ||
        referenceData.isEmpty) {
      return 0.0;
    }
    double delta = currentData[index] - referenceData[index];
    return delta;
  }

  @override
  void dispose() {
    _connectionService.onDataReceived = null;
    print("CompareModePage: onDataReceived listener cleared in dispose.");
    super.dispose();
  }

  String _getChannelName(int index) {
    if (index >= 0 && index < 8) {
      return "F${index + 1}";
    } else if (index == 8) {
      return "Clear";
    } else if (index == 9) {
      return "NIR";
    }
    return "";
  }

  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case "purple":
        return Colors.purple;
      case "navy":
        return Colors.indigo;
      case "blue":
        return Colors.blue;
      case "aqua":
        return Colors.cyan;
      case "green":
        return Colors.green;
      case "yellow":
        return Colors.yellow;
      case "orange":
        return Colors.orange;
      case "red":
        return Colors.red;
      case "white light":
      case "white":
        return Colors.white;
      case "infrared":
      case "black":
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          elevation: 0.0,
          backgroundColor: Colors.transparent,
          child: Container(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Channel Characteristics",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16.0),
                SizedBox(
                  height: 380,
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.5),
                      },
                      border: TableBorder.all(color: Colors.grey.shade300),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                          ),
                          children: const [
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Wave Length",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Color",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        for (var char in _channelCharacteristics)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  char["Channel"]!,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  char["Rentang Jangkauan"]!,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Center(
                                  child:
                                      char["Representasi"] == "Infrared"
                                          ? const Text(
                                            "Infrared",
                                            style: TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                          )
                                          : Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: _getColorFromName(
                                                char["Representasi"]!,
                                              ),
                                              border: Border.all(
                                                color:
                                                    char["Representasi"] ==
                                                            "White"
                                                        ? Colors.black
                                                        : Colors.transparent,
                                                width:
                                                    char["Representasi"] ==
                                                            "White"
                                                        ? 1.0
                                                        : 0.0,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4.0),
                                            ),
                                          ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<FlSpot> currentChartDataForDisplay;
    List<FlSpot> referenceChartDataForDisplay;

    List<double> currentDataForCalculation;
    List<double> referenceDataForCalculation;

    int decimalPlaces =
        _currentCompareGraphView == CompareGraphView.processedData ? 3 : 1;

    if (_currentCompareGraphView == CompareGraphView.rawData) {
      currentChartDataForDisplay =
          _currentSpectrumValues.sublist(0, 8).asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble() + 1, entry.value);
          }).toList();

      referenceChartDataForDisplay = _redChartData;

      currentDataForCalculation = _currentSpectrumValues;
      referenceDataForCalculation = _referenceSpectrumValues;
    } else {
      currentChartDataForDisplay =
          _currentBasicCounts.sublist(0, 8).asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble() + 1, entry.value);
          }).toList();

      referenceChartDataForDisplay =
          _referenceDataSensorCorr.sublist(0, 8).asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble() + 1, entry.value);
          }).toList();

      currentDataForCalculation = _currentDataSensorCorr;
      referenceDataForCalculation = _referenceDataSensorCorr;
    }

    double deltaAvg = _calculateDeltaAvg(
      currentDataForCalculation,
      referenceDataForCalculation,
    );
    double deltaHighest = _calculateDeltaHighest(
      currentDataForCalculation,
      referenceDataForCalculation,
    );

    String highestInfo = "";
    if (currentDataForCalculation.isNotEmpty &&
        referenceDataForCalculation.isNotEmpty &&
        currentDataForCalculation.length >= 8 &&
        referenceDataForCalculation.length >= 8) {
      double maxDeltaFxVal = 0.0;
      int maxDeltaFxIndex = -1;
      bool hasMeaningfulDelta = false;

      for (int i = 0; i < 8; i++) {
        double deltaFx =
            (currentDataForCalculation[i] - referenceDataForCalculation[i]);
        if (!hasMeaningfulDelta || deltaFx.abs() > maxDeltaFxVal.abs()) {
          maxDeltaFxVal = deltaFx;
          maxDeltaFxIndex = i + 1;
          hasMeaningfulDelta = true;
        }
      }
      highestInfo = " (${maxDeltaFxIndex != -1 ? 'F$maxDeltaFxIndex' : 'N/A'})";
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Removed FirebaseStreamer widget
          GestureDetector(
            onTap: widget.toggleConnectionMode, // CHANGED
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                // Update colors based on isBluetoothMode
                color: widget.isBluetoothMode ? Colors.blue : Colors.green,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    // Update icons based on isBluetoothMode
                    widget.isBluetoothMode ? Icons.bluetooth : Icons.cable,
                    color: Colors.white,
                    size: 24.0,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    // Update text based on isBluetoothMode
                    widget.isBluetoothMode
                        ? "Bluetooth Mode"
                        : "Cable Serial Mode",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentCompareGraphView = CompareGraphView.rawData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentCompareGraphView == CompareGraphView.rawData
                              ? Colors.blue
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Raw Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentCompareGraphView =
                            CompareGraphView.processedData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentCompareGraphView ==
                                  CompareGraphView.processedData
                              ? Colors.blue
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Processed Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 16.0, right: 16.0),
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
            child: Center(
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: SpectrumChart(
                  showGraph: true,
                  colorChartData: currentChartDataForDisplay,
                  redChartData: referenceChartDataForDisplay,
                ),
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
            padding: const EdgeInsets.all(8.0),
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
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "---",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      " Measured Data",
                      style: TextStyle(color: Color.fromARGB(255, 85, 85, 85)),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "---",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const Text(
                      " Reference Data",
                      style: TextStyle(color: Color.fromARGB(255, 85, 85, 85)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 16.0, bottom: 4.0),
            child: Text(
              "Comparing to reference data :",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          GestureDetector(
            onTap: _selectReferenceData,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.blue,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.data_saver_on,
                    color: Colors.white,
                    size: 24.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      "Reference : $_referenceTimestamp",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    right: 8.0,
                    left: 16.0,
                    bottom: 8.0,
                  ),
                  padding: const EdgeInsets.all(8.0),
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
                      const Icon(Icons.add_chart, color: Colors.blue),
                      Text(
                        deltaAvg.toStringAsFixed(decimalPlaces),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color:
                              deltaAvg.isNegative ? Colors.red : Colors.green,
                        ),
                      ),
                      const Text(
                        " ΔAvg",
                        style: TextStyle(
                          color: Color.fromARGB(255, 85, 85, 85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    right: 16.0,
                    left: 8.0,
                    bottom: 8.0,
                  ),
                  padding: const EdgeInsets.all(8.0),
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
                      const Icon(Icons.trending_up, color: Colors.blue),
                      Text(
                        "${deltaHighest.toStringAsFixed(decimalPlaces)}$highestInfo",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color:
                              deltaHighest.isNegative
                                  ? Colors.red
                                  : Colors.green,
                        ),
                      ),
                      const Text(
                        " ΔHighest",
                        style: TextStyle(
                          color: Color.fromARGB(255, 85, 85, 85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              border: TableBorder.all(color: Colors.grey.shade300),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Channel",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Difference (Δ)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                for (int i = 0; i < 8; i++)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "F${i + 1}",
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _calculateDeltaFx(
                            i,
                            currentDataForCalculation,
                            referenceDataForCalculation,
                          ).toStringAsFixed(decimalPlaces),
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _calculateDeltaFx(
                                      i,
                                      currentDataForCalculation,
                                      referenceDataForCalculation,
                                    ).isNegative
                                    ? Colors.red
                                    : Colors.green,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showAboutDialog(context),
            child: Container(
              margin: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16,
              ),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.purple,
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 24.0),
                  SizedBox(width: 8.0),
                  Text(
                    "About Channels",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
