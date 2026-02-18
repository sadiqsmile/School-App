import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../models/user_role.dart';
import '../../../utils/attachment_download/attachment_download.dart';
import '../../../widgets/loading_view.dart';

class HomeworkDetailsScreen extends ConsumerWidget {
  const HomeworkDetailsScreen({
    super.key,
    required this.yearId,
    required this.homeworkId,
    this.showTeacherActions = true,
  });

  final String yearId;
  final String homeworkId;
  final bool showTeacherActions;

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Invalid URL')));
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open attachment')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;
    final appUser = ref.watch(appUserProvider).asData?.value;

    final docStream = ref
        .read(homeworkServiceProvider)
        .homeworkCollection(yearId: yearId)
        .doc(homeworkId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Homework / Notes')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingView(message: 'Loading…'));
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final doc = snap.data;
          if (doc == null || !doc.exists) {
            return const Center(child: Text('Not found'));
          }

          final data = doc.data() ?? const <String, dynamic>{};
          final title = (data['title'] as String?) ?? 'Untitled';
          final description = (data['description'] as String?) ?? '';
          final subject = (data['subject'] as String?) ?? '-';
          final type = (data['type'] as String?) ?? '-';
          final classId = (data['class'] as String?) ?? '-';
          final sectionId = (data['section'] as String?) ?? '-';
          final createdByName = (data['createdByName'] as String?) ?? '-';
          final createdByUid = (data['createdByUid'] as String?) ?? '';
          final isActive = (data['isActive'] ?? true) == true;
          final ts = data['publishDate'];
          final publishDate = ts is Timestamp ? ts.toDate() : null;

          final rawAttachments = (data['attachments'] as List?) ?? const [];

          final myUid = authUser?.uid;
          final isAdmin = appUser?.role == UserRole.admin;
          final isTeacher = appUser?.role == UserRole.teacher;
          final canManage = showTeacherActions && (isAdmin || (isTeacher && myUid != null && myUid == createdByUid));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(subject)),
                          Chip(label: Text(type)),
                          Chip(label: Text('Class: $classId')),
                          Chip(label: Text('Section: $sectionId')),
                          Chip(label: Text(isActive ? 'Active' : 'Disabled')),
                          Chip(label: Text('Date: ${publishDate == null ? '—' : _fmt(publishDate)}')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (description.trim().isNotEmpty) ...[
                        Text(description),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Created by: $createdByName${createdByUid.isEmpty ? '' : ' ($createdByUid)'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Attachments (${rawAttachments.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      if (rawAttachments.isEmpty)
                        Text(
                          'No attachments',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        )
                      else
                        for (final a in rawAttachments)
                          _AttachmentTile(
                            attachment: a,
                            onOpen: (url) => _openUrl(context, url),
                            onDownload: (url, {fileName}) => downloadUrl(url, fileName: fileName),
                            onCopy: (url) => Clipboard.setData(ClipboardData(text: url)),
                            onDelete: !canManage
                                ? null
                                : ({required String storagePath}) async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Delete attachment?'),
                                          content: const Text('This will remove the file from Storage and this homework item.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (ok != true) return;
                                    await ref.read(homeworkServiceProvider).deleteHomeworkAttachment(
                                          yearId: yearId,
                                          homeworkId: homeworkId,
                                          storagePath: storagePath,
                                        );
                                    if (context.mounted) {
                                      _snack(context, 'Attachment deleted');
                                    }
                                  },
                          ),
                    ],
                  ),
                ),
              ),
              if (showTeacherActions) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Teacher actions',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Disable item?'),
                                    content: const Text('This will set isActive = false.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Disable'),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (ok != true) return;

                              await ref.read(homeworkServiceProvider).setHomeworkActive(
                                    yearId: yearId,
                                    homeworkId: homeworkId,
                                    isActive: false,
                                  );

                              if (context.mounted) {
                                _snack(context, 'Disabled');
                              }
                            },
                            icon: const Icon(Icons.block_outlined),
                            label: const Text('Disable (isActive=false)'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 48,
                          child: FilledButton.tonalIcon(
                            onPressed: canManage
                                ? () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Delete this item?'),
                                          content: const Text('This will delete the homework/notes document and all its attachments.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (ok != true) return;
                                    await ref.read(homeworkServiceProvider).deleteHomework(
                                          yearId: yearId,
                                          homeworkId: homeworkId,
                                        );
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.delete_outline),
                            label: Text(canManage ? 'Delete (creator only)' : 'Delete (not allowed)'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Storage files are not deleted automatically (free-plan friendly).',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.onOpen,
    required this.onDownload,
    required this.onCopy,
    required this.onDelete,
  });

  final Object attachment;
  final ValueChanged<String> onOpen;
  final Future<bool> Function(String url, {String? fileName}) onDownload;
  final ValueChanged<String> onCopy;
  final Future<void> Function({required String storagePath})? onDelete;

  @override
  Widget build(BuildContext context) {
    if (attachment is! Map) {
      return const ListTile(title: Text('Invalid attachment')); // defensive
    }

    final map = attachment as Map;
    final name = ((map['name'] ?? map['fileName']) ?? '').toString();
    final url = ((map['url'] ?? map['fileUrl']) ?? '').toString();
    final type = ((map['fileType'] ?? map['type']) ?? '').toString();
    final size = map['sizeBytes'] ?? map['size'];
    final storagePath = (map['storagePath'] ?? '').toString();

    final icon = switch (type) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'image' => Icons.image_outlined,
      _ => Icons.attach_file,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(name.isEmpty ? 'Attachment' : name),
      subtitle: Text('Type: ${type.isEmpty ? 'file' : type}${size == null ? '' : ' • Size: $size'}'),
      trailing: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: url.isEmpty ? null : () => onOpen(url),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
          TextButton.icon(
            onPressed: url.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await onDownload(url, fileName: name.isEmpty ? null : name);
                    if (!ok) {
                      messenger.showSnackBar(const SnackBar(content: Text('Could not download')));
                    }
                  },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download'),
          ),
          IconButton(
            tooltip: 'Copy link',
            onPressed: url.isEmpty
                ? null
                : () {
                    onCopy(url);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Link copied')));
                  },
            icon: const Icon(Icons.link_outlined),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: storagePath.trim().isEmpty
                  ? null
                  : () => onDelete!.call(storagePath: storagePath),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}
