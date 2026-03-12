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
      _statusMessage = "Scanning WiFi...";
    });

    final ip = _ipController.text;
    final url = Uri.parse("http://$ip/wifi/scan");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _wifiList = data;
          _statusMessage = "Scan complete. Found ${data.length} networks.";
        });
        if (mounted) _showWifiPicker();
      } else {
        setState(() => _statusMessage = "Scan failed: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _statusMessage = "Scan error: $e");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showWifiPicker() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text("Available Networks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _wifiList.length,
                itemBuilder: (context, index) {
                  final wifi = _wifiList[index];
                  return ListTile(
                    leading: Icon(Icons.wifi_rounded, color: primaryColor),
                    title: Text(wifi['ssid'] ?? "Unknown SSID", style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text("Signal: ${wifi['rssi']} dBm", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    onTap: () {
                      setState(() {
                        _ssidController.text = wifi['ssid'];
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
              SnackBar(
                content: Text(l10n.wifiConfigSuccess),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          l10n.networkConfig,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.wifi_tethering_rounded, size: 48, color: primaryColor),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.wifiConfigTip,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildTextField(
                        controller: _ipController,
                        label: l10n.deviceIpDefault,
                        icon: Icons.computer_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      
                      _buildTextField(
                        controller: _ssidController,
                        label: l10n.wifiSsid,
                        icon: Icons.wifi_rounded,
                        suffix: IconButton(
                          icon: _isScanning 
                           ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                           : Icon(Icons.search_rounded, color: primaryColor),
                          onPressed: _isScanning ? null : _scanWifi,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildTextField(
                        controller: _passwordController,
                        label: l10n.wifiPassword,
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                      ),
                      const SizedBox(height: 32),
                      
                      if (_isLoading)
                        CircularProgressIndicator(color: primaryColor)
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveNetwork,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(l10n.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      
                      if (_statusMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isSuccess ? Colors.green : Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Color(0xFF333333), fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF999999)),
        floatingLabelStyle: TextStyle(color: primaryColor),
        prefixIcon: Icon(icon, color: primaryColor, size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
