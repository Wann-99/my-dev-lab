import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/models/habit.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';

class AddHabitView extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const AddHabitView({
    super.key,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<AddHabitView> createState() => _AddHabitViewState();
}

class _AddHabitViewState extends State<AddHabitView> {
  final TextEditingController _nameController = TextEditingController();
  String _freqType = 'fixed'; // fixed, weekly, monthly
  
  // Specific time point variables
  int _timeHour = 12;
  int _timeMinute = 0;
  int _timeSecond = 0;

  String _iconKey = 'self_improvement';
  int _colorValue = 0xFF5599FF;

  DateTime _startDate = DateTime.now();
  // Reminder variables
  int _remindHour = 8;
  int _remindMinute = 0;
  int _remindSecond = 0;
  
  // Switches
  bool _multiTarget = false;
  bool _autoPopup = true;
  bool _enableReminder = true; // 是否开启每日提醒通知

  // Selected days for frequency
  final Set<int> _weeklyDays = {1, 2, 3, 4, 5, 6, 7}; // 1 = Monday, 7 = Sunday
  final Set<int> _monthlyDays = {1}; // 1 = 1st of the month
  
  // Available options for selection
  final List<int> _colorOptions = [0xFF5599FF, 0xFF44CC88, 0xFFFF9933, 0xFFFF5555, 0xFFAA8855, 0xFF9966CC];
  final List<Map<String, dynamic>> _iconOptions = [
    {'key': 'self_improvement', 'icon': Icons.self_improvement},
    {'key': 'face', 'icon': Icons.face},
    {'key': 'menu_book', 'icon': Icons.menu_book},
    {'key': 'fitness_center', 'icon': Icons.fitness_center},
    {'key': 'directions_run', 'icon': Icons.directions_run},
    {'key': 'favorite', 'icon': Icons.favorite},
    {'key': 'music_note', 'icon': Icons.music_note},
    {'key': 'brush', 'icon': Icons.brush},
    {'key': 'local_cafe', 'icon': Icons.local_cafe}
  ];

  // Target Goals
  String _targetUnit = '次';
  int _planAmount = 1;
  int _perCheckAmount = 1;

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入习惯名称')),
      );
      return;
    }
    final normalized = name.toLowerCase();
    final exists = context
        .read<HabitProvider>()
        .habits
        .any((h) => h.title.trim().toLowerCase() == normalized);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已存在相同名称的习惯，请修改名称')),
      );
      return;
    }

    List<int> finalDays = [];
    if (_freqType == 'fixed') {
      finalDays = [1, 2, 3, 4, 5, 6, 7];
    } else if (_freqType == 'weekly') {
      finalDays = _weeklyDays.toList();
    } else {
      finalDays = _monthlyDays.toList();
    }
    finalDays.sort();

    final String unit = _multiTarget ? _targetUnit : '次';
    final int dailyTarget = _multiTarget ? _planAmount : 1;
    final int perComplete = _multiTarget ? _perCheckAmount : 1;

    final newHabit = HabitPlan(
      id: DateTime.now().millisecondsSinceEpoch,
      title: name,
      iconKey: _iconKey,
      colorValue: _colorValue,
      repeatType: _freqType,
      repeatDays: finalDays,
      timeOfDay: '${_timeHour.toString().padLeft(2, '0')}:${_timeMinute.toString().padLeft(2, '0')}',
      remindTime: _enableReminder
          ? DateTime(
              _startDate.year, _startDate.month, _startDate.day,
              _remindHour, _remindMinute, _remindSecond)
          : null,
      startDate: _startDate,
      unit: unit,
      dailyTarget: dailyTarget,
      perComplete: perComplete,
      multiTarget: _multiTarget,
      autoPopup: _autoPopup,
      // 默认不配置打卡心得；实际打卡时由打卡弹窗录入/编辑。
      checkInNote: null,
      autoReset: true,
      completedDate: null,
    );

    context.read<HabitProvider>().addHabit(newHabit);
    widget.onSave();
  }

  IconData _getIconData(String key) {
    return _iconOptions.firstWhere((e) => e['key'] == key, orElse: () => _iconOptions[0])['icon'];
  }

  void _showIconColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择颜色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _colorOptions.map((colorVal) => GestureDetector(
                        onTap: () {
                          setModalState(() => _colorValue = colorVal);
                          setState(() => _colorValue = colorVal);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Color(colorVal).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: _colorValue == colorVal ? Border.all(color: Color(colorVal), width: 2) : null,
                          ),
                          child: Icon(Icons.circle, color: Color(colorVal), size: 20),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('选择图标', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _iconOptions.map((iconMap) => GestureDetector(
                        onTap: () {
                          setModalState(() => _iconKey = iconMap['key']);
                          setState(() => _iconKey = iconMap['key']);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                            border: _iconKey == iconMap['key'] ? Border.all(color: Colors.blue, width: 2) : null,
                          ),
                          child: Icon(iconMap['icon'], color: Colors.grey[700], size: 20),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showTargetSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        const Text('每日打卡目标', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text('保存', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Unit
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('这个习惯的单位', style: TextStyle(fontSize: 16)),
                            Container(
                              width: 100,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                controller: TextEditingController(text: _targetUnit),
                                onChanged: (val) {
                                  _targetUnit = val;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Plan Amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('每天计划完成量', style: TextStyle(fontSize: 16)),
                            Container(
                              width: 100,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                controller: TextEditingController(text: _planAmount.toString()),
                                onChanged: (val) {
                                  _planAmount = int.tryParse(val) ?? 1;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Per Check Amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('每次打卡完成量', style: TextStyle(fontSize: 16)),
                            Container(
                              width: 100,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                controller: TextEditingController(text: _perCheckAmount.toString()),
                                onChanged: (val) {
                                  _perCheckAmount = int.tryParse(val) ?? 1;
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        // Example text
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                                child: const Text('例', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('每天计划跑步100分钟，每次打卡完成20分钟', style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showCustomTimePicker(String type, {bool isReminder = false}) {
    int initialValue;
    if (isReminder) {
      initialValue = type == 'hour' ? _remindHour : (type == 'minute' ? _remindMinute : _remindSecond);
    } else {
      initialValue = type == 'hour' ? _timeHour : (type == 'minute' ? _timeMinute : _timeSecond);
    }
    final int maxValue = type == 'hour' ? 23 : 59;
    // 在 BottomSheet 创建时固定初始位置，弹窗关闭时自动 dispose
    final scrollCtrl = FixedExtentScrollController(initialItem: initialValue);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int tempValue = initialValue;
        
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 300,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('取消', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ),
                        Text(type == 'hour' ? '选择时' : (type == 'minute' ? '选择分' : '选择秒'), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isReminder) {
                                if (type == 'hour') _remindHour = tempValue;
                                if (type == 'minute') _remindMinute = tempValue;
                                if (type == 'second') _remindSecond = tempValue;
                              } else {
                                if (type == 'hour') _timeHour = tempValue;
                                if (type == 'minute') _timeMinute = tempValue;
                                if (type == 'second') _timeSecond = tempValue;
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('确定', style: TextStyle(color: Color(0xFF5599FF), fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      controller: scrollCtrl,
                      itemExtent: 50,
                      perspective: 0.005,
                      diameterRatio: 1.2,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setModalState(() => tempValue = index);
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: maxValue + 1,
                        builder: (context, index) {
                          return Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: tempValue == index ? 24 : 18,
                                fontWeight: tempValue == index ? FontWeight.bold : FontWeight.normal,
                                color: tempValue == index ? const Color(0xFF5599FF) : Colors.grey[400],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    ).whenComplete(() => scrollCtrl.dispose());
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _showHabitLibrary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('习惯库待接入')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // App Bar Area
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: widget.onCancel,
                  child: const Text('取消', style: TextStyle(color: Colors.black54, fontSize: 16)),
                ),
                const Text('添加习惯', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                GestureDetector(
                  onTap: _handleSave,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5599FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '保存',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Input & Library
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: '习惯名称',
                            hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showHabitLibrary,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.dns_outlined, color: Colors.orange[300], size: 24),
                              const SizedBox(height: 2),
                              const Text('习惯库', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Icon Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('挑选图标和颜色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showIconColorPicker,
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: Color(_colorValue).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getIconData(_iconKey), color: Color(_colorValue), size: 24),
                            ),
                          ),
                      // 右侧“编辑打卡心得”入口已移除（只在实际打卡时填写）。
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Frequency - 模块一
                  const Text('想在哪天完成它', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        _buildFreqTab('固定', 'fixed', Icons.access_time),
                        _buildFreqTab('每周', 'weekly', Icons.calendar_today),
                        _buildFreqTab('每月', 'monthly', Icons.calendar_month),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDaysSelector(),
                  const SizedBox(height: 32),

                  // Time of Day - 模块二
                  const Text('想在一天什么时候完成它', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Hour Card
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('hour'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(_timeHour.toString().padLeft(2, '0'), 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF5599FF))),
                                const SizedBox(height: 4),
                                const Text('时', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Minute Card
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('minute'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(_timeMinute.toString().padLeft(2, '0'), 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF5599FF))),
                                const SizedBox(height: 4),
                                const Text('分', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Second Card
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('second'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(_timeSecond.toString().padLeft(2, '0'), 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF5599FF))),
                                const SizedBox(height: 4),
                                const Text('秒', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Reminder toggle + time picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('每日提醒', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      Switch(
                        value: _enableReminder,
                        onChanged: (val) => setState(() => _enableReminder = val),
                        activeColor: const Color(0xFF5599FF),
                        activeTrackColor: const Color(0xFF5599FF).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  if (_enableReminder) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showCustomTimePicker('hour', isReminder: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: Column(children: [
                                Text(_remindHour.toString().padLeft(2, '0'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF5599FF))),
                                const SizedBox(height: 4),
                                const Text('时', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showCustomTimePicker('minute', isReminder: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: Column(children: [
                                Text(_remindMinute.toString().padLeft(2, '0'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF5599FF))),
                                const SizedBox(height: 4),
                                const Text('分', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showCustomTimePicker('second', isReminder: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: Column(children: [
                                Text(_remindSecond.toString().padLeft(2, '0'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF5599FF))),
                                const SizedBox(height: 4),
                                const Text('秒', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Start Date
                  const Text('从哪天开始', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showDatePicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${_startDate.year}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.day.toString().padLeft(2, '0')}', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                          const SizedBox(width: 8),
                          Text(
                            _startDate.year == DateTime.now().year && _startDate.month == DateTime.now().month && _startDate.day == DateTime.now().day 
                                ? '今天' : '', 
                            style: TextStyle(color: Colors.grey[400])
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Switches
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('每日打卡目标', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('设置一天多次打卡', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                      Switch(
                        value: _multiTarget,
                        onChanged: (val) {
                          setState(() => _multiTarget = val);
                          if (val) {
                            _showTargetSettings();
                          } else {
                            setState(() {
                              _targetUnit = '次';
                              _planAmount = 1;
                              _perCheckAmount = 1;
                            });
                          }
                        },
                        activeColor: const Color(0xFF5599FF),
                        activeTrackColor: const Color(0xFF5599FF).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('是否自动弹出打卡心得', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Switch(
                        value: _autoPopup,
                        onChanged: (val) => setState(() => _autoPopup = val),
                        activeColor: const Color(0xFF5599FF),
                        activeTrackColor: const Color(0xFF5599FF).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector() {
    if (_freqType == 'fixed') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.event_available, color: Colors.green[400], size: 32),
            const SizedBox(height: 8),
            const Text('每天都需要打卡', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (_freqType == 'weekly') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          int dayValue = index + 1;
          bool isSelected = _weeklyDays.contains(dayValue);
          const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
          
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  if (_weeklyDays.length > 1) {
                    _weeklyDays.remove(dayValue);
                  }
                } else {
                  _weeklyDays.add(dayValue);
                }
              });
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF7C83FD) : Colors.transparent,
                border: isSelected ? null : Border.all(color: Colors.grey[300]!),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  dayNames[index], 
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600], 
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
            ),
          );
        }),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            // Weekdays Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['日', '一', '二', '三', '四', '五', '六'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day, 
                      style: TextStyle(
                        color: Colors.grey[500], 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Calendar Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 31,
              itemBuilder: (context, index) {
                int dayValue = index + 1;
                bool isSelected = _monthlyDays.contains(dayValue);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        if (_monthlyDays.length > 1) {
                          _monthlyDays.remove(dayValue);
                        }
                      } else {
                        _monthlyDays.add(dayValue);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF7C83FD) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$dayValue', 
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87, 
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        )
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFreqTab(String label, String value, IconData icon) {
    bool isSelected = _freqType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _freqType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7C83FD) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
