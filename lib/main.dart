import 'package:flutter/material.dart';
import 'screens/tracking_screen.dart';

void main() {
  runApp(const OfflineRideTrackerApp());
}

class OfflineRideTrackerApp extends StatelessWidget {
  const OfflineRideTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Ride Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TrackingScreen(),
    );
  }
}
