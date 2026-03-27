/// 农历转换 + 二十四节气 + 文化节日
///
/// 算法：以各年正月初一的公历日期为基点，累计各月天数
/// 数据覆盖 2020-2030 年，2027 年后为推算值
library;

import 'package:space_time_plan_app/data/chinese_holidays.dart';

// ─────────────────────────────────────────────────────────────────
// 数据结构
// ─────────────────────────────────────────────────────────────────
class LunarDate {
  final int lunarYear;
  final int month;
  final int day;
  final bool isLeapMonth;
  const LunarDate({
    required this.lunarYear,
    required this.month,
    required this.day,
    required this.isLeapMonth,
  });
}

/// 春节日期用 int 存储，避免 DateTime 无 const 构造器的问题
class _YearInfo {
  final int sy, sm, sd;  // 正月初一公历 年/月/日
  final int leapMonth;   // 0=无闰月，否则为闰月月份编号
  final List<int> days;  // 各月天数（12 或 13 元素）
  const _YearInfo(this.sy, this.sm, this.sd, this.leapMonth, this.days);
  DateTime get spring => DateTime(sy, sm, sd);
}

// ─────────────────────────────────────────────────────────────────
// 农历年数据（已验证 2020-2026，2027+ 推算）
// ─────────────────────────────────────────────────────────────────
const List<_YearInfo> _kYears = [
  // 2020 庚子 鼠，闰四月
  _YearInfo(2020,1,25, 4,  [30,30,29,29,30,29,30,29,30,29,30,30,29]),
  // 2021 辛丑 牛，无闰月
  _YearInfo(2021,2,12, 0,  [29,30,29,30,29,30,30,29,30,29,30,29]),
  // 2022 壬寅 虎，无闰月
  _YearInfo(2022,2,1,  0,  [30,29,30,29,30,29,30,29,30,30,29,30]),
  // 2023 癸卯 兔，闰二月
  _YearInfo(2023,1,22, 2,  [29,30,29,29,30,29,30,29,30,30,29,30,30]),
  // 2024 甲辰 龙，无闰月
  _YearInfo(2024,2,10, 0,  [30,29,30,29,29,30,29,30,29,30,30,29]),
  // 2025 乙巳 蛇，闰六月
  _YearInfo(2025,1,29, 6,  [30,29,30,29,30,29,29,30,29,30,29,30,30]),
  // 2026 丙午 马，无闰月
  _YearInfo(2026,2,17, 0,  [30,29,30,29,30,29,30,29,30,30,29,29]),
  // 2027 丁未 羊，闰五月（推算）
  _YearInfo(2027,2,6,  5,  [30,29,29,30,29,30,29,30,29,30,30,29,30]),
  // 2028 戊申 猴，无闰月（推算）
  _YearInfo(2028,1,26, 0,  [29,30,29,30,29,30,29,30,29,30,29,30]),
  // 2029 己酉 鸡，闰六月（推算）
  _YearInfo(2029,2,13, 6,  [30,29,30,29,30,29,30,29,30,29,30,29,30]),
  // 2030 庚戌 狗，无闰月（推算）
  _YearInfo(2030,2,3,  0,  [29,30,29,30,29,30,29,30,30,29,30,29]),
];

const _kBaseYear = 2020;

// ─────────────────────────────────────────────────────────────────
// 公开 API
// ─────────────────────────────────────────────────────────────────
class LunarCalendar {
  LunarCalendar._();

  static const _monthNames = ['正','二','三','四','五','六','七','八','九','十','冬','腊'];
  static const _dayNames = [
    '初一','初二','初三','初四','初五','初六','初七','初八','初九','初十',
    '十一','十二','十三','十四','十五','十六','十七','十八','十九','二十',
    '廿一','廿二','廿三','廿四','廿五','廿六','廿七','廿八','廿九','三十',
  ];
  static const _tianGan  = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
  static const _diZhi    = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
  static const _shengXiao= ['鼠','牛','虎','兔','龙','蛇','马','羊','猴','鸡','狗','猪'];

  // ── 公历转农历 ──────────────────────────────────────────────────
  static LunarDate fromSolar(DateTime solar) {
    final date = DateTime(solar.year, solar.month, solar.day);

    // 找对应农历年索引
    int yi = 0;
    for (int i = 0; i < _kYears.length - 1; i++) {
      final next = _kYears[i + 1].spring;
      if (!DateTime(next.year, next.month, next.day).isAfter(date)) {
        yi = i + 1;
      } else {
        break;
      }
    }
    final ly   = _kYears[yi];
    final spr  = DateTime(ly.spring.year, ly.spring.month, ly.spring.day);
    int remaining = date.difference(spr).inDays;

    for (int i = 0; i < ly.days.length; i++) {
      final cnt = ly.days[i];
      if (remaining < cnt) {
        int logicalMonth;
        bool isLeap;
        if (ly.leapMonth == 0 || i < ly.leapMonth) {
          logicalMonth = i + 1;
          isLeap = false;
        } else if (i == ly.leapMonth) {
          logicalMonth = ly.leapMonth;
          isLeap = true;
        } else {
          logicalMonth = i; // after leap slot
          isLeap = false;
        }
        return LunarDate(
          lunarYear: _kBaseYear + yi,
          month: logicalMonth,
          day: remaining + 1,
          isLeapMonth: isLeap,
        );
      }
      remaining -= cnt;
    }
    // fallback: next year 正月初一
    return LunarDate(
        lunarYear: _kBaseYear + yi + 1, month: 1, day: 1, isLeapMonth: false);
  }

  // ── 日期格子副标签（优先级：节日名 > 节气 > 文化节 > 农历传统 > 农历日期）─
  static String getSubLabel(DateTime date) {
    // 1. 法定节日名（只在首日显示）
    final holiday = ChinaHolidayData.of(date);
    if (holiday != null && holiday.isOff) {
      final prev = date.subtract(const Duration(days: 1));
      final prevH = ChinaHolidayData.of(prev);
      if (prevH == null || prevH.name != holiday.name || prevH.isWork) {
        return holiday.name;
      }
    }

    // 2. 节气
    final term = _solarTerms[_key(date)];
    if (term != null) return term;

    // 3. 文化节日（元宵、七夕等固定公历节日）
    final cultural = _culturalHolidays[_key(date)];
    if (cultural != null) return cultural;

    // 4. 农历传统节日
    final l = fromSolar(date);
    final lunarTrad = _lunarFestivalOf(l);
    if (lunarTrad != null) return lunarTrad;

    // 5. 农历日期
    if (l.day == 1) {
      return '${l.isLeapMonth ? "闰" : ""}${_monthNames[l.month - 1]}月';
    }
    return _dayNames[l.day - 1];
  }

  /// 底部信息栏完整农历描述
  static String getFullLabel(DateTime date) {
    final l = fromSolar(date);
    final base = l.lunarYear - 1924;
    final tg = _tianGan[base % 10];
    final dz = _diZhi[base % 12];
    final sx = _shengXiao[base % 12];
    final mStr =
        '${l.isLeapMonth ? "闰" : ""}${_monthNames[l.month - 1]}月';
    final dStr = _dayNames[l.day - 1];
    return '$tg$dz年[$sx] $mStr$dStr';
  }

  /// 农历月名（用于首日显示）
  static String monthName(int m) => '${_monthNames[m - 1]}月';

  /// 判断某天是否是二十四节气
  static bool isSolarTerm(DateTime date) =>
      _solarTerms.containsKey(_key(date));

  // ── 内部工具 ────────────────────────────────────────────────────
  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? _lunarFestivalOf(LunarDate l) {
    if (!l.isLeapMonth) {
      switch ('${l.month}-${l.day}') {
        case '1-1':   return '春节';
        case '1-15':  return '元宵节';
        case '5-5':   return '端午节';
        case '7-7':   return '七夕节';
        case '7-15':  return '中元节';
        case '8-15':  return '中秋节';
        case '9-9':   return '重阳节';
        case '12-8':  return '腊八节';
        case '12-30': return '除夕';
      }
      // 除夕（腊月廿九且下一天是正月初一）
      if (l.month == 12 && l.day == 29) return '除夕';
    }
    return null;
  }

  // ── 二十四节气（2025-2027）──────────────────────────────────────
  static const Map<String, String> _solarTerms = {
    // 2024
    '2024-01-06': '小寒', '2024-01-20': '大寒',
    '2024-02-04': '立春', '2024-02-19': '雨水',
    '2024-03-05': '惊蛰', '2024-03-20': '春分',
    '2024-04-04': '清明', '2024-04-19': '谷雨',
    '2024-05-05': '立夏', '2024-05-20': '小满',
    '2024-06-05': '芒种', '2024-06-21': '夏至',
    '2024-07-06': '小暑', '2024-07-22': '大暑',
    '2024-08-07': '立秋', '2024-08-22': '处暑',
    '2024-09-07': '白露', '2024-09-22': '秋分',
    '2024-10-08': '寒露', '2024-10-23': '霜降',
    '2024-11-07': '立冬', '2024-11-22': '小雪',
    '2024-12-06': '大雪', '2024-12-21': '冬至',
    // 2025
    '2025-01-05': '小寒', '2025-01-20': '大寒',
    '2025-02-03': '立春', '2025-02-18': '雨水',
    '2025-03-06': '惊蛰', '2025-03-20': '春分',
    '2025-04-04': '清明', '2025-04-20': '谷雨',
    '2025-05-05': '立夏', '2025-05-21': '小满',
    '2025-06-06': '芒种', '2025-06-21': '夏至',
    '2025-07-07': '小暑', '2025-07-22': '大暑',
    '2025-08-07': '立秋', '2025-08-23': '处暑',
    '2025-09-07': '白露', '2025-09-23': '秋分',
    '2025-10-08': '寒露', '2025-10-23': '霜降',
    '2025-11-07': '立冬', '2025-11-22': '小雪',
    '2025-12-07': '大雪', '2025-12-22': '冬至',
    // 2026
    '2026-01-05': '小寒', '2026-01-20': '大寒',
    '2026-02-04': '立春', '2026-02-19': '雨水',
    '2026-03-06': '惊蛰', '2026-03-20': '春分',
    '2026-04-05': '清明', '2026-04-20': '谷雨',
    '2026-05-05': '立夏', '2026-05-21': '小满',
    '2026-06-06': '芒种', '2026-06-21': '夏至',
    '2026-07-07': '小暑', '2026-07-22': '大暑',
    '2026-08-07': '立秋', '2026-08-23': '处暑',
    '2026-09-08': '白露', '2026-09-23': '秋分',
    '2026-10-08': '寒露', '2026-10-23': '霜降',
    '2026-11-07': '立冬', '2026-11-22': '小雪',
    '2026-12-07': '大雪', '2026-12-22': '冬至',
    // 2027
    '2027-01-06': '小寒', '2027-01-20': '大寒',
    '2027-02-04': '立春', '2027-02-19': '雨水',
    '2027-03-06': '惊蛰', '2027-03-21': '春分',
    '2027-04-05': '清明', '2027-04-20': '谷雨',
    '2027-05-06': '立夏', '2027-05-21': '小满',
    '2027-06-06': '芒种', '2027-06-21': '夏至',
    '2027-07-07': '小暑', '2027-07-23': '大暑',
    '2027-08-07': '立秋', '2027-08-23': '处暑',
    '2027-09-08': '白露', '2027-09-23': '秋分',
    '2027-10-08': '寒露', '2027-10-23': '霜降',
    '2027-11-07': '立冬', '2027-11-22': '小雪',
    '2027-12-07': '大雪', '2027-12-22': '冬至',
  };

  // ── 文化/纪念节日（公历固定 + 动态节日预计算）─────────────────────
  static const Map<String, String> _culturalHolidays = {
    // 固定公历节日
    '2025-03-08': '妇女节', '2026-03-08': '妇女节', '2027-03-08': '妇女节',
    '2025-03-12': '植树节', '2026-03-12': '植树节', '2027-03-12': '植树节',
    '2025-05-04': '青年节', '2026-05-04': '青年节', '2027-05-04': '青年节',
    '2025-06-01': '儿童节', '2026-06-01': '儿童节', '2027-06-01': '儿童节',
    '2025-08-01': '建军节', '2026-08-01': '建军节', '2027-08-01': '建军节',
    '2025-09-10': '教师节', '2026-09-10': '教师节', '2027-09-10': '教师节',
    '2025-11-11': '光棍节', '2026-11-11': '光棍节', '2027-11-11': '光棍节',
    '2025-12-25': '圣诞节', '2026-12-25': '圣诞节', '2027-12-25': '圣诞节',
    // 动态节日（预计算）
    '2025-05-11': '母亲节',  // 5月第二个周日
    '2026-05-10': '母亲节',
    '2027-05-09': '母亲节',
    '2025-06-15': '父亲节',  // 6月第三个周日
    '2026-06-21': '父亲节',
    '2027-06-20': '父亲节',
  };
}
