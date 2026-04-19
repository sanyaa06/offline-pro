import 'location_service.dart';
import 'network_service.dart';
import 'prediction_service.dart';

class OfflineService {
  final LocationService locationService;
  final NetworkService networkService;
  final PredictionService predictionService;

  Map<String, double>? _lastKnownLocation;

  OfflineService({
    required this.locationService,
    required this.networkService,
    required this.predictionService,
  });

  /// Automatically fetches the correct location data based on network connectivity.
  /// Detects if offline and falls back to predictive processing seamlessly.
  Map<String, double>? getTrackingLocation() {
    if (networkService.isOnline()) {
      // Network is available, fetch accurate location
      _lastKnownLocation = locationService.getCurrentLocation();
    } else {
      // Network lost: Switch to prediction mode utilizing last known data
      if (_lastKnownLocation != null) {
         _lastKnownLocation = predictionService.predictNextLocation(
           _lastKnownLocation!['latitude']!,
           _lastKnownLocation!['longitude']!
         );
      }
    }
    
    return _lastKnownLocation;
  }
}
