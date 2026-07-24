import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/support_service.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/language_selector.dart';
import '../l10n/app_localizations.dart';
import 'dashboard_screen.dart';

// Lists support programs and provides detail navigation.
class SupportsListScreen extends StatefulWidget {
  final String userId;
  final String? highlightId;
  const SupportsListScreen({
    super.key,
    required this.userId,
    this.highlightId,
  });

  @override
  State<SupportsListScreen> createState() => _SupportsListScreenState();
}

class _SupportsListScreenState extends State<SupportsListScreen> {
  List<Map<String, dynamic>> supports = [];
  bool loading = true;
  String? _loadedLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations.localeOf needs an established InheritedWidget
    // dependency, which isn't available in initState. Re-load whenever
    // the resolved locale actually changes (e.g. the user switches
    // language while this screen is open), not just on first mount.
    final lang = Localizations.localeOf(context).languageCode;
    if (_loadedLang != lang) {
      _loadedLang = lang;
      _load();
    }
  }

  // Loads support programs from the backend (or fallback).
  Future<void> _load() async {
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final data = await SupportService.fetchSupportPrograms(lang: lang);
      if (!mounted) return;
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
    final errorText = context.tr('Link could not be opened.');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(errorText)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(errorText)));
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
                tiles.add(_sectionTitle(context.tr('Agricultural Supports')));
                tiles.add(const SizedBox(height: 8));
                tiles.addAll(_buildSupportList(context, agriculturalSupports));
              }

              if (livestockSupports.isNotEmpty) {
                if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 16));
                tiles.add(_sectionTitle(context.tr('Livestock Supports')));
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
    final isMatch = support['matchesFarm'] == true;

    return Card(
      color: highlight
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(support['title']?.toString() ?? context.tr('Support')),
            ),
            if (isMatch)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  context.tr('Matches Your Farm'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
          ],
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
                        label: Text(context.tr('Official Gazette')),
                        onPressed: () => _openExternalLink(officialGazetteUrl),
                      ),
                    if (institutionUrl != null && institutionUrl.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.apartment_outlined, size: 18),
                        label: Text(context.tr('Ministry')),
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

class SupportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const SupportDetailScreen({super.key, required this.item});

  @override
  State<SupportDetailScreen> createState() => _SupportDetailScreenState();
}

class _SupportDetailScreenState extends State<SupportDetailScreen> {
  late Map<String, dynamic> item = widget.item;
  String? _loadedLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This screen used to be built once from whatever the list screen
    // already fetched, so switching language while it was open did
    // nothing - re-fetch by id whenever the resolved locale changes.
    final lang = Localizations.localeOf(context).languageCode;
    if (_loadedLang == null) {
      _loadedLang = lang;
      return;
    }
    if (_loadedLang != lang) {
      _loadedLang = lang;
      _reload(lang);
    }
  }

  Future<void> _reload(String lang) async {
    final id = item['id']?.toString();
    if (id == null) return;
    try {
      final fresh = await ApiService.getSupportDetail(id, lang: lang);
      if (!mounted) return;
      setState(() => item = fresh);
    } catch (_) {
      // keep showing the previous (stale-language) data on failure
    }
  }

  // Opens external URLs safely with error feedback.
  Future<void> _openLink(BuildContext context, String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) return;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.tr('Link could not be opened.');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(errorText)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(errorText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = (item['summary'] ?? item['description'] ?? '').toString();
    // Only the demo/fallback data has a distinct long-form `detail`; real
    // API data just has `description` (already shown above as summary), so
    // don't show a generic placeholder pretending to be real content.
    final detailRaw = item['detail']?.toString();
    final detail =
        (detailRaw != null && detailRaw.isNotEmpty && detailRaw != summary)
            ? detailRaw
            : null;
    final amount = item['amount']?.toString();
    final region = item['region']?.toString();
    final provider = item['provider']?.toString();
    final updatedAtRaw = item['updatedAt']?.toString();
    final updatedAt = updatedAtRaw != null && updatedAtRaw.contains('T')
        ? updatedAtRaw.split('T').first
        : updatedAtRaw;
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
          if (detail != null) ...[
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
          ],
          if (amount != null && amount.isNotEmpty) ...[
            _metadataTile(
              icon: Icons.payments_outlined,
              label: context.tr('Support Amount'),
              value: amount,
            ),
            const SizedBox(height: 8),
          ],
          if (region != null && region.isNotEmpty) ...[
            _metadataTile(
              icon: Icons.map_outlined,
              label: context.tr('Region'),
              value: region,
            ),
            const SizedBox(height: 8),
          ],
          if (provider != null && provider.isNotEmpty) ...[
            _metadataTile(
              icon: Icons.account_balance_outlined,
              label: context.tr('Responsible Institution'),
              value: provider,
            ),
            const SizedBox(height: 8),
          ],
          if (updatedAt != null && updatedAt.isNotEmpty) ...[
            _metadataTile(
              icon: Icons.update,
              label: context.tr('Last Updated'),
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
                  label: Text(context.tr('Official Gazette')),
                  onPressed: () => _openLink(context, officialGazetteUrl),
                ),
              if (institutionUrl != null && institutionUrl.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.apartment_outlined),
                  label: Text(context.tr('Ministry Page')),
                  onPressed: () => _openLink(context, institutionUrl),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                            'This app only helps you discover support programs - it does not submit applications.'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: Text(context.tr('Apply via e-Devlet / ÇKS')),
                        onPressed: () =>
                            _openLink(context, 'https://www.turkiye.gov.tr'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
