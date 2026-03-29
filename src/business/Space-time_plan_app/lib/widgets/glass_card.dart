import 'package:flutter/material.dart';

/// ────────────────────────────────────────────────────
///  全局主题常量  —— 清新极简白
/// ────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // 背景
  static const bgMain      = Color(0xFFF8FFF8); // 极浅绿白大背景
  static const bgCard      = Color(0xFFFFFFFF); // 纯白卡片
  static const bgSecondary = Color(0xFFF2F9F2); // 次级区域

  // 主色 —— 薄荷绿系
  static const primary      = Color(0xFF4CAF50); // 薄荷绿
  static const primaryLight = Color(0xFFE8F5E9); // 浅绿填充
  static const primaryDark  = Color(0xFF388E3C); // 深绿强调

  // 辅色 —— 浅青系
  static const secondary      = Color(0xFF4FC3F7); // 浅青
  static const secondaryLight = Color(0xFFE1F5FE); // 浅青填充

  // 状态色（低饱和）
  static const statusGreen  = Color(0xFF66BB6A);
  static const statusBlue   = Color(0xFF4FC3F7);
  static const statusOrange = Color(0xFFFFB74D);
  static const statusRed    = Color(0xFFEF5350);

  // 文字
  static const textPrimary   = Color(0xFF333333);
  static const textSecondary = Color(0xFF888888);
  static const textHint      = Color(0xFFBBBBBB);

  // 线条 / 分割
  static const divider = Color(0xFFF0F0F0);
  static const border  = Color(0xFFE8E8E8);

  // 极淡卡片阴影
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  // 绿色强调阴影
  static List<BoxShadow> primaryShadow(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.28),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];
}

/// ────────────────────────────────────────────────────
///  CleanCard —— 白底圆角极淡阴影卡片
/// ────────────────────────────────────────────────────
class CleanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final Color? borderColor;

  const CleanCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.color,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? AppTheme.bgCard,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.2)
              : null,
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      ),
    );
  }
}

/// 彩色图标圆（不带毛玻璃，简洁版）
class ColorIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String? heroTag;

  const ColorIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final w = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.46),
    );
    if (heroTag != null) return Hero(tag: heroTag!, child: w);
    return w;
  }
}
