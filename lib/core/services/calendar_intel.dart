import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_service.dart';
import 'memory_search.dart';
import 'email_service.dart';
import 'knowledge_hub.dart';

class MeetingPrepBrief {
  final String meetingTitle;
  final DateTime meetingTime;
  final int minutesUntil;
  final List<String> relatedMemories;
  final List<String> relatedEmails;
  final List<String> relatedProjects;
  final String contextSummary;

  MeetingPrepBrief({
    required this.meetingTitle,
    required this.meetingTime,
    required this.minutesUntil,
    required this.relatedMemories,
    required this.relatedEmails,
    required this.relatedProjects,
    required this.contextSummary,
  });
}

class CalendarIntel {
  final MemoryService _memory;
  final MemorySearch _memorySearch;
  final KnowledgeHub _knowledgeHub;
  final EmailService? _emailService;

  CalendarIntel({
    required MemoryService memory,
    required MemorySearch memorySearch,
    required KnowledgeHub knowledgeHub,
    EmailService? emailService,
  })  : _memory = memory,
        _memorySearch = memorySearch,
        _knowledgeHub = knowledgeHub,
        _emailService = emailService;

  Future<MeetingPrepBrief?> generatePrepBrief(String meetingTitle, DateTime meetingTime) async {
    final now = DateTime.now();
    final diff = meetingTime.difference(now);
    final minutesUntil = diff.inMinutes;
    if (minutesUntil < 0) return null;

    // Collect related memories
    final memoryResults = await _memorySearch.search(meetingTitle, limit: 5);
    final relatedMemories = memoryResults.map((r) => r.content).toList();

    // Collect related emails
    List<String> relatedEmails = [];
    if (_emailService != null && _emailService.isConfigured) {
      final emailResults = await _emailService.searchEmails(meetingTitle);
      relatedEmails = emailResults.map((e) =>
        'From: ${e.from} — Subject: ${e.subject}'
      ).toList();
    }

    // Collect related projects from SharedPreferences
    List<String> relatedProjects = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('user_projects');
      if (data != null) {
        final projects = jsonDecode(data) as List;
        for (final project in projects) {
          final name = project['name'] as String? ?? '';
          if (name.isNotEmpty && meetingTitle.toLowerCase().contains(name.toLowerCase())) {
            relatedProjects.add(name);
          }
        }
      }
    } catch (e) {
      // No projects
    }

    // Build context summary
    final parts = <String>[];
    if (relatedMemories.isNotEmpty) {
      parts.add('Memories: ${relatedMemories.take(2).map((m) =>
        m.length > 60 ? '${m.substring(0, 60)}...' : m
      ).join('; ')}');
    }
    if (relatedEmails.isNotEmpty) {
      parts.add('Emails: ${relatedEmails.take(2).join('; ')}');
    }
    if (relatedProjects.isNotEmpty) {
      parts.add('Projects: ${relatedProjects.join(', ')}');
    }

    return MeetingPrepBrief(
      meetingTitle: meetingTitle,
      meetingTime: meetingTime,
      minutesUntil: minutesUntil,
      relatedMemories: relatedMemories,
      relatedEmails: relatedEmails,
      relatedProjects: relatedProjects,
      contextSummary: parts.isNotEmpty
          ? parts.join('. ')
          : 'No related context found for this meeting.',
    );
  }

  Future<List<MeetingPrepBrief>> checkUpcomingMeetings() async {
    final briefs = <MeetingPrepBrief>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('calendar_events');
      if (data == null) return briefs;

      final events = jsonDecode(data) as List;
      final now = DateTime.now();

      for (final event in events) {
        final eventDate = DateTime.parse(event['date']);
        final diff = eventDate.difference(now);

        // Check for meetings starting within the next 2 hours
        if (diff.inMinutes > 0 && diff.inMinutes <= 120) {
          final brief = await generatePrepBrief(
            event['title'] as String? ?? 'Untitled',
            eventDate,
          );
          if (brief != null) briefs.add(brief);
        }
      }
    } catch (e) {
      // No events
    }
    return briefs;
  }
}
