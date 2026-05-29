import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/car_state.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_utils.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  bool _showManualAdd = false;
  final TextEditingController _ipController = TextEditingController();
  String? _expandedDeviceId;
  double? _tempMaxSpeed;
  String? _tempResolution;
  String? _tempTrackingTarget;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    // Auto-collapse if switched away from this tab (DevicePage is at index 1)
    if (state.currentTabIndex != 1 && (_expandedDeviceId != null || _showManualAdd)) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _expandedDeviceId = null;
            _tempMaxSpeed = null;
            _tempResolution = null;
            _tempTrackingTarget = null;
            _showManualAdd = false;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Bar
            const Text(
              '设备管理',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      state.startDiscovery();
                      _showDiscoveryDialog(context, state, l10n);
                    },
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: const Text('局域网发现'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showManualAdd = !_showManualAdd;
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('手动添加'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF29B6F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            
            // Manual Add Panel
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _showManualAdd ? 80 : 0,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          decoration: InputDecoration(
                            hintText: '输入设备 IP',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final ip = _ipController.text.trim();
                          if (ip.isNotEmpty) {
                            // Use IP as temporary ID for manual addition
                            await state.bindDevice(ip, "Current User", ip: ip);
                            state.connect();
                            setState(() {
                              _showManualAdd = false;
                              _ipController.clear();
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF29B6F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('连接', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Device List Area (Accordion)
            if (state.isBound)
              Column(
                children: state.boundDevices.map((device) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildDeviceCard(state, device, l10n),
                )).toList(),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Icon(Icons.devices_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('暂无绑定设备', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(CarState state, DeviceConfig device, AppLocalizations l10n) {
    final bool isActive = state.activeDevice?.id == device.id;
    final bool isConnected = isActive && state.isConnected;
    final bool isExpanded = _expandedDeviceId == device.id && state.currentTabIndex == 1;

    return Slidable(
      key: ValueKey('slidable_${device.id}'),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (context) {
              if (!isActive) {
                state.setActiveDevice(device.id).then((_) {
                  if (state.isConnected) state.rebootDevice();
                });
              } else if (isConnected) {
                state.rebootDevice();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先连接设备')));
              }
            },
            backgroundColor: const Color(0xFF29B6F6),
            foregroundColor: Colors.white,
            icon: Icons.restart_alt_rounded,
            label: '重启',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          ),
          SlidableAction(
            onPressed: (context) {
              _showFactoryResetConfirm(context, state, device);
            },
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.factory_rounded,
            label: '重置',
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isActive ? Border.all(color: const Color(0xFF29B6F6).withOpacity(0.3), width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            key: ValueKey('${device.id}_${_expandedDeviceId == device.id}_${state.currentTabIndex == 1}'),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedDeviceId = device.id;
                } else if (_expandedDeviceId == device.id) {
                  _expandedDeviceId = null;
                }
                // Reset temp parameters whenever expansion state changes
                // This ensures that if parameters weren't saved, they revert to actual state
                _tempMaxSpeed = null;
                _tempResolution = null;
                _tempTrackingTarget = null;
              });

              if (expanded) {
                Future.microtask(() {
                  if (mounted && !isActive) {
                    state.setActiveDevice(device.id);
                  }
                });
              }
            },
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                boxShadow: [
                  if (isConnected)
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                ],
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    device.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showRenameDialog(context, state, device),
                  child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                device.ip.isEmpty ? '未设置 IP' : device.ip,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (!isActive) {
                      state.setActiveDevice(device.id).then((_) => state.connect());
                    } else {
                      if (state.isConnected) {
                        state.disconnect();
                      } else {
                        state.connect();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? const Color(0xFFF1F5F9) : const Color(0xFF29B6F6).withOpacity(0.1),
                    foregroundColor: isConnected ? const Color(0xFFEF4444) : const Color(0xFF29B6F6),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isConnected ? '断开连接' : '立即连接',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_right_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 24),
                    
                    // Basic Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.show_chart_rounded, color: Color(0xFF29B6F6), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '基础信息',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow('主控 IP', device.ip.isEmpty ? '--' : device.ip),
                    _buildInfoRow('摄像头 IP', device.cameraIp.isEmpty ? '192.168.1.103' : device.cameraIp),
                    _buildInfoRow('MAC地址', isConnected ? (state.macAddress == '--' ? '正在获取...' : state.macAddress) : '--'),
                    _buildInfoRow('在线时长', isConnected ? state.uptime : '--'),
                    
                    const SizedBox(height: 24),
                    
                    // Firmware Upgrade Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.memory_rounded, color: Color(0xFF64748B), size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '固件升级 (OTA)',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildMCUUpgradeRow(
                            '主 MCU 核心固件', 
                            state.currentFirmwareVersion, 
                            state.latestFirmwareVersion,
                            () => state.startOnlineOTA('main'),
                            state.mainFwUpdateAvailable,
                            isConnected,
                          ),
                          const SizedBox(height: 12),
                          _buildMCUUpgradeRow(
                            '摄像头 MCU 固件', 
                            state.currentCamFirmwareVersion, 
                            state.latestCamFirmwareVersion,
                            () => state.startOnlineOTA('camera'),
                            state.camFwUpdateAvailable,
                            isConnected,
                          ),
                          if (state.otaStatus.isNotEmpty && isActive) ...[
                            const SizedBox(height: 16),
                            Text(state.otaStatus, style: const TextStyle(fontSize: 13, color: Color(0xFF29B6F6))),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: state.otaProgress,
                              backgroundColor: Colors.white,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF29B6F6)),
                              minHeight: 6,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Device Parameter Settings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, color: Color(0xFF29B6F6), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '设备参数设置',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: isConnected ? () {
                            // Map friendly resolution back to code
                            String? mappedResolution;
                            if (_tempResolution != null) {
                              mappedResolution = _tempResolution!.contains('FHD') ? '1080P' : 
                                                (_tempResolution!.contains('HD') ? '720P' : 'VGA');
                            }

                            state.saveDeviceSettings(
                              maxSpeed: _tempMaxSpeed,
                              resolution: mappedResolution,
                              trackingTarget: _tempTrackingTarget,
                            );

                            // Send commands to device
                            if (_tempMaxSpeed != null) {
                              state.sendCommand(jsonEncode({"cmd": "speed", "value": (_tempMaxSpeed! * 100).toInt()}));
                            }
                            if (mappedResolution != null) {
                              state.sendCommand(jsonEncode({"cmd": "resolution", "value": mappedResolution}));
                            }
                            if (_tempTrackingTarget != null) {
                              state.sendCommand(jsonEncode({"cmd": "track", "target": _tempTrackingTarget}));
                            }

                            // Clear temp states after saving to reflect true state
                            setState(() {
                              _tempMaxSpeed = null;
                              _tempResolution = null;
                              _tempTrackingTarget = null;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('参数保存成功并生效')),
                            );
                          } : null,
                          icon: const Icon(Icons.save_rounded, color: Color(0xFF29B6F6)),
                          tooltip: '保存参数',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Speed Control
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('电机速度控制', style: TextStyle(fontSize: 15, color: Color(0xFF475569))),
                        Text('${((_tempMaxSpeed ?? state.maxSpeed) * 100).toInt()}%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      ),
                      child: Slider(
                        value: (_tempMaxSpeed ?? state.maxSpeed) * 100,
                        min: 10,
                        max: 100,
                        activeColor: const Color(0xFF29B6F6),
                        inactiveColor: const Color(0xFFE2E8F0),
                        onChanged: isConnected ? (val) {
                          setState(() {
                            _tempMaxSpeed = val / 100;
                          });
                        } : null,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    const Text('摄像头分辨率', style: TextStyle(fontSize: 15, color: Color(0xFF475569))),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _tempResolution ?? (state.resolution == '1080P' ? '1920x1080 (FHD)' : (state.resolution == '720P' ? '1280x720 (HD)' : '640x480 (VGA)')),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                      items: ['1920x1080 (FHD)', '1280x720 (HD)', '640x480 (VGA)'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B))),
                        );
                      }).toList(),
                      onChanged: isConnected ? (val) {
                        if (val != null) {
                          setState(() {
                            _tempResolution = val;
                          });
                        }
                      } : null,
                    ),

                    const SizedBox(height: 20),
                    const Text('AI 跟踪对象', style: TextStyle(fontSize: 15, color: Color(0xFF475569))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTargetChip('Person', '人物', _tempTrackingTarget ?? state.trackingTarget, isConnected),
                        const SizedBox(width: 12),
                        _buildTargetChip('Cat', '猫咪', _tempTrackingTarget ?? state.trackingTarget, isConnected),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),
                    
                    // Delete Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          state.unbindDevice(device.id);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        label: const Text('删除设备', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }

  void _showRenameDialog(BuildContext context, CarState state, DeviceConfig device) {
    final controller = TextEditingController(text: device.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改设备名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "请输入新的设备名称"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                state.renameDevice(device.id, controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF29B6F6)),
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFactoryResetConfirm(BuildContext context, CarState state, DeviceConfig device) {
    final bool isActive = state.activeDevice?.id == device.id;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复出厂设置'),
        content: const Text('此操作将重置设备的所有网络设置和控制参数并重启，确定继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (!isActive) {
                state.setActiveDevice(device.id).then((_) {
                  if (state.isConnected) state.factoryReset();
                });
              } else if (state.isConnected) {
                state.factoryReset();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先连接设备')));
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('重置', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
          Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMCUUpgradeRow(String title, String currentVer, String? newVer, VoidCallback onUpgrade, bool hasUpdate, bool isConnected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text('当前版本: $currentVer', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        if (hasUpdate)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '发现新版本',
              style: TextStyle(color: Color(0xFFEF5350), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ElevatedButton.icon(
          onPressed: isConnected ? (hasUpdate ? onUpgrade : () => context.read<CarState>().checkUpdates()) : null,
          icon: hasUpdate ? const Icon(Icons.file_download_outlined, size: 16) : null,
          label: Text(
            hasUpdate ? '立即升级' : '检查更新',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasUpdate ? const Color(0xFF2962FF) : const Color(0xFFF1F5F9),
            foregroundColor: hasUpdate ? Colors.white : const Color(0xFF475569),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetChip(String value, String label, String current, bool isEnabled) {
    final bool isSelected = current == value;
    return InkWell(
      onTap: isEnabled ? () => setState(() => _tempTrackingTarget = value) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF29B6F6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _showDiscoveryDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    UIUtils.showAppBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.searchingDevices, 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))
                  ),
                  if (state.isDiscovering)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF29B6F6)))
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF29B6F6)), 
                      onPressed: () => state.startDiscovery()
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Consumer<CarState>(
                  builder: (context, state, child) {
                    if (state.discoveredDevices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFE0E0E0)),
                            const SizedBox(height: 16),
                            Text(
                              state.isDiscovering ? l10n.searching : l10n.noDevicesFound,
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 15),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: state.discoveredDevices.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final device = state.discoveredDevices[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF29B6F6).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.directions_car_rounded, color: Color(0xFF29B6F6)),
                            ),
                            title: Text(
                              device['id'] ?? 'Unknown Device', 
                              style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)
                            ),
                            subtitle: Text(
                              "IP: ${device['ip']}", 
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 13)
                            ),
                            onTap: () async {
                              await state.bindDevice(device['id']!, "Current User", ip: device['ip']);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.bindSuccess), 
                                    backgroundColor: const Color(0xFF66BB6A),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                                state.connect();
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
