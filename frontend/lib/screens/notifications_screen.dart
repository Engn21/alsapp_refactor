import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selector.dart';

// Displays user notifications with pull-to-refresh.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Notifications')),
        actions: const [LanguageSelector()],
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
              return Center(child: Text(context.tr('No data yet')));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                return ListTile(
                  tileColor: n.read
                      ? null
                      : Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(.25),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(n.body),
                  trailing: Text(
                    '${n.createdAt.hour.toString().padLeft(2, '0')}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(.6)),
                  ),
                  onTap: () async {
                    await NotificationService.markRead(n.id);
                    _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
