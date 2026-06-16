import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../email_message.dart';
import 'email_service.dart';

class EmailInsight {
  final String type;
  final String title;
  final String description;
  final String priority;
  final String? emailId;

  EmailInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    this.emailId,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'title': title,
    'description': description,
    'priority': priority,
    'email_id': emailId,
  };
}

class InboxSummary {
  final int totalUnread;
  final int urgentCount;
  final int meetingCount;
  final int deadlineCount;
  final int importantCount;
  final List<EmailMessage> topUnread;
  final List<EmailInsight> insights;
  final String summaryText;

  InboxSummary({
    required this.totalUnread,
    required this.urgentCount,
    required this.meetingCount,
    required this.deadlineCount,
    required this.importantCount,
    required this.topUnread,
    required this.insights,
    required this.summaryText,
  });
}

class InboxIntelligenceService {
  static Database? _database;
  static const _dbName = 'nextron_emails.db';

  final EmailService _emailService;

  InboxIntelligenceService({required EmailService emailService})
      : _emailService = emailService;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(path, version: 1);
  }

  Future<InboxSummary> generateSummary() async {
    final stats = await _emailService.getEmailStats();
    final unread = await _emailService.getUnreadEmails(limit: 50);
    final important = await _emailService.getImportantEmails(limit: 10);
    final meetings = await _emailService.getMeetingEmails(limit: 10);
    final deadlines = await _emailService.getActionRequiredEmails(limit: 10);

    final insights = <EmailInsight>[];

    // Detect urgent patterns
    for (final email in unread) {
      final urgency = _detectUrgency(email);
      if (urgency != null) insights.add(urgency);

      final actionItem = _extractActionItem(email);
      if (actionItem != null) insights.add(actionItem);
    }

    // Detect repeated senders (relationship)
    final senderCounts = <String, int>{};
    for (final email in unread) {
      senderCounts[email.senderName] = (senderCounts[email.senderName] ?? 0) + 1;
    }
    for (final entry in senderCounts.entries) {
      if (entry.value >= 3) {
        insights.add(EmailInsight(
          type: 'relationship',
          title: 'Frequent contact: ${entry.key}',
          description: '${entry.value} unread emails from ${entry.key}',
          priority: 'medium',
        ));
      }
    }

    final summaryBuffer = StringBuffer();
    if (stats['unread'] == 0) {
      summaryBuffer.write('Inbox is clear! No unread emails.');
    } else {
      summaryBuffer.write('${stats['unread']} unread');
      if (stats['important']! > 0) summaryBuffer.write(', ${stats["important"]} important');
      if (stats['meetings']! > 0) summaryBuffer.write(', ${stats["meetings"]} meeting-related');
      if (stats['deadlines']! > 0) summaryBuffer.write(', ${stats["deadlines"]} need action');
    }

    return InboxSummary(
      totalUnread: stats['unread'] ?? 0,
      urgentCount: insights.where((i) => i.priority == 'urgent').length,
      meetingCount: stats['meetings'] ?? 0,
      deadlineCount: stats['deadlines'] ?? 0,
      importantCount: stats['important'] ?? 0,
      topUnread: unread.take(5).toList(),
      insights: insights,
      summaryText: summaryBuffer.toString(),
    );
  }

  EmailInsight? _detectUrgency(EmailMessage email) {
    final subjectLower = email.subject.toLowerCase();
    final bodyLower = email.body.toLowerCase();
    final combined = '$subjectLower $bodyLower';

    if (combined.contains(RegExp(r'urgent|asap|critical|emergency|immediate|deadline today'))) {
      return EmailInsight(
        type: 'urgent',
        title: 'Urgent: ${email.subject}',
        description: 'From ${email.senderName} - requires immediate attention',
        priority: 'urgent',
        emailId: email.id,
      );
    }

    if (combined.contains(RegExp(r'action required|please respond|needs? (your|a) (response|reply|action)|rsvp'))) {
      return EmailInsight(
        type: 'action_required',
        title: 'Action needed: ${email.subject}',
        description: 'From ${email.senderName} - response requested',
        priority: 'high',
        emailId: email.id,
      );
    }

    if (email.hasDeadline) {
      return EmailInsight(
        type: 'deadline',
        title: 'Deadline: ${email.subject}',
        description: 'Contains deadline reference from ${email.senderName}',
        priority: 'high',
        emailId: email.id,
      );
    }

    if (email.isMeeting) {
      return EmailInsight(
        type: 'meeting',
        title: 'Meeting: ${email.subject}',
        description: 'Meeting invitation from ${email.senderName}',
        priority: 'medium',
        emailId: email.id,
      );
    }

    return null;
  }

  EmailInsight? _extractActionItem(EmailMessage email) {
    final body = email.body.toLowerCase();

    if (body.contains(RegExp(r'please (review|approve|confirm|send|update|complete|submit|check)'))) {
      return EmailInsight(
        type: 'action_item',
        title: 'Action item: ${email.subject}',
        description: 'Contains a request from ${email.senderName}',
        priority: 'medium',
        emailId: email.id,
      );
    }

    if (body.contains(RegExp(r'attached|attachment|see attached|please find'))) {
      return EmailInsight(
        type: 'has_attachment',
        title: 'Attachment: ${email.subject}',
        description: 'Email from ${email.senderName} mentions attachments',
        priority: 'low',
        emailId: email.id,
      );
    }

    return null;
  }

  Future<List<EmailInsight>> getRecentInsights({int limit = 20}) async {
    final db = await database;
    try {
      final results = await db.query(
        'email_insights',
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return results.map((r) => EmailInsight(
        type: r['type'] as String,
        title: r['title'] as String,
        description: r['description'] as String,
        priority: r['priority'] as String,
        emailId: r['email_id'] as String?,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> generateMorningBriefing() async {
    final summary = await generateSummary();
    final buffer = StringBuffer();

    buffer.writeln('📧 Email Briefing:');
    buffer.writeln(summary.summaryText);

    if (summary.urgentCount > 0) {
      buffer.writeln('\n🚨 ${summary.urgentCount} urgent email${summary.urgentCount > 1 ? "s" : ""} need attention');
    }

    final urgentInsights = summary.insights.where((i) => i.priority == 'urgent').toList();
    for (final insight in urgentInsights.take(3)) {
      buffer.writeln('  • ${insight.title}');
    }

    final meetingInsights = summary.insights.where((i) => i.type == 'meeting').toList();
    if (meetingInsights.isNotEmpty) {
      buffer.writeln('\n📅 ${meetingInsights.length} meeting-related email${meetingInsights.length > 1 ? "s" : ""}');
    }

    final actionInsights = summary.insights.where((i) => i.type == 'action_required' || i.type == 'action_item').toList();
    if (actionInsights.isNotEmpty) {
      buffer.writeln('\n✅ ${actionInsights.length} email${actionInsights.length > 1 ? "s" : ""} need your action');
    }

    return buffer.toString();
  }

  Future<Map<String, dynamic>> getContactStats() async {
    final db = await database;
    try {
      final results = await db.rawQuery('''
        SELECT `from`, COUNT(*) as count,
               MAX(date) as last_email,
               SUM(CASE WHEN is_important = 1 THEN 1 ELSE 0 END) as important_count
        FROM emails
        GROUP BY `from`
        ORDER BY count DESC
        LIMIT 20
      ''');

      return {
        'contacts': results.map((r) => {
          'name': r['from'],
          'emailCount': r['count'],
          'lastEmail': r['last_email'],
          'importantCount': r['important_count'],
        }).toList(),
        'totalUniqueContacts': results.length,
      };
    } catch (_) {
      return {'contacts': [], 'totalUniqueContacts': 0};
    }
  }

  void dispose() {}
}
