import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class DeviceConfig {
  String id;
  String name;
  String ip;
  String cameraIp;
  
  // Per-device runtime telemetry
  String macAddress = '--';
  String uptime = '00:00:00';
  int uptimeSeconds = 0;
  double batteryVoltage = 0.0;
  double radarDistance = 0.0;
  double voltageMultiplier = 1.0;
  String wifiSsid = '--';
  int rssi = 0;
  String firmwareVersion = '--';
  String camFirmwareVersion = '--';
  String trackingTarget = 'Person'; // 'Person', 'Cat'

  DeviceConfig({
    required this.id,
    required this.name,
    required this.ip,
    this.cameraIp = '',
    this.voltageMultiplier = 1.0,
    this.trackingTarget = 'Person',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'cameraIp': cameraIp,
    'voltageMultiplier': voltageMultiplier,
    'trackingTarget': trackingTarget,
  };

  factory DeviceConfig.fromJson(Map<String, dynamic> json) => DeviceConfig(
    id: json['id'],
    name: json['name'],
    ip: json['ip'],
    cameraIp: json['cameraIp'] ?? '',
    voltageMultiplier: (json['voltageMultiplier'] ?? 1.0).toDouble(),
    trackingTarget: json['trackingTarget'] ?? 'Person',
  );
}

class CarState extends ChangeNotifier {
  // UI State
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  // Device Management
  List<DeviceConfig> _boundDevices = [];
  String? _activeDeviceId;
  
  // Connection State
  MqttServerClient? _mqttClient;
  WebSocketChannel? _wsChannel;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDiscovering = false;
  bool _isWifiScanning = false;
  bool _isManuallyDisconnected = false;
  List<Map<String, String>> _discoveredDevices = [];
  List<Map<String, dynamic>> _wifiScanResults = [];
  String? _wifiConfigResult; // 'success', 'failed', or null
  
  // Global Telemetry timers/metrics
  Timer? _uptimeTimer;
  Timer? _infoPollingTimer;
  Timer? _connectionTimeoutTimer;
  int _latency = 0;
  Stopwatch _latencyStopwatch = Stopwatch();
  
  // Settings
  bool _isRemoteMode = false;
  bool _showEmergencyStop = true;
  bool _isAutoMode = false;
  double _maxSpeed = 0.5;
  String _resolution = 'VGA';
  Locale _locale = const Locale('zh');
  String _currentAppVersion = '2.0.1';
  String _relayUrl = '';
  
  String get currentAppVersion => _currentAppVersion;
  
  // Firmware update tracking
  String _latestFirmwareVersion = 'v2.0.1'; 
  String _latestCamFirmwareVersion = 'v1.0.1';

  // Getters
  List<DeviceConfig> get boundDevices => _boundDevices;
  
  DeviceConfig? get activeDevice {
    if (_activeDeviceId == null || _boundDevices.isEmpty) return null;
    try {
      return _boundDevices.firstWhere((d) => d.id == _activeDeviceId);
    } catch (e) {
      return null;
    }
  }

  bool get isBound => _boundDevices.isNotEmpty;
  bool get isConnected => _isConnected;
  bool get isDiscovering => _isDiscovering;
  bool get isWifiScanning => _isWifiScanning;
  List<Map<String, String>> get discoveredDevices => _discoveredDevices;
  List<Map<String, dynamic>> get wifiScanResults => _wifiScanResults;
  String? get wifiConfigResult => _wifiConfigResult;
  
  String get carIp => activeDevice?.ip ?? '';
  String get wifiSsid => activeDevice?.wifiSsid ?? '--';
  String get macAddress => activeDevice?.macAddress ?? '--';
  String get uptime => activeDevice?.uptime ?? '00:00:00';
  int get latency => _latency;
  double get batteryVoltage => (activeDevice?.batteryVoltage ?? 0.0) * (activeDevice?.voltageMultiplier ?? 1.0);
  double get rawBatteryVoltage => activeDevice?.batteryVoltage ?? 0.0;
  double get voltageMultiplier => activeDevice?.voltageMultiplier ?? 1.0;
  String get trackingTarget => activeDevice?.trackingTarget ?? 'Person';
  double get radarDistance => activeDevice?.radarDistance ?? 0.0;
  int get rssi => activeDevice?.rssi ?? 0;
  
  int get batteryPercentage {
    final v = batteryVoltage;
    if (v == 0) return 0;
    // Standard 3S Li-ion battery: 12.6V full, 10.5V empty
    final pct = ((v - 10.5) / 2.1 * 100).round();
    return pct.clamp(0, 100);
  }

  bool get isRemoteMode => _isRemoteMode;
  bool get showEmergencyStop => _showEmergencyStop;
  bool get isAutoMode => _isAutoMode;
  double get maxSpeed => _maxSpeed;
  String get resolution => _resolution;
  Locale get locale => _locale;
  String get currentFirmwareVersion => activeDevice?.firmwareVersion ?? '--';
  String get latestFirmwareVersion => _latestFirmwareVersion;
  bool get hasFirmwareUpdate => currentFirmwareVersion != '--' && currentFirmwareVersion != _latestFirmwareVersion;
  String get currentCamFirmwareVersion => activeDevice?.camFirmwareVersion ?? '--';
  String get latestCamFirmwareVersion => _latestCamFirmwareVersion;
  bool get hasCamFirmwareUpdate => currentCamFirmwareVersion != '--' && currentCamFirmwareVersion != _latestCamFirmwareVersion;

  CarState() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? devicesJson = prefs.getString('bound_devices');
    if (devicesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(devicesJson);
        _boundDevices = decoded.map((item) => DeviceConfig.fromJson(item)).toList();
      } catch (e) {
        _boundDevices = [];
      }
    }
    
    _activeDeviceId = prefs.getString('active_device_id');
    if (_activeDeviceId == null && _boundDevices.isNotEmpty) {
      _activeDeviceId = _boundDevices.first.id;
    }

    _isRemoteMode = prefs.getBool('isRemoteMode') ?? false;
    _showEmergencyStop = prefs.getBool('showEmergencyStop') ?? true;
    _maxSpeed = prefs.getDouble('maxSpeed') ?? 0.5;
    _resolution = prefs.getString('resolution') ?? 'VGA';
    _relayUrl = prefs.getString('relayUrl') ?? '';
    
    final String lang = prefs.getString('language') ?? 'zh';
    _locale = Locale(lang);
    
    notifyListeners();
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_boundDevices.map((d) => d.toJson()).toList());
    await prefs.setString('bound_devices', encoded);
    if (_activeDeviceId != null) {
      await prefs.setString('active_device_id', _activeDeviceId!);
    }
  }

  void setAutoMode(bool autoMode) {
    _isAutoMode = autoMode;
    // Send mode change command to car
    sendCommand(jsonEncode({"cmd": "mode", "auto": _isAutoMode ? 1 : 0}));
    notifyListeners();
  }
  
  Future<void> saveAllSettings({
    bool? newIsRemoteMode,
    bool? newShowEmergencyStop,
    double? newMaxSpeed,
    String? newResolution,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (newIsRemoteMode != null) {
      bool modeChanged = _isRemoteMode != newIsRemoteMode;
      _isRemoteMode = newIsRemoteMode;
      await prefs.setBool('isRemoteMode', _isRemoteMode);
      
      // Reconnect with new protocol if already connected
      if (modeChanged && (_isConnected || _isConnecting)) {
        disconnect();
        connect();
      }
    }
    if (newShowEmergencyStop != null) {
      _showEmergencyStop = newShowEmergencyStop;
      await prefs.setBool('showEmergencyStop', _showEmergencyStop);
    }
    if (newMaxSpeed != null) {
      _maxSpeed = newMaxSpeed;
      await prefs.setDouble('maxSpeed', _maxSpeed);
    }
    if (newResolution != null) {
      _resolution = newResolution;
      await prefs.setString('resolution', _resolution);
    }
    notifyListeners();
  }

  void setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', locale.languageCode);
    notifyListeners();
  }

  bool _isMacAddress(String id) {
    // Basic MAC address pattern check
    return RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$').hasMatch(id) || 
           RegExp(r'^[0-9A-Fa-f]{12}$').hasMatch(id);
  }

  Future<bool> _isSameSubnet(String targetIp) async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final myIpParts = addr.address.split('.');
            final targetParts = targetIp.split('.');
            if (myIpParts.length == 4 && targetParts.length == 4) {
              // Check first 3 octets (simple /24 subnet check)
              if (myIpParts[0] == targetParts[0] && 
                  myIpParts[1] == targetParts[1] && 
                  myIpParts[2] == targetParts[2]) {
                return true;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Subnet check error: $e');
    }
    return false;
  }

  Future<void> bindDevice(String id, String user, {String? ip}) async {
    debugPrint('Binding device with ID: $id, IP: $ip');
    
    // Rigorous Subnet Check for manual IP entry
    if (ip != null && !ip.startsWith('192.168.4.')) { // Ignore check for AP mode
      final sameSubnet = await _isSameSubnet(ip);
      if (!sameSubnet) {
        debugPrint('Warning: Target IP $ip is on a different subnet');
        // We don't block it completely yet (might be routed), 
        // but we should be careful. The user specifically asked why it "connects".
      }
    }

    // 1. Check if this ID already exists in our bound devices
    final int existingById = _boundDevices.indexWhere((d) => d.id == id);
    if (existingById != -1) {
      debugPrint('Device ID $id already exists, updating IP to $ip');
      if (ip != null) {
        // If the active device IP is changing, we MUST disconnect first
        if (_activeDeviceId == id && _boundDevices[existingById].ip != ip) {
          disconnect();
        }
        _boundDevices[existingById].ip = ip;
      }
      _activeDeviceId = id;
      await _saveDevices();
      notifyListeners();
      return;
    }

    // 2. Check if this IP is already bound to another ID
    // If we're binding by IP and that IP is already in use by a MAC-based ID, 
    // we should switch to that ID instead of adding a new one.
    if (ip != null) {
      final int existingByIp = _boundDevices.indexWhere((d) => d.ip == ip);
      if (existingByIp != -1) {
        final existingDevice = _boundDevices[existingByIp];
        debugPrint('IP $ip already exists with ID ${existingDevice.id}, switching active device');
        _activeDeviceId = existingDevice.id;
        // If the new ID is a MAC but the existing one isn't, upgrade the ID
        if (_isMacAddress(id) && !_isMacAddress(existingDevice.id)) {
          existingDevice.id = id;
          _activeDeviceId = id;
        }
        await _saveDevices();
        notifyListeners();
        return;
      }
    }

    // 3. New device - proceed with creation
    debugPrint('Creating new device entry for ID: $id');
    int nextIndex = 1;
    final List<int> existingIndices = _boundDevices
        .map((d) {
          final match = RegExp(r'Robot Car_(\d+)').firstMatch(d.name);
          return match != null ? int.parse(match.group(1)!) : null;
        })
        .whereType<int>()
        .toList();
    
    existingIndices.sort();
    for (int index in existingIndices) {
      if (index == nextIndex) {
        nextIndex++;
      } else if (index > nextIndex) {
        break;
      }
    }

    final newDevice = DeviceConfig(
      id: id,
      name: 'Robot Car_$nextIndex',
      ip: ip ?? '192.168.4.1',
    );
    
    // Add to list and ensure new reference for Provider
    _boundDevices = [..._boundDevices, newDevice];
    _activeDeviceId = newDevice.id;
    await _saveDevices();
    notifyListeners();
    debugPrint('Device bound successfully. Total devices: ${_boundDevices.length}');
  }

  void unbindDevice(String id) async {
    _boundDevices.removeWhere((d) => d.id == id);
    if (_activeDeviceId == id) {
      _activeDeviceId = _boundDevices.isNotEmpty ? _boundDevices.first.id : null;
      disconnect();
    }
    await _saveDevices();
    notifyListeners();
  }

  Future<void> setActiveDevice(String id) async {
    if (_boundDevices.any((d) => d.id == id)) {
      if (_activeDeviceId != id) {
        disconnect();
        _activeDeviceId = id;
        await _saveDevices();
        notifyListeners();
      }
    }
  }

  void renameDevice(String id, String newName) async {
    final index = _boundDevices.indexWhere((d) => d.id == id);
    if (index != -1) {
      _boundDevices[index].name = newName;
      await _saveDevices();
      notifyListeners();
    }
  }

  void setVoltageMultiplier(double multiplier) async {
    final device = activeDevice;
    if (device != null) {
      device.voltageMultiplier = multiplier;
      await _saveDevices();
      notifyListeners();
    }
  }


  void saveDeviceSettings({
    double? maxSpeed,
    String? resolution,
    String? trackingTarget,
  }) async {
    final device = activeDevice;
    if (device == null) return;

    if (maxSpeed != null) _maxSpeed = maxSpeed;
    if (resolution != null) _resolution = resolution;
    if (trackingTarget != null) device.trackingTarget = trackingTarget;

    await _saveDevices();
    
    // Also save global settings if needed
    final prefs = await SharedPreferences.getInstance();
    if (maxSpeed != null) await prefs.setDouble('maxSpeed', maxSpeed);
    if (resolution != null) await prefs.setString('resolution', resolution);
    
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _discoveredDevices = [];
    notifyListeners();
    
    final client = MDnsClient();
    try {
      await client.start();
      
      // Look for _robocar._tcp.local
      const String serviceType = '_robocar._tcp.local';
      
      // Set a timeout for the entire discovery process
      final lookupStream = client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(serviceType)).timeout(const Duration(seconds: 5));
      
      await for (final PtrResourceRecord ptr in lookupStream) {
        final srvStream = client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName)).timeout(const Duration(seconds: 2));
            
        await for (final SrvResourceRecord srv in srvStream) {
          String? ip;
          final ipStream = client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target)).timeout(const Duration(seconds: 2));
              
          await for (final IPAddressResourceRecord ipRecord in ipStream) {
            ip = ipRecord.address.address;
            break;
          }

          if (ip != null) {
            // Get TXT records
            String? id;
            final txtStream = client.lookup<TxtResourceRecord>(
                ResourceRecordQuery.text(ptr.domainName)).timeout(const Duration(seconds: 2));
                
            await for (final TxtResourceRecord txt in txtStream) {
              // Try 'strings' first if available, then fallback to 'text'
              List<String> textList = [];
              try {
                // Some versions of multicast_dns use .text, others use .strings
                textList = (txt as dynamic).strings ?? [txt.text];
              } catch (e) {
                textList = [txt.text];
              }

              for (var text in textList) {
                final List<String> parts = text.split('\n');
                for (var part in parts) {
                  if (part.contains('id=')) {
                    id = part.split('id=')[1].trim();
                  }
                }
              }
            }

            // Fallback: use instance name if TXT fails
            final deviceId = id ?? ptr.domainName.split('.')[0];
            if (!_discoveredDevices.any((d) => d['id'] == deviceId)) {
              _discoveredDevices.add({
                'id': deviceId,
                'ip': ip,
              });
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Discovery error or timeout: $e');
    } finally {
      client.stop();
      _isDiscovering = false;
      notifyListeners();
    }
  }

  void connect() async {
    if (carIp.isEmpty) return;
    
    // Clean up any existing connection and timers first
    _cleanupConnection();
    
    _isManuallyDisconnected = false;
    _isConnected = false;
    _isConnecting = true;
    _latency = 0;

    if (_isRemoteMode) {
      _connectMQTT();
    } else {
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    debugPrint('[WS] Starting connection attempt to: $carIp');
    
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_isConnecting && !_isConnected) {
        debugPrint('[WS] Connection attempt timed out for $carIp');
        _handleUnexpectedDisconnect('timeout');
      }
    });

    final wsUrl = 'ws://$carIp:80/ws';
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _wsChannel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          debugPrint('[WS] Stream closed for $carIp');
          if (!_isManuallyDisconnected) {
            _handleUnexpectedDisconnect('done');
          } else {
            _cleanupConnection();
          }
        },
        onError: (error) {
          debugPrint('[WS] Stream error for $carIp: $error');
          if (!_isManuallyDisconnected) {
            _handleUnexpectedDisconnect('error');
          } else {
            _cleanupConnection();
          }
        },
      );
      
      // Send initial status request to trigger handshake
      _sendInfoCommand();
      notifyListeners();
    } catch (e) {
      debugPrint('[WS] Connection setup failed for $carIp: $e');
      _handleUnexpectedDisconnect('setup_failed');
    }
  }

  void _connectMQTT() async {
    final mqttHost = _relayUrl.isNotEmpty ? _relayUrl : carIp;
    debugPrint('[MQTT] Starting connection attempt to: $mqttHost');
    
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_isConnecting && !_isConnected) {
        debugPrint('[MQTT] Connection attempt timed out for $mqttHost');
        _handleUnexpectedDisconnect('timeout');
      }
    });
    
    _mqttClient = MqttServerClient(mqttHost, 'flutter_client_${DateTime.now().millisecondsSinceEpoch}');
    _mqttClient!.port = 1883;
    _mqttClient!.logging(on: false);
    _mqttClient!.keepAlivePeriod = 20;
    _mqttClient!.onDisconnected = () {
      debugPrint('[MQTT] Disconnected');
      if (!_isManuallyDisconnected) {
        _handleUnexpectedDisconnect('disconnected');
      } else {
        _cleanupConnection();
      }
    };
    _mqttClient!.onConnected = () {
      debugPrint('[MQTT] Connected');
      _isConnecting = false;
      _isConnected = true;
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = null;
      _startUptimeTimer();
      _startInfoPolling();
      
      // Subscribe to status topic
      _mqttClient!.subscribe('robocar/status', MqttQos.atMostOnce);
      
      // Listen to updates
      _mqttClient!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        if (c[0].topic == 'robocar/status') {
          _handleMessage(pt);
        }
      });
      
      notifyListeners();
    };
    
    // Setup authentication if needed, using the default user from python script
    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_client_${DateTime.now().millisecondsSinceEpoch}')
        .authenticateAs('robocar', 'smart2026')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _mqttClient!.connectionMessage = connMess;

    try {
      await _mqttClient!.connect();
    } catch (e) {
      debugPrint('[MQTT] Connection setup failed for $carIp: $e');
      _mqttClient?.disconnect();
      _handleUnexpectedDisconnect('setup_failed');
    }
  }

  void disconnect() {
    debugPrint('[Connection] Manual disconnect requested');
    _isManuallyDisconnected = true;
    _wsChannel?.sink.close();
    _mqttClient?.disconnect();
    _cleanupConnection();
  }

  void _cleanupConnection() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _mqttClient?.disconnect();
    _mqttClient = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopUptimeTimer();
    _stopInfoPolling();
    _latency = 0;
    
    // Clear runtime data on disconnect
    final device = activeDevice;
    if (device != null) {
      device.uptimeSeconds = 0;
      device.uptime = '00:00:00';
    }
    
    notifyListeners();
  }

  Timer? _reconnectTimer;
  void _handleUnexpectedDisconnect(String reason) {
    debugPrint('[Connection] Handling unexpected disconnect. Reason: $reason');
    _cleanupConnection();
    
    // Only attempt auto-reconnect if it wasn't a manual disconnect
    if (!_isManuallyDisconnected && carIp.isNotEmpty) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (!_isManuallyDisconnected && carIp.isNotEmpty) {
          debugPrint('[Connection] Attempting auto-reconnect now...');
          connect();
        }
      });
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      debugPrint('[${_isRemoteMode ? "MQTT" : "WS"}] Received: ${data['type'] ?? data['res'] ?? 'message'}');

      
      final device = activeDevice;
      if (device == null) return;

      // Calculate latency for any incoming packet if stopwatch is running
      if (_latencyStopwatch.isRunning) {
        _latencyStopwatch.stop();
        _latency = _latencyStopwatch.elapsedMilliseconds;
        _latencyStopwatch.reset();
      }

      // Handshake / Initial connection confirmation
      if (_isConnecting) {
        bool handshakeConfirmed = false;
        
        // 1. Check for hardware ID (MAC) to verify identity
        final String hwMac = data['mac'] ?? '';
        if (hwMac.isNotEmpty) {
          if (device.id != hwMac) {
            if (!_isMacAddress(device.id)) {
              debugPrint('[MQTT] Migrating ID ${device.id} -> $hwMac');
              final existingIndex = _boundDevices.indexWhere((d) => d.id == hwMac);
              if (existingIndex != -1) {
                final oldId = device.id;
                _boundDevices[existingIndex].ip = device.ip;
                _boundDevices = _boundDevices.where((d) => d.id != oldId).toList();
                _activeDeviceId = hwMac;
              } else {
                device.id = hwMac;
                _activeDeviceId = hwMac;
              }
              _saveDevices();
            } else {
              debugPrint('[MQTT] MAC Mismatch! Expected ${device.id}, got $hwMac. Aborting.');
              disconnect();
              return;
            }
          }
          handshakeConfirmed = true;
        } else if (data['type'] == 'welcome' || data['bat'] != null || data['type'] == 'status') {
          // 2. Accept welcome or status messages as handshake if MAC is missing but data is valid
          handshakeConfirmed = true;
        }

        if (handshakeConfirmed) {
          debugPrint('[MQTT] Handshake confirmed for ${device.name}');
          _isConnecting = false;
          _isConnected = true;
          _connectionTimeoutTimer?.cancel();
          _connectionTimeoutTimer = null;
          _startUptimeTimer();
          _startInfoPolling(); // Start the 3s polling timer only AFTER handshake
          notifyListeners();
        }
      }

      // Update telemetry data
      if (data['mac'] != null) device.macAddress = data['mac'];
      if (data['bat'] != null) device.batteryVoltage = (data['bat'] as num).toDouble();
      if (data['v_car'] != null) device.batteryVoltage = (data['v_car'] as num).toDouble();
      if (data['dist'] != null) device.radarDistance = (data['dist'] as num).toDouble();
      if (data['rssi'] != null) device.rssi = (data['rssi'] as num).toInt();
      if (data['ssid'] != null && data['ssid'].toString().isNotEmpty && data['ssid'] != 'Unknown') {
        device.wifiSsid = data['ssid'];
      }
      if (data['version'] != null) device.firmwareVersion = data['version'];
      if (data['cam_version'] != null) device.camFirmwareVersion = data['cam_version'];
      
      // Handle special message types
      if (data['type'] == 'scan_results') {
        _isWifiScanning = false;
        _wifiScanResults = List<Map<String, dynamic>>.from(data['networks']);
        notifyListeners();
      } else if (data['type'] == 'wifi_status' || data['type'] == 'status_reset') {
        if (data['res'] == 'ok') {
          _wifiConfigResult = 'success';
        } else if (data['res'] == 'error' && data['msg'] == 'wifi_test_failed') {
          _wifiConfigResult = 'failed';
        }
        notifyListeners();
      } else {
        // Regular update - only notify if we are connected to avoid noise during handshake
        if (_isConnected) notifyListeners();
      }
    } catch (e) {
      debugPrint('[MQTT] Parse error: $e');
    }
  }

  void _startUptimeTimer() {
    _uptimeTimer?.cancel();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final device = activeDevice;
      if (device != null && _isConnected) {
        device.uptimeSeconds++;
        final h = device.uptimeSeconds ~/ 3600;
        final m = (device.uptimeSeconds % 3600) ~/ 60;
        final s = device.uptimeSeconds % 60;
        device.uptime = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        notifyListeners();
      }
    });
  }

  void _stopUptimeTimer() {
    _uptimeTimer?.cancel();
    _uptimeTimer = null;
  }

  void _startInfoPolling() {
    _infoPollingTimer?.cancel();
    _sendInfoCommand();
    _infoPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _sendInfoCommand();
    });
  }

  void _stopInfoPolling() {
    _infoPollingTimer?.cancel();
    _infoPollingTimer = null;
  }

  void setRelayUrl(String url) async {
    _relayUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('relayUrl', url);
    notifyListeners();
  }

  void _sendInfoCommand() {
    if ((_isConnected || _isConnecting)) {
      _latencyStopwatch.start();
      final cmd = jsonEncode({'cmd': 'status'});
      if (_isRemoteMode && _mqttClient != null) {
        final builder = MqttClientPayloadBuilder();
        builder.addString(cmd);
        _mqttClient!.publishMessage('robocar/control', MqttQos.atMostOnce, builder.payload!);
      } else if (!_isRemoteMode && _wsChannel != null) {
        _wsChannel!.sink.add(cmd);
      }
    }
  }

  // App & Firmware update tracking
  bool _isCheckingUpdates = false;
  bool _appUpdateAvailable = false;
  bool _mainFwUpdateAvailable = false;
  bool _camFwUpdateAvailable = false;
  
  Map<String, dynamic>? _updateMetadata;
  double _otaProgress = 0.0;
  String _otaStatus = '';
  String _latestAppVersion = '--';
  String _appChangelog = '';
  String _appDownloadUrl = '';
  String _appSha256 = '';

  // Getters
  bool get isCheckingUpdates => _isCheckingUpdates;
  bool get appUpdateAvailable => _appUpdateAvailable;
  bool get mainFwUpdateAvailable => _mainFwUpdateAvailable;
  bool get camFwUpdateAvailable => _camFwUpdateAvailable;
  double get otaProgress => _otaProgress;
  String get otaStatus => _otaStatus;
  String get latestAppVersion => _latestAppVersion;
  String get appChangelog => _appChangelog;
  String get appDownloadUrl => _appDownloadUrl;
  String get relayUrl => _relayUrl;

  Future<void> checkUpdates() async {
    if (_isCheckingUpdates) return;
    _isCheckingUpdates = true;
    notifyListeners();
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = 'https://raw.githubusercontent.com/Wann-99/esp32_smart_car_updates/refs/heads/main/version.json?t=$timestamp';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateMetadata = data;
        
        // Check App Update
        final packageInfo = await PackageInfo.fromPlatform();
        final currentAppVersionStr = packageInfo.version;
        _latestAppVersion = data['app']['version'];
        _appChangelog = data['app']['changelog'] ?? '';
        _appDownloadUrl = data['app']['url'] ?? '';
        _appSha256 = data['app']['sha256'] ?? '';
        
        _appUpdateAvailable = _isVersionHigher(_latestAppVersion, currentAppVersionStr);
        
        // Check Firmware Update
        _latestFirmwareVersion = data['firmware']['main']['version'];
        _latestCamFirmwareVersion = data['firmware']['camera']['version'];
        
        final device = activeDevice;
        if (device != null) {
          _mainFwUpdateAvailable = _isVersionHigher(_latestFirmwareVersion, device.firmwareVersion);
          _camFwUpdateAvailable = _isVersionHigher(_latestCamFirmwareVersion, device.camFirmwareVersion);
        }
      }
    } catch (e) {
      debugPrint('Check updates error: $e');
    } finally {
      _isCheckingUpdates = false;
      notifyListeners();
    }
  }

  bool _isVersionHigher(String latest, String current) {
    if (latest == '--' || current == '--') return false;
    try {
      final latestParts = latest.replaceAll('v', '').split('.').map(int.parse).toList();
      final currentParts = current.replaceAll('v', '').split('.').map(int.parse).toList();
      
      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (e) {
      return latest != current;
    }
  }

  Future<void> downloadAndInstallApp() async {
    if (_appDownloadUrl.isEmpty) return;
    
    _otaStatus = '正在下载更新包...';
    _otaProgress = 0.0;
    notifyListeners();
    
    try {
      final response = await http.Client().send(http.Request('GET', Uri.parse(_appDownloadUrl)));
      final total = response.contentLength ?? 0;
      int received = 0;
      
      final List<int> bytes = [];
      await for (final value in response.stream) {
        bytes.addAll(value);
        received += value.length;
        if (total > 0) {
          _otaProgress = received / total;
          notifyListeners();
        }
      }
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/app_update.apk');
      await file.writeAsBytes(bytes);
      
      // Verify SHA256 for App Update
      if (_appSha256.isNotEmpty) {
        final digest = sha256.convert(bytes);
        if (digest.toString().toLowerCase() != _appSha256.toLowerCase()) {
          _otaStatus = '安装包校验失败 (SHA256 不匹配)';
          notifyListeners();
          return;
        }
      }
      
      _otaStatus = '下载完成，正在准备安装...';
      _otaProgress = 1.0;
      notifyListeners();
      
      await OpenFile.open(file.path);
    } catch (e) {
      _otaStatus = '更新失败: $e';
      notifyListeners();
    }
  }

  Future<void> startOnlineOTA(String target) async {
    if (_updateMetadata == null || activeDevice == null) return;
    
    String url = '';
    String? expectedSha256;
    
    if (target == 'main') {
      url = _updateMetadata!['firmware']['main']['url'];
      expectedSha256 = _updateMetadata!['firmware']['main']['sha256'];
    } else if (target == 'camera') {
      url = _updateMetadata!['firmware']['camera']['url'];
      expectedSha256 = _updateMetadata!['firmware']['camera']['sha256'];
    }
    
    if (url.isEmpty) return;
    
    _otaStatus = '正在获取固件...';
    _otaProgress = 0.0;
    notifyListeners();
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // Verify SHA256 if provided
        if (expectedSha256 != null && expectedSha256.isNotEmpty) {
          final digest = sha256.convert(bytes);
          if (digest.toString().toLowerCase() != expectedSha256.toLowerCase()) {
            _otaStatus = '固件校验失败 (SHA256 不匹配)';
            notifyListeners();
            return;
          }
        }
        
        await _performOtaUpload(bytes, target);
      } else {
        _otaStatus = '获取固件失败: ${response.statusCode}';
        notifyListeners();
      }
    } catch (e) {
      _otaStatus = 'OTA 错误: $e';
      notifyListeners();
    }
  }

  Future<void> _performOtaUpload(List<int> bytes, String target) async {
    final device = activeDevice;
    if (device == null) return;
    
    final totalSize = bytes.length;
    const int chunkSize = 8192; // 8KB recommended
    int offset = 0;
    
    _otaStatus = '正在上传固件...';
    _otaProgress = 0.0;
    notifyListeners();
    
    try {
      // Step 1: Notify device to prepare for OTA
      final startUrl = 'http://${device.ip}/update?target=$target&size=$totalSize';
      final startResponse = await http.post(Uri.parse(startUrl)).timeout(const Duration(seconds: 5));
      
      if (startResponse.statusCode != 200) {
        _otaStatus = '设备拒绝 OTA 请求';
        notifyListeners();
        return;
      }
      
      // Step 2: Stream chunks
      while (offset < totalSize) {
        final end = (offset + chunkSize < totalSize) ? offset + chunkSize : totalSize;
        final chunk = bytes.sublist(offset, end);
        
        final uploadResponse = await http.post(
          Uri.parse('http://${device.ip}/upload'),
          body: chunk,
          headers: {'Content-Type': 'application/octet-stream', 'X-Offset': offset.toString()},
        ).timeout(const Duration(seconds: 10));
        
        if (uploadResponse.statusCode != 200) {
          _otaStatus = '分块上传失败 ($offset)';
          notifyListeners();
          return;
        }
        
        offset = end;
        _otaProgress = offset / totalSize;
        notifyListeners();
      }
      
      // Step 3: Finalize
      final finishResponse = await http.post(Uri.parse('http://${device.ip}/finalize')).timeout(const Duration(seconds: 15));
      if (finishResponse.statusCode == 200) {
        _otaStatus = '升级成功，设备正在重启...';
        _otaProgress = 1.0;
        notifyListeners();
        
        // Wait for reboot
        await Future.delayed(const Duration(seconds: 5));
        disconnect();
      } else {
        _otaStatus = '固件写入失败';
        notifyListeners();
      }
    } catch (e) {
      _otaStatus = '上传中断: $e';
      notifyListeners();
    }
  }

  void setVoltageByActual(double actualVoltage) async {
    final device = activeDevice;
    if (device != null && device.batteryVoltage > 0) {
      final newMultiplier = actualVoltage / device.batteryVoltage;
      device.voltageMultiplier = newMultiplier;
      await _saveDevices();
      notifyListeners();
    }
  }

  Future<void> rebootDevice() async {
    if (_isConnected) {
      final cmd = jsonEncode({'cmd': 'reboot'});
      if (_isRemoteMode && _mqttClient != null) {
        final builder = MqttClientPayloadBuilder();
        builder.addString(cmd);
        _mqttClient!.publishMessage('robocar/control', MqttQos.atMostOnce, builder.payload!);
      } else if (!_isRemoteMode && _wsChannel != null) {
        _wsChannel!.sink.add(cmd);
      }
    }
  }

  Future<void> factoryReset() async {
    if (_isConnected) {
      final cmd = jsonEncode({'cmd': 'factory_reset'});
      if (_isRemoteMode && _mqttClient != null) {
        final builder = MqttClientPayloadBuilder();
        builder.addString(cmd);
        _mqttClient!.publishMessage('robocar/control', MqttQos.atMostOnce, builder.payload!);
      } else if (!_isRemoteMode && _wsChannel != null) {
        _wsChannel!.sink.add(cmd);
      }
    }
  }

  Future<void> startLocalOTA(File file) async {
    final bytes = await file.readAsBytes();
    String filename = file.path.toLowerCase();
    String target = filename.contains('cam') ? 'camera' : 'main';
    
    await _performOtaUpload(bytes, target);
  }

  void startDeviceOTA() {
    // This is now replaced by startOnlineOTA or startLocalOTA
    // We can keep it as a wrapper for the 'main' update if needed
    startOnlineOTA('main');
  }

  void sendCommand(String cmd) {
    if (!_isConnected) return;
    if (_isRemoteMode && _mqttClient != null) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(cmd);
      _mqttClient!.publishMessage('robocar/control', MqttQos.atMostOnce, builder.payload!);
    } else if (!_isRemoteMode && _wsChannel != null) {
      _wsChannel!.sink.add(cmd);
    }
  }

  void scanWifi() {
    if (!_isConnected || _isWifiScanning) return;
    _isWifiScanning = true;
    _wifiScanResults = [];
    notifyListeners();
    sendCommand(jsonEncode({'cmd': 'scan_wifi'}));
    
    // Auto timeout if no response in 10s
    Timer(const Duration(seconds: 10), () {
      if (_isWifiScanning) {
        _isWifiScanning = false;
        notifyListeners();
      }
    });
  }

  void clearWifiConfigResult() {
    _wifiConfigResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanupConnection();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
