enum EmailFolder { inbox, sent, drafts, trash, archive, spam }

enum EmailPriority { low, normal, high, urgent }

class EmailMessage {
  final String id;
  final String from;
  final String subject;
  final String body;
  final DateTime date;
  final bool isUnread;
  final bool isMeeting;
  final bool hasDeadline;
  final bool isImportant;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final EmailFolder folder;
  final EmailPriority priority;
  final List<String> labels;
  final String? inReplyTo;
  final String? threadId;
  final bool hasAttachments;
  final int? size;

  EmailMessage({
    required this.id,
    required this.from,
    required this.subject,
    this.body = '',
    required this.date,
    this.isUnread = true,
    this.isMeeting = false,
    this.hasDeadline = false,
    this.isImportant = false,
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.folder = EmailFolder.inbox,
    this.priority = EmailPriority.normal,
    this.labels = const [],
    this.inReplyTo,
    this.threadId,
    this.hasAttachments = false,
    this.size,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'from': from,
    'subject': subject,
    'body': body,
    'date': date.toIso8601String(),
    'is_unread': isUnread ? 1 : 0,
    'is_meeting': isMeeting ? 1 : 0,
    'has_deadline': hasDeadline ? 1 : 0,
    'is_important': isImportant ? 1 : 0,
    'to': to.join(','),
    'cc': cc.join(','),
    'bcc': bcc.join(','),
    'folder': folder.name,
    'priority': priority.name,
    'labels': labels.join(','),
    'in_reply_to': inReplyTo,
    'thread_id': threadId,
    'has_attachments': hasAttachments ? 1 : 0,
    'size': size,
  };

  factory EmailMessage.fromMap(Map<String, dynamic> map) => EmailMessage(
    id: map['id'] as String,
    from: map['from'] as String,
    subject: map['subject'] as String,
    body: (map['body'] as String?) ?? '',
    date: DateTime.parse(map['date'] as String),
    isUnread: (map['is_unread'] as int?) == 1,
    isMeeting: (map['is_meeting'] as int?) == 1,
    hasDeadline: (map['has_deadline'] as int?) == 1,
    isImportant: (map['is_important'] as int?) == 1,
    to: (map['to'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
    cc: (map['cc'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
    bcc: (map['bcc'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
    folder: EmailFolder.values.firstWhere((f) => f.name == map['folder'], orElse: () => EmailFolder.inbox),
    priority: EmailPriority.values.firstWhere((p) => p.name == map['priority'], orElse: () => EmailPriority.normal),
    labels: (map['labels'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
    inReplyTo: map['in_reply_to'] as String?,
    threadId: map['thread_id'] as String?,
    hasAttachments: (map['has_attachments'] as int?) == 1,
    size: map['size'] as int?,
  );

  EmailMessage copyWith({
    String? from,
    String? subject,
    String? body,
    DateTime? date,
    bool? isUnread,
    bool? isMeeting,
    bool? hasDeadline,
    bool? isImportant,
    List<String>? to,
    List<String>? cc,
    EmailFolder? folder,
    EmailPriority? priority,
    List<String>? labels,
    String? inReplyTo,
    String? threadId,
    bool? hasAttachments,
  }) => EmailMessage(
    id: id,
    from: from ?? this.from,
    subject: subject ?? this.subject,
    body: body ?? this.body,
    date: date ?? this.date,
    isUnread: isUnread ?? this.isUnread,
    isMeeting: isMeeting ?? this.isMeeting,
    hasDeadline: hasDeadline ?? this.hasDeadline,
    isImportant: isImportant ?? this.isImportant,
    to: to ?? this.to,
    cc: cc ?? this.cc,
    bcc: bcc,
    folder: folder ?? this.folder,
    priority: priority ?? this.priority,
    labels: labels ?? this.labels,
    inReplyTo: inReplyTo ?? this.inReplyTo,
    threadId: threadId ?? this.threadId,
    hasAttachments: hasAttachments ?? this.hasAttachments,
    size: size,
  );

  String get preview => body.length > 200 ? '${body.substring(0, 200)}...' : body;
  String get senderName {
    final match = RegExp(r'^"?([^"<]+)"?\s*<').firstMatch(from);
    return match != null ? match.group(1)!.trim() : from;
  }
  String get displayDate => '${date.month}/${date.day}/${date.year}';
  bool get isToday { final now = DateTime.now(); return date.year == now.year && date.month == now.month && date.day == now.day; }
  bool get isUpcoming => date.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'subject': subject,
    'body': body,
    'date': date.toIso8601String(),
    'isUnread': isUnread,
    'to': to,
    'cc': cc,
    'folder': folder.name,
    'priority': priority.name,
    'labels': labels,
  };
}
