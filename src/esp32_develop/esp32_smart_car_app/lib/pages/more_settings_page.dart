import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_state.dart';

class MoreSettingsPage extends StatelessWidget {
  const MoreSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更多设置'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection(
            '使用统计',
            [
              _buildTile('累计行驶时间', '12 小时 45 分', Icons.timer_outlined),
              _buildTile('累计行驶里程', '5.2 km', Icons.straighten_rounded),
              _buildTile('启动次数', '86 次', Icons.power_settings_new_rounded),
            ],
          ),
          const SizedBox(height: 32),
          _buildSection(
            '日志管理',
            [
              _buildTile('导出运行日志', 'CSV 格式', Icons.file_download_outlined, showArrow: true),
              _buildTile('清除缓存数据', '12.5 MB', Icons.delete_outline_rounded, isDestructive: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 12),
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTile(String title, String value, IconData icon, {bool showArrow = false, bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : const Color(0xFF29B6F6), size: 22),
      title: Text(title, style: TextStyle(fontSize: 15, color: isDestructive ? Colors.redAccent : const Color(0xFF1E293B))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
          if (showArrow) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC)),
          ],
        ],
      ),
      onTap: () {},
    );
  }
}
