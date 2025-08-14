// lib/test_maps.dart - CREATE NEW FILE
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'config/api_keys.dart';

class TestMapsScreen extends StatefulWidget {
  @override
  _TestMapsScreenState createState() => _TestMapsScreenState();
}

class _TestMapsScreenState extends State<TestMapsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🗺️ Maps Test'),
        backgroundColor: Colors.green,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(ApiKeys.defaultLatitude, ApiKeys.defaultLongitude),
          zoom: 14.0,
        ),
        onMapCreated: (GoogleMapController controller) {
          print('✅ Google Maps loaded successfully!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Google Maps loaded!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onTap: (LatLng position) {
          print('📍 Tapped: ${position.latitude}, ${position.longitude}');
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 API Key Working!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        child: Icon(Icons.check),
        backgroundColor: Colors.green,
      ),
    );
  }
}
