import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/widgets/glass_card.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  String _nickname = '习惯达人';
  static const _nicknameKey = 'profile_nickname';

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_nicknameKey);
    if (saved != null && mounted) {
      setState(() => _nickname = saved);
    }
  }

  Future<void> _saveNickname(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, name);
  }

  void _showEditProfile() {
    final ctrl = TextEditingController(text: _nickname);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('编辑昵称',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 16,
                style: const TextStyle(
                    fontSize: 16, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: '输入昵称',
                  hintStyle: const TextStyle(color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.bgMain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppTheme.primary, width: 1.5),
                  ),
                  counterStyle:
                      const TextStyle(color: AppTheme.textHint, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = ctrl.text.trim();
                    if (name.isNotEmpty) {
                      setState(() => _nickname = name);
                      _saveNickname(name);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('保存',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // whenComplete 在 pop 后作为微任务立即触发，此时动画还在进行中，
      // TextField 仍挂载在树上，立即 dispose 会触发 "used after disposed" 崩溃。
      // 延迟到动画结束（~250ms）后再 dispose。
      Future.delayed(const Duration(milliseconds: 350), ctrl.dispose);
    });
  }

  void _showSimpleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Text(content,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final streak = provider.currentStreak;
    final totalCheckIns = provider.totalCheckIns;
    final formed = provider.formedHabitsCount;
    final rate = provider.recentCompletionRate;

    // 昵称首字作为头像字母
    final avatarLetter =
        _nickname.isNotEmpty ? _nickname.characters.first : '习';

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text('我的',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // 设置入口（可扩展）
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          size: 20, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),

            // ── 主体滚动区 ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 头部用户卡片 ────────────────────────────────
                    _buildProfileCard(avatarLetter, streak),
                    const SizedBox(height: 16),

                    // ── 数据统计卡片 ────────────────────────────────
                    _buildStatsCard(totalCheckIns, formed, rate),
                    const SizedBox(height: 24),

                    // ── 功能列表 ────────────────────────────────────
                    _buildSectionTitle('服务与设置'),
                    const SizedBox(height: 10),
                    CleanCard(
                      borderRadius: 18,
                      child: Column(
                        children: [
                          _buildListTile(
                            icon: Icons.notifications_outlined,
                            iconColor: AppTheme.primary,
                            title: '提醒设置',
                            onTap: () => _showSimpleDialog(
                                '提醒设置',
                                '习惯提醒通知在「添加/编辑习惯」时进行设置，'
                                    '开启「每日提醒」开关后系统将在指定时间推送通知。'),
                          ),
                          _buildDivider(),
                          _buildListTile(
                            icon: Icons.help_outline_rounded,
                            iconColor: AppTheme.statusBlue,
                            title: '帮助与反馈',
                            onTap: () => _showSimpleDialog(
                                '帮助与反馈',
                                '如有任何问题或建议，欢迎通过以下方式联系我们：\n\n'
                                    '• 发送邮件至 support@example.com\n'
                                    '• 在应用商店留下评论\n\n'
                                    '感谢您的支持与反馈！'),
                          ),
                          _buildDivider(),
                          _buildListTile(
                            icon: Icons.info_outline_rounded,
                            iconColor: AppTheme.statusOrange,
                            title: '关于习惯打卡 App',
                            onTap: () => _showSimpleDialog(
                                '关于习惯打卡',
                                '习惯打卡 · 时空计划\n\n'
                                    '版本：V1.0.0\n\n'
                                    '致力于帮助您建立良好的日常习惯，通过科学的方式'
                                    '坚持每一天，成就更好的自己。\n\n'
                                    '© 2026 习惯打卡团队'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── 底部说明 ────────────────────────────────────
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 头部用户卡片 ─────────────────────────────────────────────────
  Widget _buildProfileCard(String avatarLetter, int streak) {
    return CleanCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // 头像
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: AppTheme.primaryShadow(AppTheme.primary),
            ),
            child: Center(
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 昵称 + 连续打卡
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nickname,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.statusOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 14,
                              color: AppTheme.statusOrange),
                          const SizedBox(width: 3),
                          Text(
                            '连续 $streak 天',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.statusOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 编辑按钮
          GestureDetector(
            onTap: _showEditProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '编辑资料',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 数据统计卡片 ─────────────────────────────────────────────────
  Widget _buildStatsCard(int totalCheckIns, int formed, int rate) {
    return CleanCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Row(
        children: [
          _buildStatItem(
            '$totalCheckIns',
            '次',
            '累计打卡',
            Icons.check_circle_outline_rounded,
            AppTheme.primary,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            '$formed',
            '个',
            '已养成',
            Icons.emoji_events_outlined,
            AppTheme.statusOrange,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            '$rate',
            '%',
            '完成率',
            Icons.pie_chart_outline_rounded,
            AppTheme.statusBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String value, String unit, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 60,
      color: AppTheme.divider,
    );
  }

  // ── 分区标题 ─────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── 列表项 ───────────────────────────────────────────────────────
  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textHint)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 66,
      endIndent: 16,
      color: AppTheme.divider,
    );
  }

  // ── 底部版本 / 协议 ──────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink('用户协议', () => _showSimpleDialog(
                '用户协议',
                '欢迎使用习惯打卡 App。\n\n使用本应用即表示您同意遵守相关服务条款。\n\n'
                    '本应用收集的数据仅用于提供服务，不会与第三方共享。')),
            _buildFooterSep(),
            _buildFooterLink('隐私政策', () => _showSimpleDialog(
                '隐私政策',
                '我们重视您的隐私。\n\n所有习惯数据均存储在您的设备本地，'
                    '不会上传至服务器。\n\n如有疑问，请系我们。')),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'V 1.0.0',
          style: TextStyle(fontSize: 12, color: AppTheme.textHint),
        ),
        const SizedBox(height: 4),
        const Text(
          '© 2026 习惯打卡团队',
          style: TextStyle(fontSize: 11, color: AppTheme.textHint),
        ),
      ],
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
          decoration: TextDecoration.underline,
          decorationColor: AppTheme.textHint,
        ),
      ),
    );
  }

  Widget _buildFooterSep() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('|',
          style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
    );
  }
}
