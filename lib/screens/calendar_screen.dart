import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/calendar_event.dart';
import '../core/providers.dart';
import '../core/services/calendar_service.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/common/error_state.dart';
import '../widgets/common/empty_state.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  List<CalendarEvent> _allEvents = [];
  List<CalendarEvent> _selectedDayEvents = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  CalendarService get _calendarService => ref.read(calendarServiceProvider);

  Future<void> _loadEvents() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      _allEvents = await _calendarService.getAllEvents();
      _selectedDayEvents = _getEventsForDate(_selectedDate);
    } catch (e) {
      _error = 'Failed to load events: $e';
    }
    setState(() => _isLoading = false);
  }

  List<CalendarEvent> _getEventsForDate(DateTime date) {
    return _allEvents.where((e) =>
      e.startTime.year == date.year &&
      e.startTime.month == date.month &&
      e.startTime.day == date.day,
    ).toList();
  }

  List<CalendarEvent> _getUpcomingEvents() {
    final now = DateTime.now();
    return _allEvents.where((e) =>
      e.startTime.isAfter(now) && !e.isCompleted,
    ).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> _addEvent() async {
    final titleController = TextEditingController();
    final timeController = TextEditingController(text: '10:00');
    final endTimeController = TextEditingController(text: '11:00');
    final descController = TextEditingController();
    final locationController = TextEditingController();
    EventCategory selectedCategory = EventCategory.other;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.backgroundElevated,
          title: const Text('Add Event', style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: timeController,
                        decoration: const InputDecoration(
                          hintText: 'Start (HH:MM)',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: endTimeController,
                        decoration: const InputDecoration(
                          hintText: 'End (HH:MM)',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    hintText: 'Location (optional)',
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
                const SizedBox(height: 12),
                DropdownButtonFormField<EventCategory>(
                  value: selectedCategory,
                  dropdownColor: AppColors.backgroundElevated,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Category',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                  ),
                  items: EventCategory.values.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name[0].toUpperCase() + c.name.substring(1)),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v ?? EventCategory.other),
                ),
              ],
            ),
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
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      try {
        final timeParts = timeController.text.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
        final startTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);

        final endParts = endTimeController.text.split(':');
        final endHour = int.parse(endParts[0]);
        final endMinute = endParts.length > 1 ? int.parse(endParts[1]) : 0;
        final endTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, endHour, endMinute);

        await _calendarService.createEvent(
          title: titleController.text.trim(),
          startTime: startTime,
          endTime: endTime,
          description: descController.text.trim(),
          location: locationController.text.trim(),
          category: selectedCategory,
          source: 'ui',
        );
        await _loadEvents();
      } catch (e) {
        setState(() => _error = 'Failed to create event: $e');
      }
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Delete Event', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Delete "${event.title}"?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _calendarService.deleteEvent(event.id);
      await _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayEvents = _getEventsForDate(DateTime.now());
    final upcoming = _getUpcomingEvents();

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
                          '${_allEvents.length} events • ${todayEvents.length} today',
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
                  : _error != null
                      ? ErrorState(
                          message: _error!,
                          onRetry: _loadEvents,
                          retryLabel: 'Retry',
                        )
                      : upcoming.isEmpty
                          ? const EmptyState(
                              icon: Icons.event_outlined,
                              title: 'No upcoming events',
                              subtitle: 'Add events to keep track of your schedule',
                            )
                          : _buildEventsList(upcoming),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCalendar() {
    final now = DateTime.now();
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfWeek = DateTime(year, month, 1).weekday % 7;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Month header with navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(year, month - 1);
                    });
                  },
                ),
                Text(
                  '${_getMonthName(month)} $year',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(year, month + 1);
                    });
                  },
                ),
              ],
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
                final date = DateTime(year, month, day);
                final isToday = day == now.day && month == now.month && year == now.year;
                final isSelected = day == _selectedDate.day && month == _selectedDate.month && year == _selectedDate.year;
                final hasEvents = _allEvents.any((e) =>
                  e.startTime.year == year &&
                  e.startTime.month == month &&
                  e.startTime.day == day,
                );

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedDayEvents = _getEventsForDate(date);
                    });
                  },
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.accent
                            : isSelected
                                ? AppColors.accentGhost
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: hasEvents && !isToday && !isSelected
                            ? Border.all(color: AppColors.accent, width: 1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isToday ? Colors.white : isSelected ? AppColors.accent : AppColors.textPrimary,
                          ),
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

  Widget _buildEventsList(List<CalendarEvent> events) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isToday = event.isToday;

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
                        '${event.startTime.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isToday ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _getMonthShort(event.startTime.month),
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
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: event.isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                  decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Row(
                children: [
                  Text(
                    event.isAllDay ? 'All day' : event.displayTime,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (event.location.isNotEmpty) ...[
                    const Text(' • ', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    Flexible(
                      child: Text(
                        event.location,
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!event.isCompleted)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.textTertiary),
                      onPressed: () async {
                        await _calendarService.markCompleted(event.id);
                        await _loadEvents();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textTertiary),
                    onPressed: () => _deleteEvent(event),
                  ),
                ],
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
