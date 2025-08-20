import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spectrumapp/services/connection_service.dart';
import 'package:spectrumapp/services/graph_framework.dart';
import 'package:spectrumapp/services/database_service.dart';
import 'package:spectrumapp/services/data_process.dart';
import 'package:spectrumapp/services/correction_matrix.dart';
import 'dart:math';

enum GraphView { rawData, processedData, cieData }

class HomePageContent extends StatefulWidget {
  final bool isBluetoothMode;
  final VoidCallback toggleConnectionMode;

  const HomePageContent({
    super.key,
    required this.isBluetoothMode,
    required this.toggleConnectionMode,
  });

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  // State variables for UI display
  List<FlSpot> _chartData = [];
  String _temperature = "N/A";
  String _lux = "N/A";
  List<double> _basicCounts = List.filled(10, 0.0);
  List<double> _dataSensorCorr = List.filled(10, 0.0);
  List<double> _dataSensorCorrNor = List.filled(10, 0.0);
  List<double> _finalCorrectedData = List.filled(correctionMatrix.length, 0.0);
  List<double> _calculatedX = List.filled(XN.length, 0.0);
  List<double> _calculatedY = List.filled(YN.length, 0.0);
  List<double> _calculatedZ = List.filled(ZN.length, 0.0);

  double _cieX = 0.0;
  double _cieY = 0.0;
  double _cieZ = 0.0;
  String _cieSmallX = "N/A";
  String _cieSmallY = "N/A";
  String _cieSmallZ = "N/A";
  String _spectralLux = "N/A";

  List<FlSpot> _cieChartSpots = [];

  GraphView _currentGraphView = GraphView.rawData;

  final ConnectionService _connectionService = ConnectionService();

  // Rate limiting variables to prevent UI from lagging on fast data streams
  static const Duration _updateInterval = Duration(milliseconds: 100);
  DateTime _lastUpdate = DateTime.now();

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
    _connectionService.onDataReceived = _updateReceivedData;
    _loadLatestLocalData();
    print(
      "HomePage: Initializing with _loadLatestLocalData and setting onDataReceived.",
    );
  }

  @override
  void didUpdateWidget(covariant HomePageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBluetoothMode != oldWidget.isBluetoothMode) {
      _clearAllData();
      _loadLatestLocalData();
      print(
        "HomePage: Connection mode changed, cleared data and reloaded latest.",
      );
    }
  }

  void _clearAllData() {
    if (!mounted) return;
    setState(() {
      _chartData = [];
      _temperature = "N/A";
      _lux = "N/A";
      _basicCounts = List.filled(10, 0.0);
      _dataSensorCorr = List.filled(10, 0.0);
      _dataSensorCorrNor = List.filled(10, 0.0);
      _finalCorrectedData = List.filled(correctionMatrix.length, 0.0);
      _calculatedX = List.filled(XN.length, 0.0);
      _calculatedY = List.filled(YN.length, 0.0);
      _calculatedZ = List.filled(ZN.length, 0.0);
      _cieX = 0.0;
      _cieY = 0.0;
      _cieZ = 0.0;
      _cieSmallX = "N/A";
      _cieSmallY = "N/A";
      _cieSmallZ = "N/A";
      _spectralLux = "N/A";
      _cieChartSpots = [];
      print("All data cleared.");
    });
  }

  void _updateReceivedData(
    List<double> rawSpektrumData,
    double temperature,
    double lux,
  ) {
    if (!mounted) return;

    // Perform heavy calculations outside of setState
    double processedTemperature = DataProcessor.processTemperature(temperature);
    double processedLux = DataProcessor.processLux(lux);

    List<FlSpot> chartData =
        rawSpektrumData.sublist(0, 8).asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble() + 1, entry.value);
        }).toList();

    List<double> basicCounts = DataProcessor.calculateBasicCount(
      rawSpektrumData,
    );
    List<double> dataSensorCorr = DataProcessor.calculateDataSensorCorr(
      basicCounts,
    );
    List<double> dataSensorCorrNor = DataProcessor.calculateDataSensorCorrNor(
      dataSensorCorr,
    );

    List<double> finalCorrectedData = DataProcessor.multiplyVectorMatrix(
      dataSensorCorr,
      correctionMatrix,
    );

    List<double> calculatedX = DataProcessor.calculateXYZ(
      finalCorrectedData,
      XN,
    );
    List<double> calculatedY = DataProcessor.calculateXYZ(
      finalCorrectedData,
      YN,
    );
    List<double> calculatedZ = DataProcessor.calculateXYZ(
      finalCorrectedData,
      ZN,
    );

    double cieX = calculatedX.fold(0.0, (sum, item) => sum + item);
    double cieY = calculatedY.fold(0.0, (sum, item) => sum + item);
    double cieZ = calculatedZ.fold(0.0, (sum, item) => sum + item);

    String cieSmallX = "N/A";
    String cieSmallY = "N/A";
    String cieSmallZ = "N/A";
    double sumXYZ = cieX + cieY + cieZ;
    if (sumXYZ > 0) {
      cieSmallX = (cieX / sumXYZ).toStringAsFixed(4);
      cieSmallY = (cieY / sumXYZ).toStringAsFixed(4);
      cieSmallZ = (cieZ / sumXYZ).toStringAsFixed(4);
    }

    String spectralLux = (cieY * 683).toStringAsFixed(2);

    if (DateTime.now().difference(_lastUpdate) > _updateInterval) {
      setState(() {
        _chartData = chartData;
        _temperature = processedTemperature.toStringAsFixed(1);
        _lux = processedLux.toStringAsFixed(1);
        _basicCounts = basicCounts;
        _dataSensorCorr = dataSensorCorr;
        _dataSensorCorrNor = dataSensorCorrNor;
        _finalCorrectedData = finalCorrectedData;
        _calculatedX = calculatedX;
        _calculatedY = calculatedY;
        _calculatedZ = calculatedZ;
        _cieX = cieX;
        _cieY = cieY;
        _cieZ = cieZ;
        _cieSmallX = cieSmallX;
        _cieSmallY = cieSmallY;
        _cieSmallZ = cieSmallZ;
        _spectralLux = spectralLux;

        if (cieSmallX != "N/A" && cieSmallY != "N/A") {
          try {
            double x = double.parse(cieSmallX);
            double y = double.parse(cieSmallY);
            _cieChartSpots.add(FlSpot(x, y));
            if (_cieChartSpots.length > 50) {
              _cieChartSpots.removeAt(0);
            }
          } catch (e) {
            print("Error parsing CIE x,y values: $e");
          }
        }
        _lastUpdate = DateTime.now();
      });
      print(
        "HomePage: Data processed and state updated. FPS is more stable now",
      );
    }
  }

  Future<void> _loadLatestLocalData() async {
    final latestMeasurement =
        await DatabaseHelper.instance.getLatestMeasurement();
    if (latestMeasurement != null) {
      if (!mounted) return;

      final spectrumDataString =
          latestMeasurement[DatabaseHelper.columnSpectrumData] as String?;
      List<double> rawSpectrumData = [];
      if (spectrumDataString != null && spectrumDataString.isNotEmpty) {
        rawSpectrumData =
            spectrumDataString.split(',').map((e) => double.parse(e)).toList();
      } else {
        rawSpectrumData = List.filled(10, 0.0);
      }

      double rawTemperature =
          (latestMeasurement[DatabaseHelper.columnTemperature] as double?) ??
          0.0;
      double rawLux =
          (latestMeasurement[DatabaseHelper.columnLux] as double?) ?? 0.0;

      // Call the data processing logic
      _updateReceivedData(rawSpectrumData, rawTemperature, rawLux);

      print("HomePage: Local data loaded and state updated.");
    } else {
      _clearAllData();
      print("HomePage: No latest local measurement found, clearing data.");
    }
  }

  @override
  void dispose() {
    _connectionService.onDataReceived = null;
    print("HomePage: onDataReceived listener cleared in dispose.");
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
    List<FlSpot> basicCountChartData =
        _basicCounts.sublist(0, 8).asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble() + 1, entry.value);
        }).toList();

    List<FlSpot> dataSensorCorrChartData =
        _dataSensorCorr.sublist(0, 8).asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble() + 1, entry.value);
        }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.toggleConnectionMode,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
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
                    widget.isBluetoothMode ? Icons.bluetooth : Icons.cable,
                    color: Colors.white,
                    size: 24.0,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentGraphView = GraphView.rawData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentGraphView == GraphView.rawData
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
                        _currentGraphView = GraphView.processedData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentGraphView == GraphView.processedData
                              ? Colors.blue
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Calc Data',
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
                        _currentGraphView = GraphView.cieData;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentGraphView == GraphView.cieData
                              ? Colors.blue
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'CIE 1931',
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
                child:
                    _currentGraphView == GraphView.rawData
                        ? SpectrumChart(
                          showGraph: true,
                          colorChartData: _chartData,
                        )
                        : _currentGraphView == GraphView.processedData
                        ? SpectrumChart(
                          showGraph: true,
                          colorChartData: basicCountChartData,
                          secondLineData: dataSensorCorrChartData,
                        )
                        : Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/CIE1931_bg.png',
                                fit: BoxFit.fitWidth,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Text(
                                      'Error loading image',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SpectrumChart(
                              showGraph: true,
                              thirdLineData: _cieChartSpots,
                              minXOverride: 0.0,
                              maxXOverride: 0.8,
                              minYOverride: 0.0,
                              maxYOverride: 0.9,
                              isCIEChart: true,
                            ),
                          ],
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("---", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      " Raw Measured Data",
                      style: TextStyle(color: Color.fromARGB(255, 85, 85, 85)),
                    ),
                  ],
                ),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "---",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      " Calibrated Data",
                      style: TextStyle(color: Color.fromARGB(255, 85, 85, 85)),
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
                top: 16,
                bottom: 8,
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
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 16.0,
                    right: 8.0,
                    top: 16.0,
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
                      const Icon(Icons.thermostat, color: Colors.blueAccent),
                      Text(
                        " $_temperature° C",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        " Suhu",
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
                    top: 8.0,
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
                      const Icon(Icons.brightness_medium, color: Colors.blue),
                      Text(
                        " $_lux Lux",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const Text(
                        " Cahaya",
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
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 8.0,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CIE 1931 Calculated Values",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8.0),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(1),
                  },
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Sum X:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieX.toStringAsFixed(5)),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Sum Y:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieY.toStringAsFixed(5)),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Sum Z:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieZ.toStringAsFixed(5)),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "x:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieSmallX),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "y:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieSmallY),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "z:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_cieSmallZ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Spectral Lux:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("$_spectralLux lm"),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              "Calculations",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Measured Data Correction",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8.0),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                  },
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: const [
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Channel",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Basic Count",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Data Sensor (Corr)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Data Sensor (Corr/Nor)",
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
                    for (int i = 0; i < _basicCounts.length; i++)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _getChannelName(i),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _basicCounts[i].toStringAsFixed(5),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _dataSensorCorr[i].toStringAsFixed(5),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _dataSensorCorrNor[i].toStringAsFixed(5),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 8.0,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Spectral Reconstruction",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _finalCorrectedData.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(3),
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
                                      "Wavelength",
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
                                      "Sensor Reconstruction",
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
                          ],
                        );
                      }
                      int dataIndex = index - 1;
                      return Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(3),
                        },
                        border: TableBorder.all(color: Colors.grey.shade300),
                        children: [
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  (dataIndex + 380).toString(),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _finalCorrectedData[dataIndex]
                                      .toStringAsFixed(5),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 8.0,
              bottom: 16.0,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Calculated XYZ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _calculatedX.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(2),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(2),
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
                                      "Wavelength",
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
                                      "X",
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
                                      "Y",
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
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      "Z",
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
                          ],
                        );
                      }
                      int dataIndex = index - 1;
                      return Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2),
                        },
                        border: TableBorder.all(color: Colors.grey.shade300),
                        children: [
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  (dataIndex + 380).toString(),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _calculatedX[dataIndex].toStringAsFixed(5),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _calculatedY[dataIndex].toStringAsFixed(5),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _calculatedZ[dataIndex].toStringAsFixed(5),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
