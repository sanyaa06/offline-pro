import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeviationService {
  List<LatLng> routePoints = [];

  /// Asynchronously loads predefined valid node routes
  Future<void> loadRoute() async {
    try {
      final String jsonStr = await rootBundle.loadString('assets/route_data.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      
      routePoints = jsonList.map((e) => LatLng(
        (e['lat'] as num).toDouble(),
        (e['lng'] as num).toDouble(),
      )).toList();
    } catch (e) {
      debugPrint("Error loading route data: $e");
    }
  }

  /// Calculates mathematically if coordinates geometrically deviate from route path scope
  bool isOnRoute(double lat, double lng) {
    if (routePoints.isEmpty) return true; // Failsafe until fully loaded
    
    // Bounds check mechanism against all standard point vectors
    for (var point in routePoints) {
      if ((lat - point.latitude).abs() < 0.001 && (lng - point.longitude).abs() < 0.001) {
        return true;
      }
    }
    return false;
  }
}
