import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/models/habit.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';

class EditHabitBottomSheet extends StatefulWidget {
  final HabitPlan habit;

  const EditHabitBottomSheet({super.key, required this.habit});

  @override
  State<EditHabitBottomSheet> createState() => _EditHabitBottomSheetState();
}

class _EditHabitBottomSheetState extends State<EditHabitBottomSheet> {
  late String _freqType;
  late Set<int> _weeklyDays;
  late Set<int> _monthlyDays;
  
  // Specific time point variables
  late int _timeHour;
  late int _timeMinute;
  late int _timeSecond;

  late DateTime _startDate;
  
  // Reminder variables
  late int _remindHour;
  late int _remindMinute;
  late int _remindSecond;

  @override
  void initState() {
    super.initState();
    _freqType = widget.habit.repeatType;
    
    if (_freqType == 'weekly') {
      _weeklyDays = Set<int>.from(widget.habit.repeatDays);
      _monthlyDays = {1};
    } else if (_freqType == 'monthly') {
      _monthlyDays = Set<int>.from(widget.habit.repeatDays);
      _weeklyDays = {1, 2, 3, 4, 5, 6, 7};
    } else {
      _weeklyDays = {1, 2, 3, 4, 5, 6, 7};
      _monthlyDays = {1};
    }
    
    // Parse timeOfDay
    _timeHour = 12;
    _timeMinute = 0;
    _timeSecond = 0;
    if (widget.habit.timeOfDay.contains(':')) {
      final parts = widget.habit.timeOfDay.split(':');
      if (parts.isNotEmpty) _timeHour = int.tryParse(parts[0]) ?? 12;
      if (parts.length > 1) _timeMinute = int.tryParse(parts[1]) ?? 0;
      if (parts.length > 2) _timeSecond = int.tryParse(parts[2]) ?? 0;
    }

    _startDate = widget.habit.startDate;

    // Parse remindTime
    _remindHour = 8;
    _remindMinute = 0;
    _remindSecond = 0;
    if (widget.habit.remindTime != null) {
      _remindHour = widget.habit.remindTime!.hour;
      _remindMinute = widget.habit.remindTime!.minute;
      _remindSecond = widget.habit.remindTime!.second;
    }
  }

  void _handleSave() {
    final newTime = '${_timeHour.toString().padLeft(2, '0')}:${_timeMinute.toString().padLeft(2, '0')}:${_timeSecond.toString().padLeft(2, '0')}';
    final newRemindTime = DateTime(
      _startDate.year, _startDate.month, _startDate.day, 
      _remindHour, _remindMinute, _remindSecond
    );

    List<int> finalDays = [];
    if (_freqType == 'fixed') {
      finalDays = [1, 2, 3, 4, 5, 6, 7];
    } else if (_freqType == 'weekly') {
      finalDays = _weeklyDays.toList();
    } else {
      finalDays = _monthlyDays.toList();
    }
    finalDays.sort();

    context.read<HabitProvider>().updateHabitDetails(
      widget.habit.id,
      repeatType: _freqType,
      repeatDays: finalDays,
      timeOfDay: newTime,
      remindTime: newRemindTime,
      startDate: _startDate,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.habit.title} 修改已保存'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showCustomTimePicker(String type, {bool isReminder = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int tempValue;
        if (isReminder) {
          tempValue = type == 'hour' ? _remindHour : (type == 'minute' ? _remindMinute : _remindSecond);
        } else {
          tempValue = type == 'hour' ? _timeHour : (type == 'minute' ? _timeMinute : _timeSecond);
        }
        
        int maxValue = type == 'hour' ? 23 : 59;
        
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
                      itemExtent: 50,
                      perspective: 0.005,
                      diameterRatio: 1.2,
                      physics: const FixedExtentScrollPhysics(),
                      controller: FixedExtentScrollController(initialItem: tempValue),
                      onSelectedItemChanged: (index) {
                        setModalState(() {
                          tempValue = index;
                        });
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
    );
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                Text('编辑 - ${widget.habit.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                GestureDetector(
                  onTap: _handleSave,
                  child: const Text('保存', style: TextStyle(color: Color(0xFF5599FF), fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Frequency
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

                  // Time of Day
                  const Text('想在一天什么时候完成它', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('hour'),
                          child: _buildTimeCard(_timeHour.toString().padLeft(2, '0'), '时'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('minute'),
                          child: _buildTimeCard(_timeMinute.toString().padLeft(2, '0'), '分'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('second'),
                          child: _buildTimeCard(_timeSecond.toString().padLeft(2, '0'), '秒'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Reminder
                  const Text('在一天中什么时候提醒你', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('hour', isReminder: true),
                          child: _buildTimeCard(_remindHour.toString().padLeft(2, '0'), '时'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('minute', isReminder: true),
                          child: _buildTimeCard(_remindMinute.toString().padLeft(2, '0'), '分'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCustomTimePicker('second', isReminder: true),
                          child: _buildTimeCard(_remindSecond.toString().padLeft(2, '0'), '秒'),
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(String value, String label) {
    return Container(
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF5599FF))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
