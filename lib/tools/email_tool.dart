import 'dart:io';
import 'tool.dart';

Future<bool> _ensureAppRunning(String appName) async {
  final checkResult = await Process.run('osascript', [
    '-e',
    'tell application "System Events" to (name of processes) contains "$appName"'
  ]);
  final isRunning = checkResult.stdout.toString().trim() == 'true';
  if (isRunning) return true;

  await Process.run('open', ['-a', appName]);
  await Future.delayed(const Duration(seconds: 2));
  return true;
}

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
      await _ensureAppRunning('Mail');

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
        return ToolResult.success('Email sent to $to with subject "$subject"');
      }
      return ToolResult.error('Mail error: ${result.stderr.toString().trim()}');
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
      await _ensureAppRunning('Mail');

      final script = '''
tell application "Mail"
  set msgList to {}
  set inboxMsgs to messages of inbox
  set maxCount to (count of inboxMsgs)
  if maxCount > $count then set maxCount to $count
  repeat with i from 1 to maxCount
    set msg to item i of inboxMsgs
    set end of msgList to (subject of msg) & " ||| " & (sender of msg) & " ||| " & (date received of msg as string) & " ||| " & (read status of msg as string)
  end repeat
  set AppleScript's text item delimiters to "###"
  if (count of msgList) = 0 then return "NO_EMAILS"
  return msgList as string
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isEmpty || output == 'NO_EMAILS') {
          return ToolResult.success('No emails in inbox.');
        }

        final emails = output.split('###').where((s) => s.trim().isNotEmpty).map((line) {
          final parts = line.split(' ||| ');
          return {
            'subject': parts.isNotEmpty ? parts[0].trim() : '',
            'from': parts.length > 1 ? parts[1].trim() : '',
            'date': parts.length > 2 ? parts[2].trim() : '',
            'read': parts.length > 3 ? parts[3].trim() == 'true' : false,
          };
        }).toList();

        return ToolResult.success(emails);
      }
      return ToolResult.error('Mail error: ${result.stderr.toString().trim()}');
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
      return ToolResult.error('subject is required');
    }

    try {
      await _ensureAppRunning('Mail');

      final script = '''
tell application "Mail"
  set inboxMsgs to messages of inbox
  repeat with msg in inboxMsgs
    if (subject of msg) contains "$subject" then
      set msgContent to "From: " & (sender of msg) & "\\n"
      set msgContent to msgContent & "Date: " & (date received of msg as string) & "\\n"
      set msgContent to msgContent & "Subject: " & (subject of msg) & "\\n\\n"
      set msgContent to msgContent & (content of msg)
      return msgContent
    end if
  end repeat
  return "EMAIL_NOT_FOUND"
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output == 'EMAIL_NOT_FOUND') {
          return ToolResult.error('No email found with subject containing "$subject"');
        }
        return ToolResult.success(output);
      }
      return ToolResult.error('Mail error: ${result.stderr.toString().trim()}');
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
