import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import '../utils/ui_utils.dart';
import 'advanced_settings_page.dart';
import 'about_page.dart';

class MoreSettingsPage extends StatelessWidget {
  const MoreSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.moreSettings, 
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF333333))
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            stretch: true,
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSection("General", [
                  _buildMenuItem(context, Icons.language_rounded, l10n.language, () {
                    _showLanguageBottomSheet(context, state, l10n);
                  }),
                ]),
                const SizedBox(height: 20),
                _buildSection("System", [
                  _buildMenuItem(
                    context, 
                    Icons.admin_panel_settings_rounded, 
                    l10n.advancedSettings, 
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdvancedSettingsPage())),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSection("App", [
                  _buildMenuItem(
                    context, 
                    Icons.info_outline_rounded, 
                    l10n.aboutRoboCar, 
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutPage())),
                    badge: state.hasAppUpdate ? "NEW" : null,
                  ),
                ]),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageBottomSheet(BuildContext context, CarState state, AppLocalizations l10n) {
    UIUtils.showAppBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              l10n.language, 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333), letterSpacing: 0.5)
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildLanguageItem(
                    context, 
                    "简体中文", 
                    "Chinese", 
                    state.locale.languageCode == 'zh', 
                    () => state.setLocale(const Locale('zh'))
                  ),
                  Divider(height: 1, color: Colors.black.withValues(alpha: 0.05), indent: 20, endIndent: 20),
                  _buildLanguageItem(
                    context, 
                    "English", 
                    "English", 
                    state.locale.languageCode == 'en', 
                    () => state.setLocale(const Locale('en'))
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem(BuildContext context, String title, String subtitle, bool isSelected, VoidCallback onTap) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      title: Text(
        title, 
        style: TextStyle(
          color: isSelected ? primaryColor : const Color(0xFF333333), 
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 16,
        )
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle, 
          style: TextStyle(color: const Color(0xFF999999), fontSize: 13)
        ),
      ),
      trailing: isSelected 
        ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 24) 
        : null,
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title, 
            style: const TextStyle(
              color: Color(0xFF999999), 
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            )
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
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

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {String? badge}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: primaryColor, size: 22),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title, 
              style: const TextStyle(
                color: Color(0xFF333333), 
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 22),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
