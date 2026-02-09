import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:network_info_plus/network_info_plus.dart';

class CarState extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;
  bool _isManuallyDisconnected = false;
  String distance = "--";
  String mode = "MANUAL";
  String carIp = "";
  String cameraIp = "";
  String deviceId = "Unbound";
  String relayServer = ""; // Relay server address (e.g., 1.2.3.4:8081)
  bool isRemoteMode = false;
  Locale locale = const Locale('en'); // Default to English
  List<Map<String, String>> discoveredDevices = [];
  bool isDiscovering = false;
  
  // New Status Fields
  double carBattery = 0.0; // Voltage
  int wifiSignal = -1; // dBm
  int latency = 0; // ms
  DateTime? _lastPingTime;
  Timer? _pingTimer;
  Timer? _autoConnectTimer;
  
  // Control State
  double maxSpeed = 0.7; 
  double patrolSpeed = 0.4;
  String sensitivity = "Medium";
  int speedLevel = 1; 
  double ultrasonicAngle = 90.0;
  
  // Vision State
  String resolution = "1080P";
  String nightMode = "Auto";
  String aiDetection = "All";
  double detectionSensitivity = 0.75;
  
  // Hardware State
  bool isLightOn = false;
  bool isHornOn = false;
  
  // Version Info
  String currentAppVersion = "1.0.0";
  String latestAppVersion = "1.0.0";
  String currentFirmwareVersion = "1.0.0";
  String latestFirmwareVersion = "1.0.0";
  String appUpdateLog = "";
  String firmwareUpdateLog = "";
  bool hasAppUpdate = false;
  bool hasFirmwareUpdate = false;
  
  // PTZ State
  double cameraAngle = 90.0;

  // Local OTA Server
  HttpServer? _localServer;
  bool isLocalServerRunning = false;
  String? localServerUrl;
  
  CarState() {
    _loadSettings();
    _startAutoConnectTimer();
    checkUpdates(); // Check updates on startup
  }

  Future<void> checkUpdates() async {
    // Simulate checking updates from server
    // In a real project, this should be an HTTP request
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulate finding App update
    latestAppVersion = "1.0.1";
    appUpdateLog = "1. Optimized auto-connection logic\n2. Fixed factory reset bug\n3. Improved remote control response speed";
    hasAppUpdate = latestAppVersion != currentAppVersion;
    
    // Simulate finding firmware update
    latestFirmwareVersion = "1.1.0";
    firmwareUpdateLog = "1. Enhanced WiFi stability\n2. Optimized motor PID control algorithm\n3. Added OTA upgrade support";
    hasFirmwareUpdate = latestFirmwareVersion != currentFirmwareVersion;
    
    notifyListeners();
  }

  void startDeviceOTA() {
    if (isConnected) {
      sendCommand({
        "cmd": "ota_start",
        "url": "http://update.robocar-a.com/firmware/v1.1.0.bin"
      });
    }
  }

  Future<void> startLocalOTA(File firmwareFile) async {
    if (!isConnected) return;

    try {
      // 1. Get phone IP in LAN
      final info = NetworkInfo();
      String? localIp = await info.getWifiIP();
      
      if (localIp == null) {
        debugPrint("Could not get local IP, please ensure WiFi is connected");
        return;
      }

      // 2. If there's an existing server, close it first
      await stopLocalServer();

      // 3. Start temporary HTTP server
      var handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler((Request request) async {
            if (request.url.path == 'firmware.bin') {
              final bytes = await firmwareFile.readAsBytes();
              return Response.ok(bytes, headers: {
                'content-type': 'application/octet-stream',
                'content-disposition': 'attachment; filename="firmware.bin"',
                'content-length': bytes.length.toString(),
              });
            }
            return Response.notFound('Not Found');
          });

      _localServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
      isLocalServerRunning = true;
      localServerUrl = "http://$localIp:8080/firmware.bin";
      debugPrint('Local firmware server started: $localServerUrl');

      // 4. Notify device to download from phone
      sendCommand({
        "cmd": "ota_start",
        "url": localServerUrl
      });
      
      notifyListeners();

      // 5. Auto timeout (10 minutes)
      Timer(const Duration(minutes: 10), () => stopLocalServer());
    } catch (e) {
      debugPrint("Failed to start local OTA server: $e");
      isLocalServerRunning = false;
      notifyListeners();
    }
  }

  Future<void> stopLocalServer() async {
    if (_localServer != null) {
      await _localServer!.close(force: true);
      _localServer = null;
      isLocalServerRunning = false;
      localServerUrl = null;
      debugPrint("Local OTA server closed");
      notifyListeners();
    }
  }

  void _startAutoConnectTimer() {
    _autoConnectTimer?.cancel();
    _autoConnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isConnected && carIp.isNotEmpty && !_isManuallyDisconnected) {
        debugPrint("Auto-connecting to $carIp...");
        connect();
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    carIp = prefs.getString('car_ip') ?? "";
    cameraIp = prefs.getString('camera_ip') ?? "";
    deviceId = prefs.getString('device_id') ?? "Unbound";
    relayServer = prefs.getString('relay_server') ?? "";
    isRemoteMode = prefs.getBool('is_remote_mode') ?? false;
    String langCode = prefs.getString('language_code') ?? 'en';
    locale = Locale(langCode);
    maxSpeed = prefs.getDouble('max_speed') ?? 0.7;
    patrolSpeed = prefs.getDouble('patrol_speed') ?? 0.4;
    sensitivity = prefs.getString('sensitivity') ?? "Medium";
    resolution = prefs.getString('resolution') ?? "1080P";
    nightMode = prefs.getString('night_mode') ?? "Auto";
    aiDetection = prefs.getString('ai_detection') ?? "All";
    detectionSensitivity = prefs.getDouble('detection_sensitivity') ?? 0.75;
    
    notifyListeners();

    // Auto-connect logic: if IP is not empty, try connecting
    if (carIp.isNotEmpty) {
      connect();
    }
  }

  Future<void> factoryReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all persistent data
    
    // Restore default in-memory values
    carIp = "";
    cameraIp = "";
    maxSpeed = 0.5; // 50%
    patrolSpeed = 0.5; // 50%
    sensitivity = "Medium";
    resolution = "720P";
    nightMode = "Auto";
    aiDetection = "Person";
    detectionSensitivity = 0.6; // 60%
    
    _isManuallyDisconnected = false;
    
    // If currently online, send command to hardware to reset
    sendCommand({"cmd": "factory_reset"});
    
    deviceId = "Unbound";
    disconnect(); // Need to disconnect for network reset
    notifyListeners();
  }

  void rebootDevice() {
    sendCommand({"cmd": "reboot"});
  }

  Future<void> setLocale(Locale newLocale) async {
    if (locale == newLocale) return;
    locale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', newLocale.languageCode);
    notifyListeners();
  }

  Future<void> saveAllSettings({
    String? newCarIp,
    String? newCameraIp,
    String? newDeviceId,
    double? newMaxSpeed,
    double? newPatrolSpeed,
    String? newSensitivity,
    String? newResolution,
    String? newNightMode,
    String? newAiDetection,
    double? newDetectionSensitivity,
    String? newRelayServer,
    bool? newIsRemoteMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (newRelayServer != null) {
      await prefs.setString('relay_server', newRelayServer);
      relayServer = newRelayServer;
    }
    if (newIsRemoteMode != null) {
      await prefs.setBool('is_remote_mode', newIsRemoteMode);
      isRemoteMode = newIsRemoteMode;
      disconnect(); // Reconnect when mode changes
    }
    
    if (newCarIp != null && newCarIp != carIp) {
      await prefs.setString('car_ip', newCarIp);
      carIp = newCarIp;
      _isManuallyDisconnected = false; // Allow auto-connect after IP change
      disconnect(); // Disconnect old connection
    }
    if (newCameraIp != null) {
      await prefs.setString('camera_ip', newCameraIp);
      cameraIp = newCameraIp;
    }
    if (newDeviceId != null) {
      await prefs.setString('device_id', newDeviceId);
      deviceId = newDeviceId;
    }
    if (newMaxSpeed != null) {
      await prefs.setDouble('max_speed', newMaxSpeed);
      maxSpeed = newMaxSpeed;
      // Sync to car hardware (0.0~1.0 -> 0~255)
      sendCommand({"cmd": "speed", "value": (maxSpeed * 255).toInt()});
    }
    if (newPatrolSpeed != null) {
      await prefs.setDouble('patrol_speed', newPatrolSpeed);
      patrolSpeed = newPatrolSpeed;
    }
    if (newSensitivity != null) {
      await prefs.setString('sensitivity', newSensitivity);
      sensitivity = newSensitivity;
    }
    if (newResolution != null) {
      await prefs.setString('resolution', newResolution);
      resolution = newResolution;
    }
    if (newNightMode != null) {
      await prefs.setString('night_mode', newNightMode);
      nightMode = newNightMode;
    }
    if (newAiDetection != null) {
      await prefs.setString('ai_detection', newAiDetection);
      aiDetection = newAiDetection;
    }
    if (newDetectionSensitivity != null) {
      await prefs.setDouble('detection_sensitivity', newDetectionSensitivity);
      detectionSensitivity = newDetectionSensitivity;
    }

    notifyListeners();
  }

  void setSpeedLevel(int level) {
    speedLevel = level;
    switch (level) {
      case 0: maxSpeed = 0.4; break; // Low
      case 1: maxSpeed = 0.7; break; // Mid
      case 2: maxSpeed = 1.0; break; // High
      default: maxSpeed = 0.7;
    }
    notifyListeners();
  }

  void updateUltrasonicAngle(double delta) {
    ultrasonicAngle = (ultrasonicAngle + delta).clamp(0.0, 180.0);
    sendCommand({"cmd": "servo", "channel": 0, "angle": ultrasonicAngle});
    notifyListeners();
  }

  // Mixed Control (Virtual Joystick)
  void updateMixedServos(double x, double y) {
    // x, y are from -1.0 to 1.0
    double sensitivity = 3.0;
    
    // X Axis: Ultrasonic Servo (Channel 0) - Position Control (Standard Servo)
    if (x.abs() > 0.1) {
      ultrasonicAngle = (ultrasonicAngle + (x * sensitivity)).clamp(0.0, 180.0);
      sendCommand({"cmd": "servo", "channel": 0, "angle": ultrasonicAngle});
    }

    // Y Axis: Camera Servo (Channel 1) - Speed Control (SG90 360 Continuous)
    double minSpeedOffsetUp = 10.0; 
    double varSpeedRangeUp = 15.0;
    double minSpeedOffsetDown = 1.0; 
    double varSpeedRangeDown = 4.0;  

    if (y.abs() > 0.1) {
      double speedFactor = -y; 
      double targetSpeedAngle = 90.0;
      
      if (speedFactor > 0) {
        targetSpeedAngle = 90.0 + minSpeedOffsetUp + (speedFactor * varSpeedRangeUp);
      } else {
        targetSpeedAngle = 90.0 - minSpeedOffsetDown + (speedFactor * varSpeedRangeDown);
      }
      
      sendCommand({"cmd": "servo", "channel": 1, "angle": targetSpeedAngle.clamp(0.0, 180.0)});
    } else {
      sendCommand({"cmd": "servo_stop", "channel": 1});
    }
    
    notifyListeners();
  }

  void resetServos() {
    ultrasonicAngle = 90.0;
    cameraAngle = 90.0;
    sendCommand({"cmd": "servo", "channel": 0, "angle": ultrasonicAngle});
    sendCommand({"cmd": "servo_stop", "channel": 1});
    notifyListeners();
  }
  
  void toggleLight() {
    isLightOn = !isLightOn;
    sendCommand({"cmd": "light", "val": isLightOn ? 1 : 0});
    notifyListeners();
  }
  
  void toggleHorn(bool on) {
    isHornOn = on;
    sendCommand({"cmd": "horn", "val": isHornOn ? 1 : 0});
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    if (isDiscovering) return;
    isDiscovering = true;
    discoveredDevices.clear();
    notifyListeners();

    const String serviceName = '_robocar._tcp.local';
    final MDnsClient client = MDnsClient();
    
    try {
      await client.start();
      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(serviceName))) {
        
        String? foundId;
        // Verify TXT record to ensure device matches
        await for (final TxtResourceRecord txt in client
            .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))) {
          final List<String> txtData = txt.text.split('\n');
          bool hasType = false;
          for (var item in txtData) {
            if (item.contains('type=robocar-a')) hasType = true;
            if (item.startsWith('id=robocar-a-v1-')) {
              foundId = item.split('=')[1];
            }
          }
          if (hasType && foundId != null) {
            break;
          } else {
            foundId = null;
          }
        }

        if (foundId == null) continue;

        await for (final SrvResourceRecord srv in client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
          await for (final IPAddressResourceRecord ip in client
              .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))) {
            final String address = ip.address.address;
            bool exists = discoveredDevices.any((d) => d['ip'] == address);
            if (!exists) {
              discoveredDevices.add({
                'ip': address,
                'id': foundId,
              });
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Discovery Error: $e");
    } finally {
      client.stop();
      isDiscovering = false;
      notifyListeners();
    }
  }

  Future<bool> connect() async {
    if (isRemoteMode) {
      if (relayServer.isEmpty || deviceId == "Unbound") return false;
    } else {
      if (carIp.isEmpty) return false;
    }
    
    if (isConnected) return true;
    
    _isManuallyDisconnected = false; // Reset flag on any connection attempt
    try {
      final Uri uri;
      if (isRemoteMode) {
        // Connect to relay server: ws://ip:port/ws?role=app&deviceId=...
        String host = relayServer;
        if (!host.startsWith('ws://') && !host.startsWith('wss://')) {
          host = 'ws://$host';
        }
        uri = Uri.parse('$host/ws?role=app&deviceId=$deviceId&carIp=$carIp');
      } else {
        uri = Uri.parse('ws://$carIp:80');
      }
      
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready; 
      isConnected = true;
      
      // Initial commands
      sendCommand({"cmd": "servo", "channel": 0, "angle": ultrasonicAngle});
      sendCommand({"cmd": "servo_stop", "channel": 1});
      sendCommand({"cmd": "speed", "value": (maxSpeed * 255).toInt()});
      
      _startPing();
      
      notifyListeners();

      _channel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'status') {
            if (data['dist'] != null) distance = data['dist'].toString();
            if (data['mode'] != null) mode = data['mode'].toString().toUpperCase();
            if (data['v_car'] != null) carBattery = (data['v_car'] as num).toDouble();
            if (data['rssi'] != null) wifiSignal = (data['rssi'] as num).toInt();
            
            // If device sends back a timestamp for ping
            if (data['pong'] != null && _lastPingTime != null) {
              latency = DateTime.now().difference(_lastPingTime!).inMilliseconds;
            }
            
            notifyListeners();
          }
        } catch (e) {
          debugPrint("Parse Error: $e");
        }
      }, onDone: () {
        _stopPing();
        isConnected = false;
        notifyListeners();
      }, onError: (err) {
        _stopPing();
        isConnected = false;
        notifyListeners();
      });
      return true;
    } catch (e) {
      isConnected = false;
      notifyListeners();
      return false;
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isConnected) {
        _lastPingTime = DateTime.now();
        sendCommand({"cmd": "ping", "ts": _lastPingTime!.millisecondsSinceEpoch});
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void disconnect() {
    _isManuallyDisconnected = true; // Set flag on manual disconnect
    _stopPing();
    stopLocalServer(); // Stop local OTA server
    _channel?.sink.close();
    isConnected = false;
    notifyListeners();
  }

  void sendCommand(Map<String, dynamic> cmd) {
    if (isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(cmd));
    }
  }
}
