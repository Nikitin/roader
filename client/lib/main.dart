import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

// URL of your backend. Replace with the IP or add of your server.
const String backendUrl = 'http://nikitin.by/roader/api/ingest/';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Road Quality Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isRecording = false;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _positionSubscription;
  
  final List<Map<String, dynamic>> _dataBuffer =;
  Timer? _uploadTimer;

  Position? _currentPosition;
  UserAccelerometerEvent? _latestAccelerometerEvent;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.sensors.request();
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
    setState(() {
      _isRecording =!_isRecording;
    });
  }

  void _startRecording() {
    // Starting the GPS
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Update with 1 meter interval.
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
    });

    // Starting the accelerometer
    _accelerometerSubscription = userAccelerometerEvents.listen(
      (UserAccelerometerEvent event) {
        _latestAccelerometerEvent = event;
        if (_currentPosition!= null) {
          _collectDataPoint(event, _currentPosition!);
        }
      },
    );

    // Starting the upload timer
    _uploadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _uploadData();
    });
  }

  void _stopRecording() {
    _accelerometerSubscription?.cancel();
    _positionSubscription?.cancel();
    _uploadTimer?.cancel();
    _uploadData(); // Upload any remaining data points
    setState(() {
      _currentPosition = null;
      _latestAccelerometerEvent = null;
    });
  }

  void _collectDataPoint(UserAccelerometerEvent accEvent, Position pos) {
    final dataPoint = {
      "timestamp": DateTime.now().toIso8601String(),
      "gps": {
        "latitude": pos.latitude,
        "longitude": pos.longitude,
        "speed": pos.speed,
        "accuracy": pos.accuracy,
      },
      "user_accelerometer": {
        "x": accEvent.x,
        "y": accEvent.y,
        "z": accEvent.z,
      },
    };
    _dataBuffer.add(dataPoint);
  }

  Future<void> _uploadData() async {
    if (_dataBuffer.isEmpty) return;

    final List<Map<String, dynamic>> dataToSend = List.from(_dataBuffer);
    _dataBuffer.clear();

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dataToSend),
      );

      if (response.statusCode == 202) {
        print('Successfully uploaded ${dataToSend.length} data points.');
      } else {
        print('Failed to upload data. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Re-add the data to the buffer if upload fails
        _dataBuffer.addAll(dataToSend);
      }
    } catch (e) {
      print('Error uploading data: $e');
      _dataBuffer.addAll(dataToSend);
    }
  }

  @override
  void dispose() {
    _stopRecording();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Quality Monitor'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleRecording,
        tooltip: 'Toggle Recording',
        child: Icon(_isRecording? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}