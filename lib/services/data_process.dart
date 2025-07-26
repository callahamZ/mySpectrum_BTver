import 'dart:math';

class DataProcessor {
  // Constant values for normalization
  static const double _normalizingFactor = 256.0 * 280.78;

  // Constants for Sensor Correction (now 10 channels: F1-F8, Clear, NIR)
  static const List<double> _corrSensorOffset = [
    0.00197, 0.00725, 0.00319, 0.00131, 0.00147, 0.00186, 0.00176, 0.00522,
    0.00300, // Clear (from image)
    0.00100, // NIR (from image)
  ];

  static const List<double> _corrSensorFactor = [
    1.02811, 1.03149, 1.03142, 1.03125, 1.03390, 1.03445, 1.03508, 1.03359,
    1.23384, // Clear (from image)
    1.26942, // NIR (from image)
  ];

  // Getter for individual Corr Sensor Offset
  static double getCorrSensorOffset(int index) {
    if (index >= 0 && index < _corrSensorOffset.length) {
      return _corrSensorOffset[index];
    }
    return 0.0; // Return default or throw error if index is out of bounds
  }

  // Getter for individual Corr Sensor Factor
  static double getCorrSensorFactor(int index) {
    if (index >= 0 && index < _corrSensorFactor.length) {
      return _corrSensorFactor[index];
    }
    return 0.0; // Return default or throw error if index is out of bounds
  }

  /// Calculates the "Basic Count" for a list of raw spectrum data values.
  /// Basic Count = raw_data_F_value / (256 * 280.78)
  ///
  /// [rawSpectrumData] A list of raw double values (e.g., F1 to F8, Clear, NIR).
  /// Returns a new list containing the calculated Basic Count for each raw value.
  static List<double> calculateBasicCount(List<double> rawSpectrumData) {
    if (rawSpectrumData.isEmpty) {
      return List.filled(
        _corrSensorOffset.length,
        0.0,
      ); // Return filled list if empty input
    }

    // Ensure rawSpectrumData length matches the constants length for consistency
    int effectiveLength = min(rawSpectrumData.length, _corrSensorOffset.length);
    List<double> basicCounts = [];
    for (int i = 0; i < effectiveLength; i++) {
      basicCounts.add(rawSpectrumData[i] / _normalizingFactor);
    }
    // Pad with zeros if rawSpectrumData was shorter than the expected 10 channels
    while (basicCounts.length < _corrSensorOffset.length) {
      basicCounts.add(0.0);
    }
    return basicCounts;
  }

  /// Calculates "Data Sensor (Corr)" values for each channel.
  /// Data Sensor (Corr) = Corr Sensor Factor * (Basic Count - Corr Sensor Offset)
  ///
  /// [basicCounts] A list of Basic Count values for each channel.
  /// Returns a new list containing the calculated Data Sensor (Corr) values.
  static List<double> calculateDataSensorCorr(List<double> basicCounts) {
    if (basicCounts.isEmpty || basicCounts.length != _corrSensorOffset.length) {
      return List.filled(_corrSensorOffset.length, 0.0);
    }

    List<double> dataSensorCorr = [];
    for (int i = 0; i < basicCounts.length; i++) {
      double value =
          _corrSensorFactor[i] * (basicCounts[i] - _corrSensorOffset[i]);
      dataSensorCorr.add(value);
    }
    return dataSensorCorr;
  }

  static List<double> multiplyVectorMatrix(
    List<double> dataSensorCorr,
    List<List<double>> matrix,
  ) {
    if (dataSensorCorr.isEmpty || matrix.isEmpty || matrix[0].isEmpty) {
      // Handle empty inputs or invalid matrix dimensions
      return [];
    }

    int numRowsMatrix = matrix.length; // N
    int numColsMatrix = matrix[0].length; // M
    int vectorLength = dataSensorCorr.length; // M

    // Check if the inner dimensions match for multiplication (1xM * NxM is not standard)
    // For vector * matrix, generally columns of vector must match rows of matrix, or
    // we're doing a dot product of vector with each row of the matrix.
    // Given correctionMatrix is 336x10 and dataSensorCorr is 10,
    // the most likely intended operation is dataSensorCorr * transpose(correctionMatrix).
    // This results in a 1x336 vector.

    if (vectorLength != numColsMatrix) {
      // If the vector length (10) doesn't match the number of columns in the matrix (10),
      // then the multiplication as a dot product with rows won't work.
      // This check ensures that dataSensorCorr can be multiplied by each row of the matrix.
      print("Error: Incompatible dimensions for multiplication.");
      print("Vector length: $vectorLength");
      print("Matrix columns: $numColsMatrix");
      return [];
    }

    List<double> resultVector = List.filled(
      numRowsMatrix,
      0.0,
    ); // Result will have N elements

    // Perform the multiplication: result[i] = sum(dataSensorCorr[j] * matrix[i][j])
    for (int i = 0; i < numRowsMatrix; i++) {
      // Iterate through each row of the matrix (N rows)
      double sum = 0.0;
      for (int j = 0; j < numColsMatrix; j++) {
        // Iterate through each element in the row (M columns)
        sum += dataSensorCorr[j] * matrix[i][j]; //
      }
      resultVector[i] = sum;
    }
    return resultVector;
  }

  static List<double> calculateXYZ(
    List<double> reconstructedSpectrum,
    List<double> nStandardValue,
  ) {
    if (reconstructedSpectrum.isEmpty) {
      return List.filled(nStandardValue.length, 0.0);
    }

    List<double> calculatedXYZ = [];
    for (int i = 0; i < nStandardValue.length; i++) {
      calculatedXYZ.add(reconstructedSpectrum[i] * nStandardValue[i]);
    }

    return calculatedXYZ;
  }

  /// Calculates "Data Sensor (Corr/Nor)" values for each channel.
  /// Data Sensor (Corr/Nor) = Data Sensor (Corr) / max(Data Sensor Corr)
  ///
  /// [dataSensorCorr] A list of Data Sensor (Corr) values.
  /// Returns a new list containing the calculated Data Sensor (Corr/Nor) values.
  static List<double> calculateDataSensorCorrNor(List<double> dataSensorCorr) {
    if (dataSensorCorr.isEmpty) {
      return List.filled(_corrSensorOffset.length, 0.0);
    }

    double maxDataSensorCorr = 0.0;
    // Find the maximum absolute value for normalization to handle negative values correctly
    for (var val in dataSensorCorr) {
      if (val.abs() > maxDataSensorCorr.abs()) {
        maxDataSensorCorr = val.abs();
      }
    }

    if (maxDataSensorCorr == 0) {
      return List.filled(dataSensorCorr.length, 0.0); // Avoid division by zero
    }

    return dataSensorCorr.map((value) {
      return value / maxDataSensorCorr;
    }).toList();
  }

  /// Applies linear regression to raw temperature data.
  static double processTemperature(double rawTemperature) {
    return 1.3605 + 0.9691 * rawTemperature;
  }

  /// Applies linear regression to raw lux data.
  static double processLux(double rawLux) {
    return -3.563 + 0.2144 * rawLux;
  }
}
