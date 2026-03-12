import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/car_state.dart';
import 'device_config_page.dart';
import 'network_mgmt_page.dart';
import 'more_settings_page.dart';
import 'login_page.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF64B5F6), // Blue 400
              Color(0xFFBBDEFB), // Blue 100
              Color(0xFFF5F6FA), // Light Gray
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar.large(
                title: Text(
                  l10n.mine, 
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 0.5, 
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  )
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                stretch: true,
                pinned: true,
              ),
              SliverToBoxAdapter(
                child: _buildUserHeader(context, state, l10n),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Extra bottom padding
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMenuSection(
                      context,
                      [
                        _buildMenuItem(
                          context, 
                          Icons.settings_suggest_rounded, 
                          l10n.deviceSettings, 
                          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeviceConfigPage())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildMenuSection(
                      context,
                      [
                        _buildMenuItem(
                          context, 
                          Icons.wifi_rounded, 
                          l10n.networkConfig, 
                          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NetworkMgmtPage())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildMenuSection(
                      context,
                      [
                        _buildMenuItem(
                          context, 
                          Icons.more_horiz_rounded, 
                          l10n.moreSettings,
                          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MoreSettingsPage())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _buildLogoutButton(context, l10n),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85), // Glass effect
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF29B6F6).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        },
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF5252), size: 22),
        label: Text(
          l10n.logout,
          style: const TextStyle(
            color: Color(0xFFFF5252),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFFFEBEE).withValues(alpha: 0.8), // Slight transparency
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, CarState state, AppLocalizations l10n) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85), // Glass effect
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'avatar',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 32, 
                  backgroundColor: primaryColor.withValues(alpha: 0.1), 
                  child: Icon(Icons.person_rounded, size: 40, color: primaryColor)
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.admin, 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333), letterSpacing: 0.5)
                  ),
                  const SizedBox(height: 6),
                  state.isBound 
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link_rounded, size: 14, color: primaryColor),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  state.deviceId,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Text(
                        l10n.unbound,
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color? color}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final itemColor = color ?? primaryColor;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: itemColor, size: 22),
      ),
      title: Text(
        title, 
        style: const TextStyle(
          color: Color(0xFF333333), 
          fontSize: 16, 
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        )
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 22),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
