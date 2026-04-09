import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';

class NetworkMgmtPage extends StatefulWidget {
  const NetworkMgmtPage({super.key});

  @override
  State<NetworkMgmtPage> createState() => _NetworkMgmtPageState();
}

class _NetworkMgmtPageState extends State<NetworkMgmtPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    // Auto start scan if connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<CarState>();
      if (state.isConnected) {
        state.scanWifi();
      }
    });
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('网络配置', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          if (state.isWifiScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: state.isConnected ? () => state.scanWifi() : null,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Connection
            _buildSectionTitle('当前连接'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    state.isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: state.isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isConnected ? state.wifiSsid : '未连接',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          state.isConnected ? '信号强度: ${state.rssi}dBm' : '请先连接到设备热点',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Available Networks
            _buildSectionTitle('可用 WiFi 列表'),
            const SizedBox(height: 12),
            if (!state.isConnected)
              _buildEmptyState('请先连接到设备')
            else if (state.isWifiScanning && state.wifiScanResults.isEmpty)
              _buildLoadingState('正在扫描附近 WiFi...')
            else if (state.wifiScanResults.isEmpty)
              _buildEmptyState('未发现可用 WiFi')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.wifiScanResults.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final net = state.wifiScanResults[index];
                  return _buildWifiItem(net, state, l10n);
                },
              ),
            
            const SizedBox(height: 32),
            _buildInfoCard(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiItem(Map<String, dynamic> net, CarState state, AppLocalizations l10n) {
    final ssid = net['ssid'] ?? 'Unknown';
    final rssi = net['rssi'] ?? -100;
    // Explicitly convert int (0/1) to bool to avoid "type 'int' is not a subtype of type 'bool'"
    final dynamic secureVal = net['secure'];
    final bool isSecure = secureVal is int ? secureVal != 0 : (secureVal as bool? ?? true);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          _getWifiIcon(rssi),
          color: const Color(0xFF29B6F6),
        ),
        title: Text(ssid, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: isSecure ? const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)) : null,
        onTap: () => _showConnectDialog(ssid, state, l10n),
      ),
    );
  }

  IconData _getWifiIcon(int rssi) {
    if (rssi > -60) return Icons.wifi_rounded;
    if (rssi > -75) return Icons.wifi_2_bar_rounded;
    return Icons.wifi_1_bar_rounded;
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.wifi_find_rounded, size: 48, color: const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Text(msg, style: const TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 20),
            Text(msg, style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  void _showConnectDialog(String ssid, CarState state, AppLocalizations l10n) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('连接到 $ssid', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入 WiFi 密码',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setDialogState(() => _isObscure = !_isObscure),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('连接成功后设备将自动重启并尝试加入该网络', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleConnect(ssid, _passwordController.text, state, l10n);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF29B6F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleConnect(String ssid, String password, CarState state, AppLocalizations l10n) {
    state.clearWifiConfigResult();
    
    // Show connecting status
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer<CarState>(
        builder: (context, state, child) {
          if (state.wifiConfigResult == 'success') {
            Future.delayed(Duration.zero, () {
              Navigator.pop(context); // Close dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('WiFi 验证通过，设备正在重启并应用设置'), backgroundColor: Colors.green),
              );
              Navigator.pop(context); // Go back
            });
          } else if (state.wifiConfigResult == 'failed') {
            Future.delayed(Duration.zero, () {
              Navigator.pop(context); // Close dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('WiFi 密码错误或无法连接，请重试'), backgroundColor: Colors.red),
              );
              state.clearWifiConfigResult();
            });
          }

          return Center(
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF29B6F6)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '正在验证并连接',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '这可能需要几秒钟...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.normal,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Send command with test flag
    state.sendCommand(jsonEncode({
      "cmd": "wifi_config",
      "ssid": ssid,
      "password": password,
      "test": true
    }));

    // Safety timeout
    Future.delayed(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (state.wifiConfigResult == null) {
        Navigator.of(context, rootNavigator: true).pop(); // Force close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('验证超时，请检查设备状态')),
        );
      }
    });
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
    );
  }

  Widget _buildInfoCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF0288D1), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.wifiConfigTip,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0277BD), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
