import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoadixApp());
}

class RoadixApp extends StatelessWidget {
  const RoadixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROADIX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _controller;

  // Free public vector style from OpenFreeMap
  static const String _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ROADIX'),
        centerTitle: true,
      ),
      body: MapLibreMap(
        styleString: _styleUrl,
        initialCameraPosition: const CameraPosition(
          target: LatLng(23.8103, 90.4125), // Centered on Dhaka
          zoom: 12.0,
        ),
        myLocationEnabled: true,
        myLocationTrackingMode: MyLocationTrackingMode.trackingCompass,
        onMapCreated: (controller) => _controller = controller,
      ),
    );
  }
}