import 'dart:io';
import 'tool.dart';

class EmailSendTool extends Tool {
  EmailSendTool()
      : super(
          name: 'email_send',
          description: 'Send an email using macOS Mail app',
          parameters: [
            const ToolParameter(
              name: 'to',
              description: 'Recipient email address',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'subject',
              description: 'Email subject',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'body',
              description: 'Email body content',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final to = params['to'] as String?;
    final subject = params['subject'] as String?;
    final body = params['body'] as String?;

    if (to == null || subject == null || body == null) {
      return ToolResult.error('to, subject, and body are required');
    }

    try {
      final script = '''
tell application "Mail"
  set newMessage to make new outgoing message with properties {subject:"$subject", content:"$body", visible:false}
  tell newMessage
    make new to recipient at end of to recipients with properties {address:"$to"}
  end tell
  send newMessage
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        return ToolResult.success('Email sent to $to');
      }
      return ToolResult.error(result.stderr.toString());
    } catch (e) {
      return ToolResult.error('Failed to send email: $e');
    }
  }
}

class EmailListTool extends Tool {
  EmailListTool()
      : super(
          name: 'email_list',
          description: 'List recent emails from the inbox',
          parameters: [
            const ToolParameter(
              name: 'count',
              description: 'Number of emails to list (default: 5)',
              type: ToolParameterType.integer,
              defaultValue: 5,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final count = params['count'] as int? ?? 5;

    try {
      final script = '''
tell application "Mail"
  set emailList to {}
  set inbox to mailbox "INBOX" of account 1
  set messages to messages of inbox
  repeat with i from 1 to (count of messages)
    if i > $count then exit repeat
    set msg to item i of messages
    set end of emailList to (subject of msg & " ||| " & sender of msg & " ||| " & (date received of msg as string))
  end repeat
  set AppleScript's text item delimiters to "###"
  return emailList as string
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isEmpty) return ToolResult.success(<dynamic>[]);

        final emails = output.split('###').map((line) {
          final parts = line.split(' ||| ');
          return {
            'subject': parts.isNotEmpty ? parts[0] : '',
            'from': parts.length > 1 ? parts[1] : '',
            'date': parts.length > 2 ? parts[2] : '',
          };
        }).toList();

        return ToolResult.success(emails);
      }
      return ToolResult.error(result.stderr.toString());
    } catch (e) {
      return ToolResult.error('Failed to list emails: $e');
    }
  }
}

class EmailReadTool extends Tool {
  EmailReadTool()
      : super(
          name: 'email_read',
          description: 'Read the content of a specific email by subject',
          parameters: [
            const ToolParameter(
              name: 'subject',
              description: 'Subject of the email to read',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final subject = params['subject'] as String?;

    if (subject == null) {
      return ToolResult.error('subject is required to identify the email');
    }

    try {
      final script = '''
tell application "Mail"
  set inbox to mailbox "INBOX" of account 1
  set messages to messages of inbox
  repeat with msg in messages
    if subject of msg is "$subject" then
      return content of msg
    end if
  end repeat
  return "Email not found"
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        return ToolResult.success(result.stdout.toString().trim());
      }
      return ToolResult.error(result.stderr.toString());
    } catch (e) {
      return ToolResult.error('Failed to read email: $e');
    }
  }
}

List<Tool> getAllEmailTools() {
  return [
    EmailSendTool(),
    EmailListTool(),
    EmailReadTool(),
  ];
}
