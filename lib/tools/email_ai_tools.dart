import 'dart:async';
import '../core/email_message.dart';
import '../core/services/email_service.dart';
import 'tool.dart';

class EmailReadTool extends Tool {
  final EmailService _emailService;
  EmailReadTool(this._emailService)
      : super(
          name: 'email_read',
          description: 'Read emails from inbox. Returns unread or recent emails with full content.',
          parameters: [
            const ToolParameter(name: 'count', description: 'Number of emails to read (default: 5)', type: ToolParameterType.integer),
            const ToolParameter(name: 'unreadOnly', description: 'Only show unread emails (default: false)', type: ToolParameterType.boolean),
            const ToolParameter(name: 'folder', description: 'Email folder to read from', type: ToolParameterType.string, enumValues: ['inbox', 'sent', 'drafts', 'archive', 'trash']),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final count = (params['count'] as int?) ?? 5;
      final unreadOnly = params['unreadOnly'] as bool? ?? false;
      final folderStr = (params['folder'] as String?) ?? 'inbox';
      final folder = EmailFolder.values.firstWhere((f) => f.name == folderStr, orElse: () => EmailFolder.inbox);

      await _emailService.fetchEmails(folder: folder, limit: count, unreadOnly: unreadOnly);
      final emails = await _emailService.getStoredEmails(folder: folder, limit: count);

      if (emails.isEmpty) {
        return ToolResult.success('No ${unreadOnly ? "unread " : ""}emails in $folderStr');
      }

      final buffer = StringBuffer('📧 ${emails.length} email${emails.length > 1 ? "s" : ""}:\n\n');
      for (final e in emails) {
        final status = e.isUnread ? '📩' : '📧';
        buffer.writeln('$status From: ${e.senderName}');
        buffer.writeln('   Subject: ${e.subject}');
        buffer.writeln('   Date: ${e.displayDate}');
        if (e.body.isNotEmpty) {
          final preview = e.body.length > 300 ? '${e.body.substring(0, 300)}...' : e.body;
          buffer.writeln('   Content: $preview');
        }
        if (e.isMeeting) buffer.writeln('   📅 Contains meeting references');
        if (e.hasDeadline) buffer.writeln('   ⏰ Contains deadline');
        buffer.writeln();
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to read emails: $e');
    }
  }
}

class EmailSearchTool extends Tool {
  final EmailService _emailService;
  EmailSearchTool(this._emailService)
      : super(
          name: 'email_search',
          description: 'Search emails by keyword in subject, sender, or body content',
          parameters: [
            const ToolParameter(name: 'query', description: 'Search keyword', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'count', description: 'Max results (default: 10)', type: ToolParameterType.integer),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final query = params['query'] as String;
      final count = (params['count'] as int?) ?? 10;

      final emails = await _emailService.searchEmails(query, limit: count);

      if (emails.isEmpty) {
        return ToolResult.success('No emails found matching "$query"');
      }

      final buffer = StringBuffer('🔍 Search results for "$query" (${emails.length}):\n\n');
      for (final e in emails) {
        buffer.writeln('• ${e.subject}');
        buffer.writeln('  From: ${e.senderName} - ${e.displayDate}');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to search emails: $e');
    }
  }
}

class EmailSendTool extends Tool {
  final EmailService _emailService;
  EmailSendTool(this._emailService)
      : super(
          name: 'email_send',
          description: 'Send an email to a recipient',
          parameters: [
            const ToolParameter(name: 'to', description: 'Recipient email address', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'subject', description: 'Email subject', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'body', description: 'Email body content', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'cc', description: 'CC recipients (comma-separated)', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final to = params['to'] as String;
      final subject = params['subject'] as String;
      final body = params['body'] as String;
      final ccStr = params['cc'] as String?;
      final cc = ccStr?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? [];

      final sent = await _emailService.sendEmail(to: to, subject: subject, body: body, cc: cc);
      if (sent) {
        return ToolResult.success('Email sent to $to with subject "$subject"');
      }
      return ToolResult.error('Failed to send email');
    } catch (e) {
      return ToolResult.error('Failed to send email: $e');
    }
  }
}

class EmailDraftTool extends Tool {
  final EmailService _emailService;
  EmailDraftTool(this._emailService)
      : super(
          name: 'email_draft',
          description: 'Save an email draft without sending',
          parameters: [
            const ToolParameter(name: 'to', description: 'Recipient email address', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'subject', description: 'Email subject', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'body', description: 'Email body content', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final to = params['to'] as String;
      final subject = params['subject'] as String;
      final body = params['body'] as String;

      final draft = await _emailService.saveDraft(to: to, subject: subject, body: body);
      return ToolResult.success('Draft saved: "${draft.subject}" to $to (ID: ${draft.id})');
    } catch (e) {
      return ToolResult.error('Failed to save draft: $e');
    }
  }
}

class EmailReplyTool extends Tool {
  final EmailService _emailService;
  EmailReplyTool(this._emailService)
      : super(
          name: 'email_reply',
          description: 'Reply to an existing email',
          parameters: [
            const ToolParameter(name: 'email_id', description: 'ID of the email to reply to', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'body', description: 'Reply body content', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final emailId = params['email_id'] as String;
      final body = params['body'] as String;

      final original = await _emailService.getEmail(emailId);
      if (original == null) return ToolResult.error('Email not found');

      final sent = await _emailService.sendEmail(
        to: original.from,
        subject: 'Re: ${original.subject}',
        body: body,
        inReplyTo: original.id,
      );

      if (sent) {
        await _emailService.markAsRead(emailId);
        return ToolResult.success('Reply sent to ${original.senderName}');
      }
      return ToolResult.error('Failed to send reply');
    } catch (e) {
      return ToolResult.error('Failed to reply: $e');
    }
  }
}

class EmailForwardTool extends Tool {
  final EmailService _emailService;
  EmailForwardTool(this._emailService)
      : super(
          name: 'email_forward',
          description: 'Forward an email to another recipient',
          parameters: [
            const ToolParameter(name: 'email_id', description: 'ID of the email to forward', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'to', description: 'Forward recipient email address', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'note', description: 'Optional note to add', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final emailId = params['email_id'] as String;
      final to = params['to'] as String;
      final note = params['note'] as String? ?? '';

      final original = await _emailService.getEmail(emailId);
      if (original == null) return ToolResult.error('Email not found');

      final forwardBody = StringBuffer();
      if (note.isNotEmpty) forwardBody.writeln('$note\n');
      forwardBody.writeln('---------- Forwarded message ----------');
      forwardBody.writeln('From: ${original.from}');
      forwardBody.writeln('Subject: ${original.subject}');
      forwardBody.writeln('Date: ${original.displayDate}');
      forwardBody.writeln();
      forwardBody.write(original.body);

      final sent = await _emailService.sendEmail(
        to: to,
        subject: 'Fwd: ${original.subject}',
        body: forwardBody.toString(),
      );

      if (sent) {
        return ToolResult.success('Email forwarded to $to');
      }
      return ToolResult.error('Failed to forward email');
    } catch (e) {
      return ToolResult.error('Failed to forward: $e');
    }
  }
}

class EmailArchiveTool extends Tool {
  final EmailService _emailService;
  EmailArchiveTool(this._emailService)
      : super(
          name: 'email_archive',
          description: 'Archive an email',
          parameters: [
            const ToolParameter(name: 'email_id', description: 'ID of the email to archive', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final emailId = params['email_id'] as String;
      final archived = await _emailService.archiveEmail(emailId);
      return archived
          ? ToolResult.success('Email archived')
          : ToolResult.error('Email not found');
    } catch (e) {
      return ToolResult.error('Failed to archive: $e');
    }
  }
}

class EmailMarkReadTool extends Tool {
  final EmailService _emailService;
  EmailMarkReadTool(this._emailService)
      : super(
          name: 'email_mark_read',
          description: 'Mark an email as read or unread',
          parameters: [
            const ToolParameter(name: 'email_id', description: 'ID of the email', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'unread', description: 'Set to true for unread, false for read (default: false)', type: ToolParameterType.boolean),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final emailId = params['email_id'] as String;
      final unread = params['unread'] as bool? ?? false;
      final success = unread
          ? await _emailService.markAsUnread(emailId)
          : await _emailService.markAsRead(emailId);
      return success
          ? ToolResult.success(unread ? 'Marked as unread' : 'Marked as read')
          : ToolResult.error('Email not found');
    } catch (e) {
      return ToolResult.error('Failed to update email: $e');
    }
  }
}

class EmailGetUnreadTool extends Tool {
  final EmailService _emailService;
  EmailGetUnreadTool(this._emailService)
      : super(
          name: 'email_get_unread',
          description: 'Get all unread emails from inbox',
          parameters: [
            const ToolParameter(name: 'count', description: 'Max unread emails to return (default: 20)', type: ToolParameterType.integer),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final count = (params['count'] as int?) ?? 20;
      await _emailService.fetchEmails(unreadOnly: true, limit: count);
      final emails = await _emailService.getUnreadEmails(limit: count);

      if (emails.isEmpty) {
        return ToolResult.success('No unread emails');
      }

      final buffer = StringBuffer('📩 ${emails.length} unread email${emails.length > 1 ? "s" : ""}:\n\n');
      for (final e in emails) {
        final flags = <String>[];
        if (e.isImportant) flags.add('⭐ Important');
        if (e.isMeeting) flags.add('📅 Meeting');
        if (e.hasDeadline) flags.add('⏰ Deadline');
        final flagStr = flags.isNotEmpty ? ' [${flags.join(", ")}]' : '';

        buffer.writeln('• ${e.subject}$flagStr');
        buffer.writeln('  From: ${e.senderName} - ${e.displayDate}');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to get unread emails: $e');
    }
  }
}

class EmailSummarizeInboxTool extends Tool {
  final EmailService _emailService;
  EmailSummarizeInboxTool(this._emailService)
      : super(
          name: 'email_summarize_inbox',
          description: 'Get a summary of inbox with counts by category',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final stats = await _emailService.getEmailStats();
      final unread = await _emailService.getUnreadEmails(limit: 50);
      final important = await _emailService.getImportantEmails(limit: 10);
      final meetings = await _emailService.getMeetingEmails(limit: 10);
      final deadlines = await _emailService.getActionRequiredEmails(limit: 10);

      final buffer = StringBuffer('📊 Inbox Summary:\n');
      buffer.writeln('• Total emails: ${stats['total']}');
      buffer.writeln('• Unread: ${stats['unread']}');
      buffer.writeln('• Important: ${stats['important']}');
      buffer.writeln('• Meeting-related: ${stats['meetings']}');
      buffer.writeln('• Action required: ${stats['deadlines']}');

      if (important.isNotEmpty) {
        buffer.writeln('\n⭐ Important emails:');
        for (final e in important.take(3)) {
          buffer.writeln('  • ${e.subject} from ${e.senderName}');
        }
      }

      if (meetings.isNotEmpty) {
        buffer.writeln('\n📅 Meeting emails:');
        for (final e in meetings.take(3)) {
          buffer.writeln('  • ${e.subject} from ${e.senderName}');
        }
      }

      if (deadlines.isNotEmpty) {
        buffer.writeln('\n⏰ Action required:');
        for (final e in deadlines.take(3)) {
          buffer.writeln('  • ${e.subject} from ${e.senderName}');
        }
      }

      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to summarize inbox: $e');
    }
  }
}

List<Tool> getAllEmailAITools(EmailService service) {
  return [
    EmailReadTool(service),
    EmailSearchTool(service),
    EmailSendTool(service),
    EmailDraftTool(service),
    EmailReplyTool(service),
    EmailForwardTool(service),
    EmailArchiveTool(service),
    EmailMarkReadTool(service),
    EmailGetUnreadTool(service),
    EmailSummarizeInboxTool(service),
  ];
}
