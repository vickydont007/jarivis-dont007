import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/email_message.dart';
import '../core/providers.dart';
import '../core/services/email_service.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/common/empty_state.dart';

class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  bool _isLoading = false;
  String? _error;
  EmailFolder _currentFolder = EmailFolder.inbox;
  List<EmailMessage> _emails = [];
  EmailMessage? _selectedEmail;
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmails();
  }

  EmailService get _emailService => ref.read(emailServiceProvider);

  Future<void> _loadEmails() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      if (_emailService.isConfigured) {
        await _emailService.fetchEmails(folder: _currentFolder, limit: 30);
      }
      _emails = await _emailService.getStoredEmails(folder: _currentFolder, limit: 30);
    } catch (e) {
      _error = 'Failed to load emails: $e';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _searchEmails() async {
    if (_searchQuery.isEmpty) {
      await _loadEmails();
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      _emails = await _emailService.searchEmails(_searchQuery, limit: 30);
    } catch (e) {
      _error = 'Search failed: $e';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _composeEmail() async {
    final toController = TextEditingController();
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Compose Email', style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: toController,
                decoration: const InputDecoration(
                  hintText: 'To',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  hintText: 'Subject',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Email body...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: AppColors.textPrimary),
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
            child: const Text('Send', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (result == true && toController.text.isNotEmpty && subjectController.text.isNotEmpty) {
      await _emailService.sendEmail(
        to: toController.text.trim(),
        subject: subjectController.text.trim(),
        body: bodyController.text.trim(),
      );
      await _loadEmails();
    }
  }

  Future<void> _markAsRead(EmailMessage email) async {
    await _emailService.markAsRead(email.id);
    setState(() {
      _selectedEmail = email.copyWith(isUnread: false);
      _emails = _emails.map((e) => e.id == email.id ? e.copyWith(isUnread: false) : e).toList();
    });
  }

  Future<void> _archiveEmail(EmailMessage email) async {
    await _emailService.archiveEmail(email.id);
    setState(() {
      _emails.removeWhere((e) => e.id == email.id);
      if (_selectedEmail?.id == email.id) _selectedEmail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            // Email list panel
            SizedBox(
              width: 400,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildFolderTabs(),
                  if (_isSearching) _buildSearchBar(),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                        : _error != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                                    const SizedBox(height: 12),
                                    GlassButton(
                                      onPressed: _loadEmails,
                                      label: 'Retry',
                                      isCompact: true,
                                    ),
                                  ],
                                ),
                              )
                            : _emails.isEmpty
                                ? EmptyState(
                                    icon: Icons.email_outlined,
                                    title: _currentFolder == EmailFolder.inbox ? 'No emails' : 'No emails in ${_currentFolder.name}',
                                    subtitle: _emailService.isConfigured
                                        ? 'Connect to see your emails'
                                        : 'Configure email in Settings',
                                  )
                                : _buildEmailList(),
                  ),
                ],
              ),
            ),

            // Divider
            const VerticalDivider(width: 1, color: AppColors.glassBorder),

            // Email detail panel
            Expanded(
              child: _selectedEmail != null
                  ? _buildEmailDetail(_selectedEmail!)
                  : _buildEmptyDetail(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📧 Email',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _emailService.isConfigured
                      ? '${_emailService.username ?? "Connected"}'
                      : 'Not configured — set up in Settings',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppColors.textSecondary),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _loadEmails();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loadEmails,
          ),
          GlassButton(
            onPressed: _composeEmail,
            label: 'Compose',
            icon: Icons.edit,
            isCompact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTabs() {
    final folders = [
      (EmailFolder.inbox, '📥', 'Inbox'),
      (EmailFolder.sent, '📤', 'Sent'),
      (EmailFolder.drafts, '📝', 'Drafts'),
      (EmailFolder.archive, '📦', 'Archive'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Row(
        children: folders.map((f) {
          final isActive = _currentFolder == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () {
                setState(() => _currentFolder = f.$1);
                _loadEmails();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accentGhost : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? AppColors.accent : AppColors.glassBorder,
                  ),
                ),
                child: Text(
                  '${f.$2} ${f.$3}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
      child: GlassTextField(
        controller: _searchController,
        hintText: 'Search emails...',
        onChanged: (value) {
          _searchQuery = value;
          _searchEmails();
        },
      ),
    );
  }

  Widget _buildEmailList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      itemCount: _emails.length,
      itemBuilder: (context, index) {
        final email = _emails[index];
        final isSelected = _selectedEmail?.id == email.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedEmail = email);
              if (email.isUnread) _markAsRead(email);
            },
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentGhost : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    width: isSelected ? 1.5 : 0,
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unread indicator
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: email.isUnread ? AppColors.accent : Colors.transparent,
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  email.senderName,
                                  style: TextStyle(
                                    fontWeight: email.isUnread ? FontWeight.w600 : FontWeight.w400,
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(email.date),
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email.subject,
                            style: TextStyle(
                              fontWeight: email.isUnread ? FontWeight.w500 : FontWeight.w400,
                              color: email.isUnread ? AppColors.textPrimary : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email.preview,
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Flags
                          if (email.isMeeting || email.hasDeadline || email.isImportant)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  if (email.isImportant) _flagChip('⭐', 'Important'),
                                  if (email.isMeeting) _flagChip('📅', 'Meeting'),
                                  if (email.hasDeadline) _flagChip('⏰', 'Deadline'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _flagChip(String icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$icon $label', style: const TextStyle(fontSize: 9, color: AppColors.textTertiary)),
    );
  }

  Widget _buildEmailDetail(EmailMessage email) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email.subject,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.accentGhost,
                          child: Text(
                            email.senderName.isNotEmpty ? email.senderName[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.accent, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email.senderName,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              email.from,
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.archive, color: AppColors.textTertiary),
                onPressed: () => _archiveEmail(email),
                tooltip: 'Archive',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: AppSpacing.md),

          // Date
          Text(
            'Received: ${email.date}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          if (email.to.isNotEmpty)
            Text(
              'To: ${email.to.join(", ")}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Body
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                email.body.isNotEmpty ? email.body : email.preview,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),

          // Actions
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.glassBorder),
          Row(
            children: [
              GlassButton(
                onPressed: () {
                  // Reply via AI
                },
                label: 'Reply',
                icon: Icons.reply,
                isCompact: true,
              ),
              const SizedBox(width: AppSpacing.sm),
              GlassButton(
                onPressed: () {
                  // Forward via AI
                },
                label: 'Forward',
                icon: Icons.forward,
                isCompact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDetail() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.email_outlined, size: 64, color: AppColors.textTertiary),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Select an email to read',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}';
  }
}
