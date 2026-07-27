import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';
import '../navigation.dart';
import '../widgets/language_selector.dart';
import '../theme/app_theme.dart';

// Displays user notifications with pull-to-refresh. Actionable alerts
// (production/quality warnings) are visually distinct from informational
// ones, and tapping one that references a crop/animal jumps straight to
// it so the farmer can act on it, not just dismiss it.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = NotificationService.list();
  }

  Future<void> _refresh() async {
    setState(() => _future = NotificationService.list());
  }

  Future<void> _markAllRead(List<NotificationItem> items) async {
    final unread = items.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    await Future.wait(unread.map((n) => NotificationService.markRead(n.id)));
    await _refresh();
  }

  Future<void> _openNotification(NotificationItem n) async {
    if (!n.read) {
      await NotificationService.markRead(n.id);
    }
    if (!mounted) return;

    await openRelatedRecord(
      cropId: n.relatedCropId,
      livestockId: n.relatedLivestockId,
    );
    if (mounted) await _refresh();
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return context.tr('Just now');
    if (diff.inMinutes < 60) {
      return context.tr('{count}m ago', params: {'count': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return context.tr('{count}h ago', params: {'count': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return context.tr('{count}d ago', params: {'count': '${diff.inDays}'});
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(context.tr('Notifications')),
        actions: [
          FutureBuilder<List<NotificationItem>>(
            future: _future,
            builder: (context, snap) {
              final items = snap.data ?? const <NotificationItem>[];
              final hasUnread = items.any((n) => !n.read);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllRead(items),
                child: Text(
                  context.tr('Mark all read'),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
          const LanguageSelector(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<NotificationItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                  child: Text(context
                      .tr('Load error: {message}', params: {'message': '${snap.error}'})));
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('No notifications yet'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr(
                                  'We will alert you here about production issues, quality warnings, and spray reminders.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                final actionable = n.isActionable;
                final canOpen =
                    n.relatedCropId != null || n.relatedLivestockId != null;
                final accent = !n.read
                    ? (actionable ? Colors.red.shade600 : Colors.green.shade600)
                    : Colors.grey.shade400;

                return Material(
                  color: !n.read
                      ? (actionable
                          ? Colors.red.withOpacity(.06)
                          : Colors.green.withOpacity(.06))
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openNotification(n),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border(left: BorderSide(color: accent, width: 4)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: accent.withOpacity(.15),
                            child: Icon(
                              actionable
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n.localizedTitle(context),
                                        style: TextStyle(
                                          fontWeight:
                                              !n.read ? FontWeight.w700 : FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (!n.read)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  n.localizedBody(context),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(.75),
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      _relativeTime(context, n.createdAt),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    if (canOpen) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '· ${context.tr('Tap to view')}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (canOpen)
                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
