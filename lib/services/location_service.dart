import 'prediction_service.dart';

class LocationService {
  final PredictionService _predictionService = PredictionService();

  /// Moves the tracker forward, querying PredictionService if currently offline
  Map<String, double> moveForward(double lat, double lng, bool isOffline) {
    if (isOffline) {
      // Delegate to prediction if no network context
      return _predictionService.predictNext(lat, lng);
    } else {
      // Return highly accurate mock GPS data (fast tick)
      return {
        'lat': lat + 0.0005,
        'lng': lng + 0.0005,
      };
    }
  }
}
