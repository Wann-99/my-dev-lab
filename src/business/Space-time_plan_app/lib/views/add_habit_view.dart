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
  final TextEditingController _nameController = TextEditingController(text: '打坐冥想');
  String _freqType = 'fixed'; // fixed, weekly, monthly
  String _timeOfDay = '上午'; // 全天, 上午, 下午, 晚上

  String _iconKey = 'self_improvement';
  int _colorValue = 0xFF5599FF;

  DateTime _startDate = DateTime.now();
  
  // Selected days for frequency
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7}; // 1 = Monday, 7 = Sunday
  
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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入习惯名称')),
      );
      return;
    }

    final newHabit = HabitPlan(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _nameController.text.trim(),
      iconKey: _iconKey,
      colorValue: _colorValue,
      repeatType: _freqType,
      repeatDays: _selectedDays.toList(),
      timeOfDay: _timeOfDay,
      startDate: _startDate,
      unit: _targetUnit,
      dailyTarget: _planAmount,
      perComplete: _perCheckAmount,
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

  void _showHabitLibrary() {
    // Just a dummy action
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
                  child: const Text('取消', style: TextStyle(color: Colors.black54, fontSize: 14)),
                ),
                const Text('添加习惯', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                GestureDetector(
                  onTap: _handleSave,
                  child: const Text('保存', style: TextStyle(color: Color(0xFF5599FF), fontSize: 16)),
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
                  // Name Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showHabitLibrary,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text('习惯库', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Icon Selection
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Color(_colorValue), 
                          shape: BoxShape.circle
                        ),
                        child: Icon(_getIconData(_iconKey), color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _showIconColorPicker,
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                          child: const Center(child: Text('文', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Frequency - 模块一
                  const Text('想在哪天完成它', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildFreqTab('固定', 'fixed'),
                        _buildFreqTab('每周', 'weekly'),
                        _buildFreqTab('每月', 'monthly'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      int dayValue = index + 1;
                      bool isSelected = _selectedDays.contains(dayValue);
                      const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              if (_selectedDays.length > 1) { // Prevent deselecting all
                                _selectedDays.remove(dayValue);
                              }
                            } else {
                              _selectedDays.add(dayValue);
                            }
                          });
                        },
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF5599FF) : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              dayNames[index], 
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black54, 
                                fontWeight: FontWeight.bold
                              )
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Time of Day - 模块二
                  const Text('想在一天什么时候完成它', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildTimeTab('全天', '全天'),
                        _buildTimeTab('上午', '上午'),
                        _buildTimeTab('下午', '下午'),
                        _buildTimeTab('晚上', '晚上'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Reminder / Target - 模块三
                  const Text('在一天中什么时候提醒你', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showTargetSettings,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('设置提醒和打卡目标', style: TextStyle(color: Colors.black87)),
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                        ],
                      ),
                    ),
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

  Widget _buildFreqTab(String label, String value) {
    bool isSelected = _freqType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _freqType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5599FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTab(String label, String value) {
    bool isSelected = _timeOfDay == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _timeOfDay = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5599FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
