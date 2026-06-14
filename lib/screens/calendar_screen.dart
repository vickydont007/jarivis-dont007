import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/services/persistent_scheduler.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/common/status_chip.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final List<_CalendarEvent> _events = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('calendar_events');
      if (data != null) {
        final list = jsonDecode(data) as List;
        _events.clear();
        for (final item in list) {
          _events.add(_CalendarEvent(
            title: item['title'],
            date: DateTime.parse(item['date']),
            time: item['time'] ?? '',
            description: item['description'] ?? '',
            isAllDay: item['isAllDay'] ?? false,
          ));
        }
      }
    } catch (e) {
      // Use empty list
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _events.map((e) => {
      'title': e.title,
      'date': e.date.toIso8601String(),
      'time': e.time,
      'description': e.description,
      'isAllDay': e.isAllDay,
    }).toList();
    await prefs.setString('calendar_events', jsonEncode(data));
  }

  Future<void> _addEvent() async {
    final titleController = TextEditingController();
    final timeController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Add Event', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Event title',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                hintText: 'Time (e.g., 14:00)',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      setState(() {
        _events.add(_CalendarEvent(
          title: titleController.text.trim(),
          date: _selectedDate,
          time: timeController.text.trim(),
          description: descController.text.trim(),
        ));
      });
      _events.sort((a, b) => a.date.compareTo(b.date));
      await _saveEvents();
    }
  }

  List<_CalendarEvent> _getEventsForDate(DateTime date) {
    return _events.where((e) =>
      e.date.year == date.year &&
      e.date.month == date.month &&
      e.date.day == date.day,
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final todayEvents = _getEventsForDate(DateTime.now());
    final upcomingEvents = _events.where((e) =>
      e.date.isAfter(DateTime.now()) ||
      (e.date.year == DateTime.now().year &&
       e.date.month == DateTime.now().month &&
       e.date.day == DateTime.now().day),
    ).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.xxxl, 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📅 Calendar',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${_events.length} events • ${todayEvents.length} today',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassButton(
                    onPressed: _addEvent,
                    label: 'Add Event',
                    icon: Icons.add,
                    isCompact: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Mini calendar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: _buildMiniCalendar(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Events list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : upcomingEvents.isEmpty
                      ? _buildEmptyState()
                      : _buildEventsList(upcomingEvents),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCalendar() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDayOfWeek = DateTime(now.year, now.month, 1).weekday % 7;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Month header
            Text(
              _getMonthName(now.month),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Day grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: firstDayOfWeek + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstDayOfWeek) return const SizedBox();
                final day = index - firstDayOfWeek + 1;
                final isToday = day == now.day;
                final hasEvents = _events.any((e) =>
                  e.date.year == now.year &&
                  e.date.month == now.month &&
                  e.date.day == day,
                );

                return Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: hasEvents && !isToday
                          ? Border.all(color: AppColors.accent, width: 1)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                          color: isToday ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No upcoming events',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add events to keep track of your schedule',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<_CalendarEvent> events) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isToday = event.date.year == DateTime.now().year &&
            event.date.month == DateTime.now().month &&
            event.date.day == DateTime.now().day;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GlassCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.accentGhost : AppColors.glassFill,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${event.date.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isToday ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _getMonthShort(event.date.month),
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday ? AppColors.accent : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              title: Text(
                event.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                event.time.isNotEmpty ? event.time : 'All day',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textTertiary),
                onPressed: () {
                  setState(() => _events.removeWhere((e) =>
                    e.title == event.title &&
                    e.date == event.date,
                  ));
                  _saveEvents();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  String _getMonthShort(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}

class _CalendarEvent {
  final String title;
  final DateTime date;
  final String time;
  final String description;
  final bool isAllDay;

  _CalendarEvent({
    required this.title,
    required this.date,
    this.time = '',
    this.description = '',
    this.isAllDay = false,
  });
}
