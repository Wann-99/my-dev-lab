import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/models/event_item.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _currentMonth = DateTime.now();
  final DateTime _today = DateTime.now();

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _showAddEventBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                      child: const Text('取消', style: TextStyle(color: Colors.black54, fontSize: 16)),
                    ),
                    const Text('选择日期', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    GestureDetector(
                      onTap: () {
                        // TODO: Save EventItem logic
                        Navigator.pop(context);
                      },
                      child: const Text('保存', style: TextStyle(color: Color(0xFF5599FF), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Top Tabs
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildEventTab('时间点', false),
                      _buildEventTab('时间段', true),
                      _buildEventTab('全天', false),
                    ],
                  ),
                ),
              ),

              // Dummy Calendar Grid for multiselect
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.chevron_left),
                    Text('${_currentMonth.year}/${_currentMonth.month.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Weekdays
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['日', '一', '二', '三', '四', '五', '六']
                    .map((d) => Text(d, style: TextStyle(color: Colors.grey[500]))).toList(),
              ),
              const SizedBox(height: 8),

              // Mock Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: 35,
                  itemBuilder: (context, index) {
                    bool isSelected = index == 14 || index == 15; // Mock selection
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF5599FF) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${(index % 30) + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Configuration Area
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
                  ]
                ),
                child: Column(
                  children: [
                    _buildConfigRow('类型', '每天'),
                    const Divider(height: 1),
                    _buildConfigRow('提醒日', '长期'),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('持续时间', style: TextStyle(fontSize: 16)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('05:30-05:45', style: TextStyle(color: Color(0xFF5599FF), fontSize: 16)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.add, size: 14, color: Colors.grey[500]),
                                  Text('添加一个时间', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _buildConfigRow('开始日期', '2026/03/08'),
                    const Divider(height: 1),
                    _buildConfigRow('结束日期', '长期'),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('跳过法定节假日', style: TextStyle(fontSize: 16)),
                          Switch(value: false, onChanged: (v){}),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('跳过非补班周末', style: TextStyle(fontSize: 16)),
                          Switch(value: false, onChanged: (v){}),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildEventTab(String label, bool isSelected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.black54, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String monthStr = '${_currentMonth.year}/${_currentMonth.month.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: const Text(
          '事项',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Calendar View Area
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    // Month Switcher
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _previousMonth,
                            child: const Icon(Icons.chevron_left, color: Colors.black54),
                          ),
                          Text(
                            monthStr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          GestureDetector(
                            onTap: _nextMonth,
                            child: const Icon(Icons.chevron_right, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    // Weekdays
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['日', '一', '二', '三', '四', '五', '六']
                            .map((day) => Text(day, style: TextStyle(color: Colors.grey[500], fontSize: 12)))
                            .toList(),
                      ),
                    ),
                    // Days Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: 35, // Mock 5 weeks
                      itemBuilder: (context, index) {
                        int day = (index % 30) + 1;
                        bool isToday = day == _today.day && _currentMonth.month == _today.month;
                        
                        // Mock Lunar string
                        List<String> lunars = ['十四','元宵节','十六','十七','十八','十九','二十'];
                        String lunar = lunars[index % lunars.length];

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: isToday ? Colors.white : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isToday ? Border.all(color: const Color(0xFF5599FF), width: 1.5) : null,
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isToday ? const Color(0xFF5599FF) : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lunar,
                              style: TextStyle(
                                fontSize: 10,
                                color: lunar == '元宵节' ? Colors.red : Colors.grey[400],
                              ),
                            )
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Empty State
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('当前暂无日程', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Floating Action Button
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              heroTag: 'calendar_add',
              backgroundColor: const Color(0xFF5599FF),
              elevation: 4,
              onPressed: _showAddEventBottomSheet,
              child: const Icon(Icons.add, size: 32, color: Colors.white),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
