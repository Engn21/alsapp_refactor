import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/support_service.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/language_selector.dart';
import '../l10n/app_localizations.dart';
import 'dashboard_screen.dart';

// Lists support programs and provides detail navigation.
class SupportsListScreen extends StatefulWidget {
  final String userId;
  final String password;
  final String? highlightId;
  const SupportsListScreen({
    super.key,
    required this.userId,
    required this.password,
    this.highlightId,
  });

  @override
  State<SupportsListScreen> createState() => _SupportsListScreenState();
}

class _SupportsListScreenState extends State<SupportsListScreen> {
  List<Map<String, dynamic>> supports = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Loads support programs from the backend (or fallback).
  Future<void> _load() async {
    try {
      final data = await SupportService.fetchSupportPrograms(widget.userId, widget.password);
      setState(() => supports = data);
    } catch (e) {
      // ignore; keep empty list
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Opens the detail view for a support item.
  void _openDetail(Map<String, dynamic> s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportDetailScreen(item: s),
      ),
    );
  }

  // Launches an external URL in the default browser.
  Future<void> _openExternalLink(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) return;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Baglanti acilamadi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Baglanti acilamadi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Supports')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  userId: widget.userId,
                  password: widget.password,
                ),
              ),
            );
          },
        ),
        actions: const [LanguageSelector()],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : () {
              final livestockSupports =
                  supports.where(_isLivestockSupport).toList();
              final agriculturalSupports =
                  supports.where((s) => !_isLivestockSupport(s)).toList();

              final tiles = <Widget>[];

              if (agriculturalSupports.isNotEmpty) {
                tiles.add(_sectionTitle('Tarimsal Destekler'));
                tiles.add(const SizedBox(height: 8));
                tiles.addAll(_buildSupportList(context, agriculturalSupports));
              }

              if (livestockSupports.isNotEmpty) {
                if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 16));
                tiles.add(_sectionTitle('Hayvancilik Destekleri'));
                tiles.add(const SizedBox(height: 8));
                tiles.addAll(_buildSupportList(context, livestockSupports));
              }

              if (tiles.isEmpty) {
                tiles.add(
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Text(context.tr('No data available.')),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: tiles,
              );
            }(),
      bottomNavigationBar: BottomNavigation(
        currentIndex: 1,
        userId: widget.userId,
        password: widget.password,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // optional: flag/save
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _buildSupportList(
    BuildContext context,
    List<Map<String, dynamic>> data,
  ) {
    final items = <Widget>[];
    for (var i = 0; i < data.length; i++) {
      final support = data[i];
      final highlight = widget.highlightId != null &&
          widget.highlightId == support['id']?.toString();
      items.add(_supportCard(context, support, highlight: highlight));
      if (i != data.length - 1) {
        items.add(const SizedBox(height: 12));
      }
    }
    return items;
  }

  Widget _supportCard(
    BuildContext context,
    Map<String, dynamic> support, {
    required bool highlight,
  }) {
    final summary = (support['summary'] ?? support['description'] ?? '').toString();
    final officialGazetteUrl = support['officialGazetteUrl']?.toString();
    final institutionUrl =
        (support['institutionUrl'] ?? support['link'])?.toString();

    return Card(
      color: highlight
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: ListTile(
        title: Text(
          support['title']?.toString() ?? context.tr('Support'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if ((officialGazetteUrl != null && officialGazetteUrl.isNotEmpty) ||
                (institutionUrl != null && institutionUrl.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (officialGazetteUrl != null &&
                        officialGazetteUrl.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.article_outlined, size: 18),
                        label: const Text('Resmi Gazete'),
                        onPressed: () => _openExternalLink(officialGazetteUrl),
                      ),
                    if (institutionUrl != null && institutionUrl.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.apartment_outlined, size: 18),
                        label: const Text('Bakanlik'),
                        onPressed: () => _openExternalLink(institutionUrl),
                      ),
                  ],
                ),
              ),
          ],
        ),
        trailing: TextButton(
          child: Text(context.tr('More Info')),
          onPressed: () => _openDetail(support),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  bool _isLivestockSupport(Map<String, dynamic> support) {
    final category = (support['category'] ?? '').toString().toLowerCase();
    if (category.contains('hayvansal')) return true;
    if (category.contains('livestock')) return true;
    if (category.contains('animal')) return true;
    return false;
  }

}

class SupportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const SupportDetailScreen({super.key, required this.item});

  // Opens external URLs safely with error feedback.
  Future<void> _openLink(BuildContext context, String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) return;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Baglanti acilamadi.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Baglanti acilamadi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = (item['summary'] ?? item['description'] ?? '').toString();
    final detail = (item['detail'] ??
            context.tr('Full application procedures and notes appear here.'))
        .toString();
    final amount = item['amount']?.toString();
    final region = item['region']?.toString();
    final provider = item['provider']?.toString();
    final updatedAt = item['updatedAt']?.toString();
    final officialGazetteUrl = item['officialGazetteUrl']?.toString();
    final institutionUrl = (item['institutionUrl'] ?? item['link'])?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(item['title']?.toString() ?? context.tr('Support')),
        actions: const [LanguageSelector()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (summary.isNotEmpty) ...[
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (amount != null && amount.isNotEmpty) ...[
            _metadataTile(
              icon: Icons.payments_outlined,
              label: 'Destek Tutari',
              value: amount,
            ),
            const SizedBox(height: 8),
          ],
          if (region != null && region.isNotEmpty) ...[
            _metadataTile(
              icon: Icons.map_outlined,
              label: 'Bolge',
              value: region,
            ),
            const SizedBox(height: 8),
          ],
          if (provider != null && provider.isNotEmpty) ...[
            _metadataTile(
              icon: Icons.account_balance_outlined,
              label: 'Sorumlu Kurum',
              value: provider,
            ),
            const SizedBox(height: 8),
          ],
          if (updatedAt != null && updatedAt.isNotEmpty) ...[
            _metadataTile(
              icon: Icons.update,
              label: 'Son Guncelleme',
              value: updatedAt,
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (officialGazetteUrl != null && officialGazetteUrl.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Resmi Gazete'),
                  onPressed: () => _openLink(context, officialGazetteUrl),
                ),
              if (institutionUrl != null && institutionUrl.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.apartment_outlined),
                  label: const Text('Bakanlik Sayfasi'),
                  onPressed: () => _openLink(context, institutionUrl),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metadataTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
