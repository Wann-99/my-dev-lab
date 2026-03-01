import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'advanced_settings_page.dart';
import 'about_page.dart';

class MoreSettingsPage extends StatelessWidget {
  const MoreSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text("更多设置"), centerTitle: true),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text("通用", style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          _buildMenuItem(context, Icons.restore, "恢复出厂设置", () {
            _showFactoryResetDialog(context, state, l10n);
          }),
          _buildMenuItem(context, Icons.restart_alt, "重启设备", () {
            _showRebootDialog(context, state, l10n);
          }),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 12),
            child: Text("语言", style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          _buildMenuItem(context, Icons.language, l10n.language, () {
            _showLanguageDialog(context, state, l10n);
          }),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 12),
            child: Text("隐私与安全", style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          _buildMenuItem(context, Icons.description, "个人信息收集清单", () {
            _showPrivacyListDialog(context);
          }),
          _buildMenuItem(context, Icons.privacy_tip, "隐私政策摘要", () {
            _showPrivacySummaryDialog(context);
          }),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 12),
            child: Text("关于", style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          _buildMenuItem(
            context,
            Icons.info_outline,
            l10n.aboutRoboCar,
            () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutPage()));
            },
            badge: state.hasAppUpdate ? "NEW" : null,
          ),
          _buildMenuItem(
            context,
            Icons.system_update,
            "固件更新",
            () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdvancedSettingsPage()));
            },
          ),
        ],
      ),
    );
  }

  void _showFactoryResetDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.factoryReset),
        content: Text(l10n.factoryResetConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () async {
              await state.factoryReset();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.factoryResetSuccess), backgroundColor: Colors.green),
                );
              }
            },
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRebootDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rebootDevice),
        content: Text(l10n.rebootConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              state.rebootDevice();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.rebooting)),
              );
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showPrivacyListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text("个人信息收集清单"),
        content: Text(
          "本应用仅收集实现设备控制所必需的信息，例如：\n"
          "1. 设备标识（如设备ID，用于绑定与管理）\n"
          "2. 网络信息（如设备IP，用于局域网连接）\n"
          "3. 基本使用数据（如固件版本，用于升级与兼容性判断）\n\n"
          "不采集与上述目的无关的敏感个人信息。",
        ),
      ),
    );
  }

  void _showPrivacySummaryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text("隐私政策摘要"),
        content: Text(
          "RoboCar-A 将严格按照最小必要原则使用您的信息，仅用于设备连接、控制与固件升级等功能。\n"
          "除法律法规要求或获得您明确同意外，不会向第三方提供您的个人信息。\n"
          "详细隐私条款请参考随产品提供的完整隐私政策。",
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, CarState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.english),
              trailing: state.locale.languageCode == 'en' ? const Icon(Icons.check, color: Color(0xFF00F0FF)) : null,
              onTap: () {
                state.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.chinese),
              trailing: state.locale.languageCode == 'zh' ? const Icon(Icons.check, color: Color(0xFF00F0FF)) : null,
              onTap: () {
                state.setLocale(const Locale('zh'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {String? badge}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00F0FF)),
      title: Row(
        children: [
          Text(title),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
