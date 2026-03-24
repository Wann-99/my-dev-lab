import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';
import 'network_mgmt_page.dart';
import 'about_page.dart';
import 'advanced_settings_page.dart';
import 'device_config_page.dart';
import 'more_settings_page.dart';
import '../utils/ui_utils.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Stack(
          children: [
            // 1. Background Area
            _buildTopArea(state),
            
            // 2. Content Area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 140, 16, 40),
              child: Column(
                children: [
                  _buildGroup(
                    title: '网络与连接',
                    children: [
                      _buildListItem(
                        title: '网络设置', 
                        trailingText: state.isConnected ? state.wifiSsid : '未连接',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NetworkMgmtPage())),
                      ),
                      _buildDivider(),
                      _buildListItem(
                        title: 'MQTT 服务器配置',
                        trailingText: state.relayUrl.isEmpty ? '未配置' : state.relayUrl,
                        onTap: () => _showRelayUrlDialog(context, state),
                      ),
                      _buildDivider(),
                      _buildListItem(
                        title: '远程控制模式',
                        trailingWidget: Switch(
                          value: state.isRemoteMode,
                          onChanged: (val) {
                            if (val && state.relayUrl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先设置 MQTT 服务器地址')));
                              _showRelayUrlDialog(context, state);
                              return;
                            }
                            state.saveAllSettings(newIsRemoteMode: val);
                            if (val && state.isConnected) {
                              // Send relay config to device if turning on
                              state.sendCommand(jsonEncode({
                                "cmd": "set_relay",
                                "url": state.relayUrl,
                                "id": state.activeDevice?.id ?? "unknown"
                              }));
                            }
                          },
                          activeTrackColor: const Color(0xFF29B6F6),
                          activeThumbColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  _buildGroup(
                    title: '高级设置',
                    children: [
                      _buildListItem(
                        title: '全局急停按钮显示',
                        trailingWidget: Switch(
                          value: state.showEmergencyStop,
                          onChanged: (val) {
                            state.saveAllSettings(newShowEmergencyStop: val);
                          },
                          activeTrackColor: const Color(0xFF29B6F6),
                          activeThumbColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  _buildGroup(
                    title: '更多设置',
                    children: [
                      _buildListItem(
                        title: '多语言切换', 
                        trailingText: state.locale.languageCode == 'zh' ? '简体中文' : 'English',
                        onTap: () => _showLanguageBottomSheet(context, state, l10n),
                      ),
                      _buildDivider(),
                      _buildListItem(
                        title: '系统校准测试', 
                        trailingText: '电压/舵机',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdvancedSettingsPage())),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  _buildGroup(
                    title: '关于 RoboCar-A',
                    children: [
                      _buildListItem(
                        title: '功能介绍',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AboutPage())),
                      ),
                      _buildDivider(),
                      _buildListItem(
                        title: '检查更新 (App)', 
                        trailingText: state.appUpdateAvailable ? '发现新版本' : 'v${state.currentAppVersion}',
                        trailingWidget: state.isCheckingUpdates 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : null,
                        onTap: () => _handleAppUpdateCheck(context, state),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopArea(CarState state) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF29B6F6),
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            Color(0xFF64B5F6),
            Color(0xFF29B6F6),
            Color(0xFF0288D1),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RoboCar-A',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _blinkController,
                        builder: (context, child) {
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4ADE80).withOpacity(0.4 + (_blinkController.value * 0.6)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4ADE80).withOpacity(_blinkController.value * 0.8),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '系统运行正常',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF999999),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildListItem({required String title, String? trailingText, Widget? trailingWidget, bool isDestructive = false, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? const Color(0xFFFF5252) : const Color(0xFF333333),
        ),
      ),
      trailing: trailingWidget ?? (trailingText != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingText,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 20),
              ],
            )
          : const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 20)),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0));
  }

  void _showRelayUrlDialog(BuildContext context, CarState state) {
    final controller = TextEditingController(text: state.relayUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置 MQTT 服务器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入 MQTT 服务器地址（如: 192.168.1.100 或 mqtt.example.com）', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "服务器地址",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              state.setRelayUrl(controller.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF29B6F6)),
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleAppUpdateCheck(BuildContext context, CarState state) async {
    if (state.isCheckingUpdates) return;
    
    await state.checkUpdates();
    
    if (!mounted) return;
    
    if (state.appUpdateAvailable) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Consumer<CarState>(
          builder: (context, state, child) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('发现新版本'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('版本号: v${state.latestAppVersion}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF29B6F6))),
                const SizedBox(height: 12),
                if (state.appChangelog.isNotEmpty) ...[
                  const Text('更新内容：', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(state.appChangelog, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                  const SizedBox(height: 16),
                ],
                if (state.otaStatus.isNotEmpty) ...[
                  Text(state.otaStatus, style: const TextStyle(fontSize: 13, color: Color(0xFF29B6F6))),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.otaProgress,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF29B6F6)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ],
            ),
            actions: [
              if (state.otaProgress <= 0)
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('以后再说')),
              if (state.otaProgress <= 0)
                ElevatedButton(
                  onPressed: () => state.downloadAndInstallApp(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF29B6F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('立即更新'),
                ),
              if (state.otaProgress > 0 && state.otaProgress < 1.0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              if (state.otaProgress >= 1.0)
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
    }
  }

  void _showLanguageBottomSheet(BuildContext context, CarState state, AppLocalizations l10n) {
    UIUtils.showAppBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.language, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              title: const Text("简体中文"),
              trailing: state.locale.languageCode == 'zh' ? const Icon(Icons.check, color: Color(0xFF29B6F6)) : null,
              onTap: () {
                state.setLocale(const Locale('zh'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("English"),
              trailing: state.locale.languageCode == 'en' ? const Icon(Icons.check, color: Color(0xFF29B6F6)) : null,
              onTap: () {
                state.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
