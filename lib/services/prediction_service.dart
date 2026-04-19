class PredictionService {
  /// Predicts the next coordinates assuming a constant extrapolation
  Map<String, double> predictNext(double lat, double lng) {
    // Slower or estimated movement simulates offline estimation ticks
    return {
      'lat': lat + 0.0003,
      'lng': lng + 0.0003,
    };
  }
}
