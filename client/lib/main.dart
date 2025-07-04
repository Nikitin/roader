import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

// URL вашего бэкенда. Убедитесь, что он доступен с телефона.
// Используем https, так как ваш сервер настроен на SSL.
const String backendUrl = 'https://nikitin.by/roader/api/ingest/';

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

  // ИСПРАВЛЕНИЕ 1: Инициализация пустого списка
  final List<Map<String, dynamic>> _dataBuffer = [];
  Timer? _uploadTimer;

  Position? _currentPosition;
  UserAccelerometerEvent? _latestAccelerometerEvent;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Geolocator сам обрабатывает запросы разрешений, но для sensors лучше запросить явно.
    await Permission.sensors.request();
    // Проверим и запросим разрешение на геолокацию
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  void _startRecording() {
    // Starting the GPS
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Обновление при смещении на 1 метр.
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
        if (_currentPosition != null) {
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
    _uploadData(); // Загрузить оставшиеся точки данных
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

      if (response.statusCode == 202) { // Accepted
        print('Успешно загружено ${dataToSend.length} точек данных.');
      } else {
        print('Ошибка загрузки данных. Код состояния: ${response.statusCode}');
        print('Тело ответа: ${response.body}');
        // Возвращаем данные в буфер при ошибке
        _dataBuffer.addAll(dataToSend);
      }
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
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
          // ИСПРАВЛЕНИЕ 2: Добавлены виджеты для отображения информации
          children: <Widget>[
            Text(
              _isRecording ? 'Запись активна' : 'Нажмите Play для начала записи',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text('Точек в буфере: ${_dataBuffer.length}'),
            const SizedBox(height: 10),
            if (_currentPosition != null)
              Text('GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'),
            if (_latestAccelerometerEvent != null)
              Text('Акселерометр: X: ${_latestAccelerometerEvent!.x.toStringAsFixed(2)}, Y: ${_latestAccelerometerEvent!.y.toStringAsFixed(2)}, Z: ${_latestAccelerometerEvent!.z.toStringAsFixed(2)}'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleRecording,
        tooltip: 'Toggle Recording',
        child: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}