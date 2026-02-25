import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';

class NetworkConfigPage extends StatefulWidget {
  final String baseIp; // Defaults to 192.168.4.1 (SoftAP) or user input
  const NetworkConfigPage({super.key, this.baseIp = "192.168.4.1"});

  @override
  State<NetworkConfigPage> createState() => _NetworkConfigPageState();
}

class _NetworkConfigPageState extends State<NetworkConfigPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ipController = TextEditingController();
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isSuccess = false;
  String _statusMessage = "";
  List<dynamic> _wifiList = [];

  @override
  void initState() {
    super.initState();
    _ipController.text = widget.baseIp;
  }

  Future<void> _scanWifi() async {
    setState(() {
      _isScanning = true;
      _statusMessage = "正在扫描 WiFi...";
    });

    final ip = _ipController.text;
    final url = Uri.parse("http://$ip/wifi/scan");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _wifiList = data;
          _statusMessage = "扫描完成，找到 ${data.length} 个网络";
        });
        _showWifiPicker();
      } else {
        setState(() => _statusMessage = "扫描失败: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _statusMessage = "扫描出错: $e");
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showWifiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView.builder(
        itemCount: _wifiList.length,
        itemBuilder: (context, index) {
          final wifi = _wifiList[index];
          return ListTile(
            leading: const Icon(Icons.wifi, color: Color(0xFF00F0FF)),
            title: Text(wifi['ssid'] ?? "未知 SSID", style: const TextStyle(color: Colors.white)),
            subtitle: Text("信号: ${wifi['rssi']} dBm", style: const TextStyle(color: Colors.grey)),
            onTap: () {
              setState(() {
                _ssidController.text = wifi['ssid'];
              });
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Future<void> _saveNetwork() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _isSuccess = false;
      _statusMessage = l10n.sendingConfig;
    });

    final ip = _ipController.text;
    final url = Uri.parse("http://$ip/wifi");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "ssid": _ssidController.text,
          "password": _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _isSuccess = true;
          _statusMessage = l10n.wifiConfigSuccess;
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(content: Text(l10n.wifiConfigSuccess)),
            );
        }
      } else {
        setState(() {
          _isSuccess = false;
          _statusMessage = l10n.wifiConfigFailed(response.statusCode.toString());
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = l10n.error(e.toString());
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkConfig),
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFF00F0FF),
      ),
      backgroundColor: const Color(0xFF050510),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                 const Icon(Icons.wifi_tethering, size: 80, color: Color(0xFF00F0FF)),
                 const SizedBox(height: 32),
                 Text(
                   l10n.wifiConfigTip,
                   textAlign: TextAlign.center,
                   style: const TextStyle(color: Colors.grey, fontSize: 16),
                 ),
                 const SizedBox(height: 24),
                 
                 TextField(
                   controller: _ipController,
                   decoration: InputDecoration(
                     labelText: l10n.deviceIpDefault,
                     prefixIcon: const Icon(Icons.computer, color: Color(0xFF00F0FF)),
                   ),
                   keyboardType: TextInputType.number,
                   style: const TextStyle(color: Colors.white),
                 ),
                 const SizedBox(height: 16),
                 
                 TextField(
                   controller: _ssidController,
                   decoration: InputDecoration(
                     labelText: l10n.wifiSsid,
                     prefixIcon: const Icon(Icons.wifi, color: Color(0xFF00F0FF)),
                     suffixIcon: IconButton(
                       icon: _isScanning 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search, color: Color(0xFF00F0FF)),
                       onPressed: _isScanning ? null : _scanWifi,
                     ),
                   ),
                   style: const TextStyle(color: Colors.white),
                 ),
                 const SizedBox(height: 16),
                 
                 TextField(
                   controller: _passwordController,
                   obscureText: true,
                   decoration: InputDecoration(
                     labelText: l10n.wifiPassword,
                     prefixIcon: const Icon(Icons.lock, color: Color(0xFF00F0FF)),
                   ),
                   style: const TextStyle(color: Colors.white),
                 ),
                 const SizedBox(height: 32),
                 
                 if (_isLoading)
                   const CircularProgressIndicator(color: Color(0xFF00F0FF))
                 else
                   ElevatedButton(
                     onPressed: _saveNetwork,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF00F0FF),
                       foregroundColor: Colors.black,
                       minimumSize: const Size(double.infinity, 50),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     child: Text(l10n.save, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   ),
                 
                 if (_statusMessage.isNotEmpty)
                   Padding(
                     padding: const EdgeInsets.only(top: 24.0),
                     child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                   ),
              ],
            )
          ),
        ),
      ),
    );
  }
}
