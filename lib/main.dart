import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/tracking_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await dotenv.load(fileName: '.env');
  // Initialize the flutter_map_tile_caching store used by the app
  // Tile caching plugin can be initialized here if desired (FMTC API).
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
