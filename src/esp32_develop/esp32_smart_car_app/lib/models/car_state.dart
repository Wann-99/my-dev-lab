import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:http/http.dart' as http;

class CarState extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;
  bool _isManuallyDisconnected = false;
  
  // PRD: 多传感器距离
  double distFront = 0.0;
  double distLeft = 0.0;
  double distRight = 0.0;
  String distance = "--"; // Main distance for display
  
  String mode = "MANUAL";
  String carIp = "";
  String cameraIp = "";
  String deviceId = "Unbound";
  bool isBound = false; // PRD: 绑定状态
  String boundUser = ""; // PRD: 绑定用户
  String relayServer = ""; // Relay server address (e.g., 1.2.3.4:8081)
  bool isRemoteMode = false;
  Locale locale = const Locale('en'); // Default to English
  List<Map<String, String>> discoveredDevices = [];
  bool isDiscovering = false;
  
  // New Status Fields
  double carBattery = 0.0; // Voltage
  int wifiSignal = -1; // dBm
  int latency = 0; // ms
  
  // Battery Calculation (2S LiPo: 6.8V - 8.4V)
  // R1=220k, R2=100k, Max 8.4V -> 2.625V ADC
  double get batteryPercentage {
    if (carBattery <= 0) return 0.0;
    
    // 2S LiPo Discharge Curve Mapping (More realistic than linear)
    // 8.4V = 100%, 7.4V = 50%, 6.8V = 0%
    const double maxV = 8.4;
    const double midV = 7.4;
    const double minV = 6.8;
    
    double pct;
    if (carBattery >= midV) {
      // 7.4V - 8.4V -> 50% - 100%
      pct = 0.5 + (carBattery - midV) / (maxV - midV) * 0.5;
    } else {
      // 6.8V - 7.4V -> 0% - 50%
      pct = (carBattery - minV) / (midV - minV) * 0.5;
    }
    
    return pct.clamp(0.0, 1.0);
  }

  // Voltage Calibration
  double voltageCalibration = 1.0;
  bool useVoltageDivider = false;
  final List<double> _voltageBuffer = [];
  double _smoothedVoltage = 0.0;
  
  void _updateVoltage(double rawVoltage) {
    // Apply voltage divider multiplier (R1=220k, R2=100k => x3.2)
    double baseVoltage = rawVoltage;
    if (useVoltageDivider) {
      baseVoltage = rawVoltage * 3.2;
    }
    
    // Apply calibration
    double calibrated = baseVoltage * voltageCalibration;
    
    // Exponential Moving Average (EMA) + Moving Average Buffer
    // Window size 30 for high stability (approx 15 seconds of data at 2Hz)
    _voltageBuffer.add(calibrated);
    if (_voltageBuffer.length > 30) {
      _voltageBuffer.removeAt(0);
    }
    
    double sum = _voltageBuffer.reduce((a, b) => a + b);
    double avg = sum / _voltageBuffer.length;
    
    // Apply EMA to the average for double smoothing
    if (_smoothedVoltage == 0) {
      _smoothedVoltage = avg;
    } else {
      const double alpha = 0.15; // Lower = smoother, higher = faster
      _smoothedVoltage = (_smoothedVoltage * (1 - alpha)) + (avg * alpha);
    }
    
    // Keep internal precision for percentage, but round for display
    carBattery = _smoothedVoltage;
    notifyListeners();
  }
  DateTime? _lastPingTime;
  Timer? _pingTimer;
  Timer? _heartbeatCheckTimer;
  DateTime? _lastHeartbeatTime;
  Timer? _autoConnectTimer;
  
  // Control State
  double maxSpeed = 1.0; 
  double patrolSpeed = 0.5;
  String sensitivity = "Medium";
  int speedLevel = 2; 
  double ultrasonicAngle = 90.0;
  
  // Vision State
  String resolution = "1080P";
  String nightMode = "Auto";
  String aiDetection = "All";
  double detectionSensitivity = 0.75;
  
  // Hardware State
  bool isLightOn = false;
  bool isHornOn = false;
  bool isCamFlashOn = false;
  
  // Version Info
  String currentAppVersion = "1.0.0";
  String latestAppVersion = "1.0.0";
  
  // Dual MCU Firmware Info
  String currentFirmwareVersion = "1.0.0"; // S3 Main
  String latestFirmwareVersion = "1.0.0";
  String currentCamFirmwareVersion = "1.0.0"; // CAM Vision
  String latestCamFirmwareVersion = "1.0.0";
  
  String appUpdateLog = "";
  String firmwareUpdateLog = "";
  String camFirmwareUpdateLog = "";
  
  bool hasAppUpdate = false;
  bool hasFirmwareUpdate = false;
  bool hasCamFirmwareUpdate = false;
  
  // PTZ State
  double cameraAngle = 90.0;

  // Local OTA Server
  HttpServer? _localServer;
  bool isLocalServerRunning = false;
  String? localServerUrl;
  
  bool showEmergencyStop = true;
  
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
    
    // Simulate finding CAM firmware update
    latestCamFirmwareVersion = "1.0.5";
    camFirmwareUpdateLog = "1. Improved MJPEG stream FPS\n2. Added mDNS support (robocar-cam.local)\n3. Optimized auto-exposure for low light";
    hasCamFirmwareUpdate = latestCamFirmwareVersion != currentCamFirmwareVersion;
    
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

  Future<void> startLocalOTA(File firmwareFile, {bool isCam = false}) async {
    if (!isConnected || carIp.isEmpty) return;

    try {
      isLocalServerRunning = true; // Use this as "isUpdating" flag
      notifyListeners();

      final uri = Uri.parse("http://$carIp/update${isCam ? "?target=cam" : ""}");
      
      // ESP32-S3 expects raw body or multipart? 
      // My ota_server.c implementation uses httpd_req_recv, which handles raw body better.
      // But standard HTML forms use multipart. 
      // Let's check my ota_server.c again.
      // It uses `httpd_req_recv(req, buf, MIN(remaining, sizeof(buf)))` which reads the raw body.
      // So we should send the raw bytes.

      final bytes = await firmwareFile.readAsBytes();
      
      final response = await http.post(
        uri,
        body: bytes,
        headers: {
          'Content-Type': 'application/octet-stream',
        },
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        debugPrint("OTA Upload Success: ${response.body}");
      } else {
        debugPrint("OTA Upload Failed (${response.statusCode}): ${response.body}");
        throw Exception("Update failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Failed to perform local OTA: $e");
      rethrow;
    } finally {
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
      // PRD: Only auto-connect if device is bound
      if (isBound && !isConnected && carIp.isNotEmpty && !_isManuallyDisconnected) {
        debugPrint("Auto-connecting to bound device at $carIp...");
        connect();
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    carIp = prefs.getString('car_ip') ?? "";
    cameraIp = prefs.getString('camera_ip') ?? "";
    deviceId = prefs.getString('device_id') ?? "Unbound";
    isBound = prefs.getBool('is_bound') ?? false;
    boundUser = prefs.getString('bound_user') ?? "";
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
    voltageCalibration = prefs.getDouble('voltage_calibration') ?? 1.0;
    useVoltageDivider = prefs.getBool('use_voltage_divider') ?? false;
    showEmergencyStop = prefs.getBool('show_emergency_stop') ?? true;
    
    if (cameraIp.isEmpty && carIp.isNotEmpty) {
      cameraIp = carIp;
    }
    
    notifyListeners();
  
    // PRD: Auto-connect ONLY if bound and IP is available
    if (isBound && carIp.isNotEmpty) {
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
    showEmergencyStop = true;
    
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

  void emergencyStop() {
    // PRD: High priority stop command
    sendCommand({
      "cmd": "move",
      "vx": 0,
      "vy": 0,
      "vw": 0
    });
    // In case of emergency stop, we might want to toggle some local UI state
    notifyListeners();
  }

  Future<void> bindDevice(String id, String user) async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = id;
    isBound = true;
    boundUser = user;
    await prefs.setString('device_id', id);
    await prefs.setBool('is_bound', true);
    await prefs.setString('bound_user', user);
    notifyListeners();
  }

  Future<void> unbindDevice() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = "Unbound";
    isBound = false;
    boundUser = "";
    await prefs.setString('device_id', "Unbound");
    await prefs.setBool('is_bound', false);
    await prefs.setString('bound_user', "");
    notifyListeners();
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
    bool? newShowFloatingBall,
    bool? newShowEmergencyStop,
    double? newVoltageCalibration,
    bool? newUseVoltageDivider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (newUseVoltageDivider != null) {
      await prefs.setBool('use_voltage_divider', newUseVoltageDivider);
      useVoltageDivider = newUseVoltageDivider;
    }
    
    if (newVoltageCalibration != null) {
      await prefs.setDouble('voltage_calibration', newVoltageCalibration);
      voltageCalibration = newVoltageCalibration;
    }
    
    if (newRelayServer != null) {
      await prefs.setString('relay_server', newRelayServer);
      relayServer = newRelayServer;
    }
    if (newIsRemoteMode != null) {
      await prefs.setBool('is_remote_mode', newIsRemoteMode);
      isRemoteMode = newIsRemoteMode;
      disconnect(); // Reconnect when mode changes
    }
    
    if (newShowEmergencyStop != null) {
      await prefs.setBool('show_emergency_stop', newShowEmergencyStop);
      showEmergencyStop = newShowEmergencyStop;
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
      if (isConnected) {
        sendCommand({"cmd": "set_cam_ip", "value": newCameraIp});
      }
    }
    if (newDeviceId != null) {
      await prefs.setString('device_id', newDeviceId);
      deviceId = newDeviceId;
    }
    if (newMaxSpeed != null) {
      await prefs.setDouble('max_speed', newMaxSpeed);
      maxSpeed = newMaxSpeed;
      // Sync to car hardware (0.0~1.0 -> 0~100)
      sendCommand({"cmd": "speed", "value": (maxSpeed * 100).toInt()});
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

  // PTZ Control (Dual 180 Servo)
  void updatePtz(double x, double y) {
    // x, y are from -1.0 to 1.0 (Joystick input)
    // x controls Channel 0 (Pan), y controls Channel 1 (Tilt)
    
    double sensitivity = 2.0;
    
    // Pan (Ch0)
    if (x.abs() > 0.1) {
      ultrasonicAngle = (ultrasonicAngle + (x * sensitivity)).clamp(0.0, 180.0);
      sendCommand({"cmd": "servo", "channel": 0, "angle": ultrasonicAngle.toInt()});
    }
    
    // Tilt (Ch1) - Inverted Y usually feels more natural (Up on stick = Camera Up)
    // But servo mapping depends on mounting. Let's assume standard.
    if (y.abs() > 0.1) {
      cameraAngle = (cameraAngle + (y * sensitivity)).clamp(0.0, 180.0);
      sendCommand({"cmd": "servo", "channel": 1, "angle": cameraAngle.toInt()});
    }
    
    notifyListeners();
  }

  // Legacy mixed control (keeping for compatibility if needed, but redirecting to new logic)
  void updateMixedServos(double x, double y) {
    updatePtz(x, y);
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

  void toggleCamFlash() {
    isCamFlashOn = !isCamFlashOn;
    sendCommand({"cmd": "cam_flash", "val": isCamFlashOn ? 255 : 0});
    notifyListeners();
  }

  // Mode change tracking to prevent UI flicker
  DateTime _lastModeChangeTime = DateTime.fromMillisecondsSinceEpoch(0);

  void setCarMode(String newMode) {
    if (isConnected) {
      _lastModeChangeTime = DateTime.now();
      final modeUpper = newMode.toUpperCase();
      mode = modeUpper; // Optimistic update for immediate UI feedback
      sendCommand({"cmd": "mode", "value": modeUpper});

      // Safety: Only stop the car if switching TO Manual mode.
      // If switching TO Auto, let the car's autonomous logic take over.
      if (modeUpper == "MANUAL") {
        emergencyStop();
      }

      notifyListeners();
    }
  }

  Future<void> startDiscovery() async {
    if (isDiscovering) return;
    isDiscovering = true;
    discoveredDevices.clear();
    notifyListeners();

    // PRD: Use multiple discovery strategies (mDNS + manual IP fallback if needed)
    // Here we focus on making mDNS more robust
    const String serviceName = '_robocar._tcp.local';
    
    // On some Windows/Android environments, we need to bind to a specific address or use RawDatagramSocket
    final MDnsClient client = MDnsClient();
    
    try {
      await client.start();
      debugPrint("mDNS Client started, searching for $serviceName...");
      
      // Look for pointers to our service
      final Stream<PtrResourceRecord> ptrStream = client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceName),
      );

      await for (final PtrResourceRecord ptr in ptrStream.timeout(const Duration(seconds: 5), onTimeout: (sink) => sink.close())) {
        debugPrint("Found mDNS PTR: ${ptr.domainName}");
        
        String? foundId;
        String? foundIp;
        String foundInstanceName = ptr.domainName.split('.')[0];

        // Resolve TXT, SRV and IP in parallel for this PTR
        await Future.wait([
          // 1. Get TXT for ID and Type
          () async {
            try {
              await for (final TxtResourceRecord txt in client
                  .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))
                  .timeout(const Duration(seconds: 2))) {
                final List<String> txtData = txt.text.split('\n');
                bool hasType = false;
                for (var item in txtData) {
                  if (item.contains('type=robocar-a')) hasType = true;
                  if (item.startsWith('id=')) {
                    foundId = item.split('=')[1];
                  }
                }
                if (hasType && foundId != null) break;
              }
            } catch (e) {
              debugPrint("TXT lookup error for ${ptr.domainName}: $e");
            }
          }(),
          
          // 2. Get SRV then IP
          () async {
            try {
              await for (final SrvResourceRecord srv in client
                  .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
                  .timeout(const Duration(seconds: 2))) {
                
                await for (final IPAddressResourceRecord ip in client
                    .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
                    .timeout(const Duration(seconds: 2))) {
                  foundIp = ip.address.address;
                  if (foundIp != null) break;
                }
                if (foundIp != null) break;
              }
            } catch (e) {
              debugPrint("SRV/IP lookup error for ${ptr.domainName}: $e");
            }
          }(),
        ]);

        if (foundIp != null) {
          final String finalId = foundId ?? foundInstanceName;
          bool exists = discoveredDevices.any((d) => d['ip'] == foundIp);
          if (!exists) {
            debugPrint("Discovered Device: $finalId at $foundIp");
            discoveredDevices.add({
              'ip': foundIp!,
              'id': finalId,
              'name': foundInstanceName,
            });
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint("Discovery Error: $e");
    } finally {
      client.stop();
      isDiscovering = false;
      debugPrint("Discovery finished. Found ${discoveredDevices.length} devices.");
      notifyListeners();
    }
  }

  Future<bool> connect() async {
    // PRD: Strictly enforce binding before connection
    if (!isBound) {
      debugPrint("Connection rejected: Device must be bound first.");
      return false;
    }

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
      
      debugPrint("Connecting to WebSocket: $uri");
      _channel = WebSocketChannel.connect(uri);
      
      // Wait for connection with timeout
      await _channel!.ready.timeout(const Duration(seconds: 5)); 
      
      isConnected = true;
      _isManuallyDisconnected = false;

      // Request initial status and Camera IP
      sendCommand({"cmd": "status"});
      
      // Initial commands
      sendCommand({"cmd": "servo", "channel": 0, "angle": ultrasonicAngle});
      sendCommand({"cmd": "servo_stop", "channel": 1});
      sendCommand({"cmd": "speed", "value": (maxSpeed * 100).toInt()});
      
      _startPing();
      
      notifyListeners();

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            
            // Handle Ping/Pong separately from status messages
            if (data['res'] == 'pong' && _lastPingTime != null) {
              latency = DateTime.now().difference(_lastPingTime!).inMilliseconds;
              notifyListeners();
              return;
            }

            if (data['type'] == 'status') {
              _lastHeartbeatTime = DateTime.now(); // Update heartbeat on any status message
              
              // PRD: 多传感器距离
              if (data['dist_f'] != null) distFront = (data['dist_f'] as num).toDouble();
              if (data['dist_l'] != null) distLeft = (data['dist_l'] as num).toDouble();
              if (data['dist_r'] != null) distRight = (data['dist_r'] as num).toDouble();
              
              if (data['dist'] != null) {
                distance = data['dist'].toString();
              } else if (data['dist_f'] != null) {
                distance = data['dist_f'].toString();
              }
              
              if (data['mode'] != null) {
                final newMode = data['mode'].toString().toUpperCase();
                // Only sync hardware mode if not manually changed recently (within 2s)
                if (DateTime.now().difference(_lastModeChangeTime).inSeconds > 2) {
                  if (mode != newMode) {
                    mode = newMode;
                    notifyListeners();
                  }
                }
              }
              if (data.containsKey('cam_ip') || data.containsKey('camIP')) {
                String? newIp = data['cam_ip'] ?? data['camIP'];
                if (newIp != null && newIp != "0.0.0.0" && newIp != cameraIp) {
                  cameraIp = newIp;
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setString('camera_ip', newIp);
                  });
                }
              }
              if (data['v_car'] != null) {
                _updateVoltage((data['v_car'] as num).toDouble());
              }
              if (data['rssi'] != null) wifiSignal = (data['rssi'] as num).toInt();
              
              notifyListeners();
            }
          } catch (e) {
            debugPrint("Parse Error: $e");
          }
        }, 
        onDone: () {
          debugPrint("WebSocket Connection Closed (onDone)");
          _handleDisconnect();
        }, 
        onError: (err) {
          debugPrint("WebSocket Error: $err");
          _handleDisconnect();
        },
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      debugPrint("Connection failed: $e");
      _handleDisconnect();
      return false;
    }
  }

  void _handleDisconnect() {
    _stopPing();
    _channel = null;
    isConnected = false;
    notifyListeners();
  }

  void _startPing() {
    _pingTimer?.cancel();
    _lastHeartbeatTime = DateTime.now(); // Reset heartbeat on start
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isConnected) {
        _lastPingTime = DateTime.now();
        sendCommand({"cmd": "ping", "ts": _lastPingTime!.millisecondsSinceEpoch});
      }
    });

    // Heartbeat check: If no status update for 5 seconds, consider disconnected
    _heartbeatCheckTimer?.cancel();
    _heartbeatCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isConnected && _lastHeartbeatTime != null) {
        if (DateTime.now().difference(_lastHeartbeatTime!).inSeconds > 5) {
          debugPrint("Heartbeat lost, disconnecting...");
          disconnect();
        }
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _heartbeatCheckTimer?.cancel();
    _heartbeatCheckTimer = null;
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
    // Allow control commands even if not bound, but still block sensitive commands
    final String? commandName = cmd['cmd']?.toString();
    final List<String> sensitiveCommands = ['ota_start', 'factory_reset', 'reset', 'restart', 'reboot', 'set_relay'];
    
    // Block sensitive commands if not bound
    if (!isBound && commandName != null && sensitiveCommands.contains(commandName)) {
      debugPrint("Sensitive command blocked: Device not bound. Command: $commandName");
      return;
    }

    if (isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(cmd));
    }
  }
}
