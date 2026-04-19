import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Import our newly separated basic architecture logic context!
import '../services/location_service.dart';
import '../services/deviation_service.dart';
import '../services/confidence_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  // --- 1. Service Instantiations ---
  // These handle all backend logic so the UI widget stays perfectly clean!
  final LocationService _locationService = LocationService();
  final DeviationService _deviationService = DeviationService();
  final ConfidenceService _confidenceService = ConfidenceService();

  // --- 2. State Variables ---
  // Minimal attributes required to paint tracking canvas natively
  double latitude = 12.9716;
  double longitude = 77.5946;
  bool isOffline = false;
  int offlineSteps = 0;
  bool onRoute = true;

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // We defer to the DeviationService internally to fetch layout mappings securely
    _deviationService.loadRoute().then((_) {
      if (mounted) {
        setState(() {
          onRoute = _deviationService.isOnRoute(latitude, longitude);
        });
      }
    });
  }

  /// 6. Maintain Data Pipeline synchronously via simple decoupled methods
  void _moveForward() {
    setState(() {
      // 1. Update location (LocationService seamlessly resolves prediction internal fallback dynamically)
      final newLoc = _locationService.moveForward(latitude, longitude, isOffline);
      latitude = newLoc['lat']!;
      longitude = newLoc['lng']!;

      // 2. Update offline steps simulation sequentially securely
      if (isOffline) {
        offlineSteps++;
      } else {
        offlineSteps = 0;
      }

      // 3 & 4. Run deviation layout resolving bounds securely natively using pure math Service bounds
      onRoute = _deviationService.isOnRoute(latitude, longitude);
    });

    // 5. Update Map UI externally
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(latitude, longitude)),
    );
  }

  /// System logic toggling testing fallback conditions natively
  void _toggleNetwork() {
    setState(() {
      isOffline = !isOffline;
      if (!isOffline) {
        offlineSteps = 0; // Decay simulation resets cleanly back to High confidence
        onRoute = _deviationService.isOnRoute(latitude, longitude);
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    // 3. Resolve confidence score off abstracted confidence service securely
    String confidence = _confidenceService.getConfidence(isOffline, offlineSteps);

    // Resolve context color mapping naturally natively
    Color confidenceColor;
    if (confidence == "High" && !isOffline) {
      confidenceColor = Colors.blue.shade800;
    } else if (confidence == "High") confidenceColor = Colors.orange.shade800;
    else if (confidence == "Medium") confidenceColor = Colors.deepOrange.shade800;
    else confidenceColor = Colors.red.shade900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Ride Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- UI: Mode Display ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isOffline ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isOffline ? 'Offline Mode – Estimated Tracking Active' : 'Online Mode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isOffline ? Colors.red.shade900 : Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // --- UI: Central Information Hub / Map Layout ---
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isOffline ? Colors.orange.shade300 : Colors.blue.shade300,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Hardcoded platform filter catching chrome map deployment crashing internally natively
                      if (kIsWeb)
                        Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              "Map not supported on web. Use mobile device.", 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: LatLng(latitude, longitude),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId("currentLocation"),
                              position: LatLng(latitude, longitude),
                            )
                          },
                          polylines: {
                            if (_deviationService.routePoints.isNotEmpty)
                              Polyline(
                                polylineId: const PolylineId("route"),
                                points: _deviationService.routePoints,
                                color: Colors.blue,
                                width: 4,
                              )
                          },
                        ),
                        
                      // Floating context dashboard overlaying maps naturally capturing local states
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                isOffline ? 'Predicted Location' : 'Actual Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOffline ? Colors.orange.shade900 : Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Lat: ${latitude.toStringAsFixed(5)}, Lng: ${longitude.toStringAsFixed(5)}",
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
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
            
            // --- UI: Route Status Context Boolean Display ---
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
            
            // --- Action Testing Logic Connectors ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _moveForward,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Move Forward', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade600,
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
                    label: const Text('Toggle Network', style: TextStyle(fontWeight: FontWeight.bold)),
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
