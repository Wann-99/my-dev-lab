/// 中国法定节假日 & 补班调休数据
/// type: 'off'  = 法定休假日
///       'work' = 调休补班（原本是周末需要上班）
///
/// 数据来源：国务院历年节假日安排通知
/// 2026 年数据依据日历规律推算，如与官方通知有出入请以官方为准
library;

class ChinaHoliday {
  final String name;
  /// 'off' = 休  /  'work' = 补班（上班）
  final String type;
  const ChinaHoliday(this.name, this.type);

  bool get isOff => type == 'off';
  bool get isWork => type == 'work';
}

class ChinaHolidayData {
  ChinaHolidayData._();

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 查询某天的节假日信息，返回 null 表示普通工作日/周末
  static ChinaHoliday? of(DateTime date) => _data[_key(date)];

  static bool isHoliday(DateTime date) => _data[_key(date)]?.isOff ?? false;
  static bool isMakeupWork(DateTime date) => _data[_key(date)]?.isWork ?? false;
  static String? labelOf(DateTime date) => _data[_key(date)]?.name;

  // ─────────────────────────────────────────────────────────────────────────
  // 数据表
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<String, ChinaHoliday> _data = {

    // ══════════════════════════════════════════
    //  2024 年
    // ══════════════════════════════════════════
    '2024-01-01': ChinaHoliday('元旦', 'off'),
    // 春节 2024-02-10（正月初一）
    '2024-02-04': ChinaHoliday('补班', 'work'),
    '2024-02-10': ChinaHoliday('春节', 'off'),
    '2024-02-11': ChinaHoliday('春节', 'off'),
    '2024-02-12': ChinaHoliday('春节', 'off'),
    '2024-02-13': ChinaHoliday('春节', 'off'),
    '2024-02-14': ChinaHoliday('春节', 'off'),
    '2024-02-15': ChinaHoliday('春节', 'off'),
    '2024-02-16': ChinaHoliday('春节', 'off'),
    '2024-02-17': ChinaHoliday('春节', 'off'),
    '2024-02-18': ChinaHoliday('补班', 'work'),
    // 清明节 2024-04-04
    '2024-04-04': ChinaHoliday('清明节', 'off'),
    '2024-04-05': ChinaHoliday('清明节', 'off'),
    '2024-04-06': ChinaHoliday('清明节', 'off'),
    '2024-04-07': ChinaHoliday('补班', 'work'),
    // 劳动节 2024-05-01
    '2024-04-28': ChinaHoliday('补班', 'work'),
    '2024-05-01': ChinaHoliday('劳动节', 'off'),
    '2024-05-02': ChinaHoliday('劳动节', 'off'),
    '2024-05-03': ChinaHoliday('劳动节', 'off'),
    '2024-05-04': ChinaHoliday('劳动节', 'off'),
    '2024-05-05': ChinaHoliday('劳动节', 'off'),
    '2024-05-11': ChinaHoliday('补班', 'work'),
    // 端午节 2024-06-10
    '2024-06-08': ChinaHoliday('补班', 'work'),
    '2024-06-10': ChinaHoliday('端午节', 'off'),
    // 中秋节 2024-09-17
    '2024-09-14': ChinaHoliday('补班', 'work'),
    '2024-09-15': ChinaHoliday('中秋节', 'off'),
    '2024-09-16': ChinaHoliday('中秋节', 'off'),
    '2024-09-17': ChinaHoliday('中秋节', 'off'),
    // 国庆节 2024-10-01
    '2024-09-29': ChinaHoliday('补班', 'work'),
    '2024-10-01': ChinaHoliday('国庆节', 'off'),
    '2024-10-02': ChinaHoliday('国庆节', 'off'),
    '2024-10-03': ChinaHoliday('国庆节', 'off'),
    '2024-10-04': ChinaHoliday('国庆节', 'off'),
    '2024-10-05': ChinaHoliday('国庆节', 'off'),
    '2024-10-06': ChinaHoliday('国庆节', 'off'),
    '2024-10-07': ChinaHoliday('国庆节', 'off'),
    '2024-10-12': ChinaHoliday('补班', 'work'),

    // ══════════════════════════════════════════
    //  2025 年
    // ══════════════════════════════════════════
    '2025-01-01': ChinaHoliday('元旦', 'off'),
    // 春节 2025-01-29（正月初一）
    '2025-01-26': ChinaHoliday('补班', 'work'),
    '2025-01-28': ChinaHoliday('除夕', 'off'),
    '2025-01-29': ChinaHoliday('春节', 'off'),
    '2025-01-30': ChinaHoliday('春节', 'off'),
    '2025-01-31': ChinaHoliday('春节', 'off'),
    '2025-02-01': ChinaHoliday('春节', 'off'),
    '2025-02-02': ChinaHoliday('春节', 'off'),
    '2025-02-03': ChinaHoliday('春节', 'off'),
    '2025-02-04': ChinaHoliday('春节', 'off'),
    '2025-02-08': ChinaHoliday('补班', 'work'),
    // 清明节 2025-04-04
    '2025-04-04': ChinaHoliday('清明节', 'off'),
    '2025-04-05': ChinaHoliday('清明节', 'off'),
    '2025-04-06': ChinaHoliday('清明节', 'off'),
    // 劳动节 2025-05-01
    '2025-04-27': ChinaHoliday('补班', 'work'),
    '2025-05-01': ChinaHoliday('劳动节', 'off'),
    '2025-05-02': ChinaHoliday('劳动节', 'off'),
    '2025-05-03': ChinaHoliday('劳动节', 'off'),
    '2025-05-04': ChinaHoliday('劳动节', 'off'),
    '2025-05-05': ChinaHoliday('劳动节', 'off'),
    // 端午节 2025-05-31（农历五月初五）
    '2025-05-31': ChinaHoliday('端午节', 'off'),
    '2025-06-01': ChinaHoliday('端午节', 'off'),
    '2025-06-02': ChinaHoliday('端午节', 'off'),
    // 国庆节 + 中秋节 2025-10-06
    '2025-09-28': ChinaHoliday('补班', 'work'),
    '2025-10-01': ChinaHoliday('国庆节', 'off'),
    '2025-10-02': ChinaHoliday('国庆节', 'off'),
    '2025-10-03': ChinaHoliday('国庆节', 'off'),
    '2025-10-04': ChinaHoliday('国庆节', 'off'),
    '2025-10-05': ChinaHoliday('国庆节', 'off'),
    '2025-10-06': ChinaHoliday('中秋节', 'off'),
    '2025-10-07': ChinaHoliday('国庆节', 'off'),
    '2025-10-08': ChinaHoliday('国庆节', 'off'),
    '2025-10-11': ChinaHoliday('补班', 'work'),

    // ══════════════════════════════════════════
    //  2026 年（依据日历规律推算）
    // ══════════════════════════════════════════
    // 元旦 2026-01-01（周四）
    '2026-01-01': ChinaHoliday('元旦', 'off'),
    '2026-01-02': ChinaHoliday('元旦', 'off'),
    '2026-01-03': ChinaHoliday('元旦', 'off'),
    '2026-01-04': ChinaHoliday('补班', 'work'),
    // 春节 2026-02-17（正月初一，周二）
    '2026-02-15': ChinaHoliday('补班', 'work'),
    '2026-02-16': ChinaHoliday('除夕', 'off'),
    '2026-02-17': ChinaHoliday('春节', 'off'),
    '2026-02-18': ChinaHoliday('春节', 'off'),
    '2026-02-19': ChinaHoliday('春节', 'off'),
    '2026-02-20': ChinaHoliday('春节', 'off'),
    '2026-02-21': ChinaHoliday('春节', 'off'),
    '2026-02-22': ChinaHoliday('春节', 'off'),
    '2026-02-23': ChinaHoliday('春节', 'off'),
    '2026-02-28': ChinaHoliday('补班', 'work'),
    // 清明节 2026-04-05（周日）
    '2026-04-04': ChinaHoliday('清明节', 'off'),
    '2026-04-05': ChinaHoliday('清明节', 'off'),
    '2026-04-06': ChinaHoliday('清明节', 'off'),
    '2026-04-12': ChinaHoliday('补班', 'work'),
    // 劳动节 2026-05-01（周五）
    '2026-04-26': ChinaHoliday('补班', 'work'),
    '2026-05-01': ChinaHoliday('劳动节', 'off'),
    '2026-05-02': ChinaHoliday('劳动节', 'off'),
    '2026-05-03': ChinaHoliday('劳动节', 'off'),
    '2026-05-04': ChinaHoliday('劳动节', 'off'),
    '2026-05-05': ChinaHoliday('劳动节', 'off'),
    '2026-05-09': ChinaHoliday('补班', 'work'),
    // 端午节 2026-06-20（农历五月初五，周六）
    '2026-06-19': ChinaHoliday('端午节', 'off'),
    '2026-06-20': ChinaHoliday('端午节', 'off'),
    '2026-06-21': ChinaHoliday('端午节', 'off'),
    // 中秋节 2026-09-25（周五）
    '2026-09-25': ChinaHoliday('中秋节', 'off'),
    '2026-09-26': ChinaHoliday('中秋节', 'off'),
    '2026-09-27': ChinaHoliday('中秋节', 'off'),
    // 国庆节 2026-10-01（周四）
    '2026-10-01': ChinaHoliday('国庆节', 'off'),
    '2026-10-02': ChinaHoliday('国庆节', 'off'),
    '2026-10-03': ChinaHoliday('国庆节', 'off'),
    '2026-10-04': ChinaHoliday('国庆节', 'off'),
    '2026-10-05': ChinaHoliday('国庆节', 'off'),
    '2026-10-06': ChinaHoliday('国庆节', 'off'),
    '2026-10-07': ChinaHoliday('国庆节', 'off'),
    '2026-10-10': ChinaHoliday('补班', 'work'),
  };
}
