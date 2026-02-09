import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '智能监控',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0D47A1),
          secondary: Color(0xFF00B0FF),
          surface: Color(0xFF1E1E1E),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00B0FF), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString('last_ip') ?? 'esp32cam.local';
    });
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_ip', ip);
  }

  Future<String?> _resolveHostname(String hostname) async {
    if (!hostname.endsWith('.local')) return hostname;

    setState(() => _statusMessage = 'Resolving $hostname...');
    
    try {
      final MDnsClient client = MDnsClient();
      await client.start();
      
      // Look for the IP address of the service
      // Note: We search for the address record directly
      await for (final IPAddressResourceRecord record
          in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(hostname))) {
        client.stop();
        return record.address.address;
      }
      client.stop();
    } catch (e) {
      debugPrint('mDNS error: $e');
    }
    
    return null;
  }

  Future<void> _resetWifi() async {
    final input = _ipController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter IP/Hostname first')),
      );
      return;
    }

    // Confirm dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset WiFi?'),
        content: const Text(
          'This will clear WiFi settings on the ESP32-CAM and reboot it.\n\n'
          'After reboot, it will create a hotspot "ESP32-CAM-Setup" for you to connect and configure new WiFi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Sending reset command...';
    });

    String targetIp = input;
    if (input.toLowerCase().endsWith('.local')) {
      final resolved = await _resolveHostname(input);
      if (resolved != null) targetIp = resolved;
    }

    try {
      final url = Uri.parse('http://$targetIp:8080/reset_wifi');
      // Use a short timeout because the device might reboot immediately
      await http.get(url).timeout(const Duration(seconds: 3));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset command sent! Please connect to "ESP32-CAM-Setup" hotspot.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // It's possible the request fails if the device reboots too fast, which is fine
      debugPrint('Reset request error (expected): $e');
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Command sent (or timed out). Check if device is rebooting.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = 'Device resetting... Connect to its hotspot.';
        });
      }
    }
  }

  void _connect() async {
    final input = _ipController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting...';
    });
    
    await _saveIp(input);

    String targetIp = input;
    
    // Attempt mDNS resolution if it's a .local address
    if (input.toLowerCase().endsWith('.local')) {
      final resolved = await _resolveHostname(input);
      if (resolved != null) {
        targetIp = resolved;
        setState(() => _statusMessage = 'Resolved to $targetIp');
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        setState(() => _statusMessage = 'Could not resolve $input, trying anyway...');
      }
    }

    setState(() => _isConnecting = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StreamPage(url: 'http://$targetIp/stream')),
      );
    }
  }

  void _openWifiSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WifiSetupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ESP32-CAM Pro', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.wifi_off, color: Colors.redAccent),
              tooltip: 'Reset Device WiFi',
              onPressed: _isConnecting ? null : _resetWifi,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF121212), Color(0xFF121212)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Hero(
                  tag: 'camera_icon',
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B0FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00B0FF).withOpacity(0.2), width: 2),
                    ),
                    child: const Icon(Icons.videocam_rounded, size: 80, color: Color(0xFF00B0FF)),
                  ),
                ),
                const SizedBox(height: 40),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          'Connection Settings',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _ipController,
                          style: const TextStyle(fontSize: 16),
                          decoration: const InputDecoration(
                            labelText: 'Device IP or Hostname',
                            hintText: 'esp32cam.local',
                            prefixIcon: Icon(Icons.lan_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_statusMessage.isNotEmpty)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _statusMessage,
                              style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isConnecting ? null : _connect,
                          icon: _isConnecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_circle_fill_rounded),
                          label: Text(_isConnecting ? 'Processing...' : 'Start Monitoring'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white54),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.wifi_find_rounded,
                        title: 'WiFi Setup',
                        subtitle: 'Initial config',
                        onTap: _openWifiSetup,
                        color: Colors.tealAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.system_update_alt_rounded,
                        title: 'OTA Update',
                        subtitle: 'Update firmware',
                        onTap: () {
                          // Show info about OTA
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Access http://esp32cam.local:8080/update in browser')),
                          );
                        },
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Make sure your device is powered on and connected to the same network.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class StreamPage extends StatelessWidget {
  final String url;

  const StreamPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Live Feed', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              // Simple way to refresh: pop and push again
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => StreamPage(url: url)));
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Hero(
              tag: 'camera_icon',
              child: Mjpeg(
                isLive: true,
                stream: url,
                timeout: const Duration(seconds: 7),
                loading: (context) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00B0FF)),
                    SizedBox(height: 20),
                    Text('Establishing Secure Stream...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                error: (context, error, stack) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 24),
                        const Text(
                          'Stream Unavailable',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Could not connect to the camera. Please check if the device is online.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Return to Settings'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text(
                      DateTime.now().toString().split('.')[0].split(' ')[1],
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WifiSetupPage extends StatefulWidget {
  const WifiSetupPage({super.key});

  @override
  State<WifiSetupPage> createState() => _WifiSetupPageState();
}

class _WifiSetupPageState extends State<WifiSetupPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Initialize WebViewController
    final WebViewController controller = WebViewController();
    
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Handle error, maybe device not connected to AP
          },
        ),
      )
      ..loadRequest(Uri.parse('http://192.168.4.1'));

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.orange.withOpacity(0.2),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '1. Connect your phone to "ESP32-CAM-Setup" WiFi.\n2. Use this page to configure your home WiFi.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
