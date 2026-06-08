import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/deviation_service.dart';
import '../services/confidence_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final LocationService _locationService = LocationService();
  final DeviationService _deviationService = DeviationService();
  final ConfidenceService _confidenceService = ConfidenceService();

  double latitude = 12.9716;
  double longitude = 77.5946;
  bool isOffline = false;
  int offlineSteps = 0;
  bool onRoute = true;
  bool isLoadingRoute = false;

  final MapController _mapController = MapController();
  final double _mapZoom = 19;

  final List<LatLng> _routeHistory = [];
  final List<LatLng> _expectedRoutePoints = [];

  final TextEditingController _destinationController =
      TextEditingController();

  String? _destinationName;

  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();

    _deviationService.loadRoute().then((_) {
      if (mounted) {
        setState(() {
          onRoute = _isCurrentLocationOnExpectedRoute();
        });
      }
    });

    _initializeLocationTracking();
  }

  Future<void> _initializeLocationTracking() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint("Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint("Location permission denied.");
      return;
    }

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    if (!mounted) return;

    _updateLocation(position.latitude, position.longitude);
    _subscribeToPositionStream();
  }

  void _subscribeToPositionStream() {
    _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      debugPrint("LIVE GPS: ${position.latitude}, ${position.longitude}");

      if (!mounted || isOffline) return;

      _updateLocation(position.latitude, position.longitude);
    });
  }

  void _stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _updateLocation(double lat, double lng) {
    final LatLng newPoint = LatLng(lat, lng);

    setState(() {
      latitude = lat;
      longitude = lng;
      offlineSteps = 0;
      onRoute = _isCurrentLocationOnExpectedRoute();

      if (_routeHistory.isEmpty || _routeHistory.last != newPoint) {
        _routeHistory.add(newPoint);
      }
    });

    _mapController.move(newPoint, _mapZoom);
  }

  bool _isCurrentLocationOnExpectedRoute() {
    if (_expectedRoutePoints.isEmpty) {
      return true;
    }

    const Distance distance = Distance();
    final LatLng currentPoint = LatLng(latitude, longitude);

    double nearestDistance = double.infinity;

    for (final point in _expectedRoutePoints) {
      final double currentDistance = distance(currentPoint, point);
      if (currentDistance < nearestDistance) {
        nearestDistance = currentDistance;
      }
    }

    return nearestDistance <= 120;
  }

  Future<void> _navigateToDestination() async {
    final String destination = _destinationController.text.trim();

    if (destination.isEmpty) {
      return;
    }

    setState(() {
      isLoadingRoute = true;
    });

    try {
      final List<Location> locations = await locationFromAddress(destination);

      if (locations.isEmpty) {
        _showMessage("Destination not found");
        return;
      }

      final double destinationLat = locations.first.latitude;
      final double destinationLng = locations.first.longitude;

      final String url =
          'https://router.project-osrm.org/route/v1/driving/'
          '$longitude,$latitude;'
          '$destinationLng,$destinationLat'
          '?overview=full&geometries=geojson';

      final http.Response response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        _showMessage("Could not fetch route");
        return;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['routes'] == null || data['routes'].isEmpty) {
        _showMessage("No route found");
        return;
      }

      final List coordinates =
          data['routes'][0]['geometry']['coordinates'] as List;

      final List<LatLng> routePoints = coordinates
          .map(
            (coord) => LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            ),
          )
          .toList();

      setState(() {
        _destinationName = destination;
        _expectedRoutePoints
          ..clear()
          ..addAll(routePoints);
        onRoute = _isCurrentLocationOnExpectedRoute();
      });

      _showMessage("Route loaded to $destination");
    } catch (e) {
      debugPrint("Destination error: $e");
      _showMessage("Failed to load destination");
    } finally {
      if (mounted) {
        setState(() {
          isLoadingRoute = false;
        });
      }
    }
  }

  Future<void> _clearTileCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
    } catch (e) {
      debugPrint('ImageCache clear failed: $e');
    }

    _showMessage('Tile cache cleared');
  }

  void _moveForward() {
    final newLoc = _locationService.moveForward(
      latitude,
      longitude,
      isOffline,
    );

    final LatLng predictedPoint = LatLng(
      newLoc['lat']!,
      newLoc['lng']!,
    );

    setState(() {
      latitude = predictedPoint.latitude;
      longitude = predictedPoint.longitude;

      if (isOffline) {
        offlineSteps++;
      } else {
        offlineSteps = 0;
      }

      onRoute = _isCurrentLocationOnExpectedRoute();
      _routeHistory.add(predictedPoint);
    });

    _mapController.move(predictedPoint, _mapZoom);
  }

  void _toggleNetwork() {
    setState(() {
      isOffline = !isOffline;

      if (isOffline) {
        _stopLocationTracking();
        offlineSteps = 0;
      }
    });

    if (!isOffline) {
      _initializeLocationTracking();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String confidence =
        _confidenceService.getConfidence(isOffline, offlineSteps);

    Color confidenceColor;

    if (confidence == "High" && !isOffline) {
      confidenceColor = Colors.blue.shade800;
    } else if (confidence == "High") {
      confidenceColor = Colors.orange.shade800;
    } else if (confidence == "Medium") {
      confidenceColor = Colors.deepOrange.shade800;
    } else {
      confidenceColor = Colors.red.shade900;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Ride Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isOffline ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isOffline
                    ? 'Offline Mode – Estimated Tracking Active'
                    : 'Online Mode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isOffline ? Colors.red.shade900 : Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _destinationController,
                    decoration: const InputDecoration(
                      labelText: "Enter destination",
                      hintText: "Example: Jaipur Railway Station",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isLoadingRoute ? null : _navigateToDestination,
                  child: isLoadingRoute
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Go"),
                ),
              ],
            ),

            if (_destinationName != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Destination: $_destinationName",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isOffline
                          ? Colors.orange.shade300
                          : Colors.blue.shade300,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      if (kIsWeb)
                        Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              "Map not supported on web. Use mobile device.",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(latitude, longitude),
                            initialZoom: _mapZoom,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.offline_ride_tracker',
                            ),

                            if (_expectedRoutePoints.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _expectedRoutePoints,
                                    color: Colors.blue,
                                    strokeWidth: 4,
                                  ),
                                ],
                              ),

                            if (_routeHistory.length > 1)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _routeHistory,
                                    color: isOffline
                                        ? Colors.orange
                                        : Colors.green,
                                    strokeWidth: 5,
                                  ),
                                ],
                              ),

                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(latitude, longitude),
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOffline
                                    ? 'Predicted Location'
                                    : 'Actual Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOffline
                                      ? Colors.orange.shade900
                                      : Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Lat: ${latitude.toStringAsFixed(5)}, Lng: ${longitude.toStringAsFixed(5)}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Confidence: $confidence',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: confidenceColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Actual Points: ${_routeHistory.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Expected Points: ${_expectedRoutePoints.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: !onRoute ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                !onRoute ? 'Route Deviation Detected' : 'On Route',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: !onRoute ? Colors.red.shade900 : Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isOffline ? _moveForward : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      'Move Forward',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isOffline
                          ? Colors.blue.shade600
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearTileCache,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear Tile Cache'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleNetwork,
                    icon: Icon(isOffline ? Icons.wifi : Icons.wifi_off),
                    label: const Text(
                      'Toggle Network',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isOffline ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}