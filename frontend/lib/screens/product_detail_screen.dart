import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../data/type_fields.dart';

// Detailed view for a single crop or livestock item.
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // Remote detail payload (falls back to the initial product).
  Map<String, dynamic>? detail;
  bool loading = true;
  String? error;

  final _milkQuantityCtrl = TextEditingController();
  final _milkFatCtrl = TextEditingController();
  DateTime? _milkDate;

  final _sprayPesticideCtrl = TextEditingController();
  DateTime? _sprayDate;

  final _harvestAmountCtrl = TextEditingController();
  DateTime? _harvestDate;

  // Normalized source map for rendering.
  Map<String, dynamic> get _source {
    final raw = detail ?? widget.product;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  // Record identifier used for API calls.
  String? get _recordId {
    final raw = detail?['id'] ?? widget.product['id'];
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  // Determines whether the item is crop or livestock.
  String get _currentType {
    final rawType = (detail?['type'] ?? widget.product['type'])?.toString();
    if (rawType != null && rawType.isNotEmpty) return rawType.toLowerCase();
    final source = _source;
    if (source.containsKey('cropType')) return 'crop';
    if (source.containsKey('animalType') || source.containsKey('species')) {
      return 'livestock';
    }
    return '';
  }

  bool get _isCrop => _currentType == 'crop';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _milkQuantityCtrl.dispose();
    _milkFatCtrl.dispose();
    _sprayPesticideCtrl.dispose();
    _harvestAmountCtrl.dispose();
    super.dispose();
  }

  // Deletes the current record and returns to the list.
  Future<void> _deleteItem() async {
    final id = _recordId;
    if (id == null) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Product id is missing')}),
      );
      return;
    }
    try {
      if (_isCrop) {
        await ApiService.deleteCrop(id);
      } else {
        await ApiService.deleteLivestock(id);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    }
  }

  // Confirmation dialog for deletion.
  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete item?')),
        content: Text(
          context.tr('Are you sure you want to remove this record?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await _deleteItem();
    }
  }

  // Fetches the latest detail data.
  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final id = _recordId;
    if (id == null) {
      setState(() {
        loading = false;
        error = context.tr('Product id is missing');
      });
      return;
    }
    try {
      final data = _isCrop
          ? await ApiService.cropDetail(id)
          : await ApiService.livestockDetail(id);
      setState(() => detail = data);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Shows a date picker and passes the selection to a setter.
  Future<void> _pickDate(ValueChanged<DateTime?> setter,
      {DateTime? initial}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    setter(picked);
  }

  // Submits a new milk measurement.
  Future<void> _submitMilk() async {
    final id = _recordId;
    if (id == null) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Product id is missing')}),
      );
      return;
    }
    final qty = double.tryParse(_milkQuantityCtrl.text.replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Please provide milk quantity.')}),
      );
      return;
    }
    final fat = _milkFatCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_milkFatCtrl.text.replaceAll(',', '.'));
    try {
      await ApiService.addMilkMeasurement(
        id: id,
        quantityLiters: qty,
        fatPercent: fat,
        date: _milkDate,
      );
      _milkQuantityCtrl.clear();
      _milkFatCtrl.clear();
      _milkDate = null;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('Saved'))));
      }
    } catch (e) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    }
  }

  // Submits a new spray log for crops.
  Future<void> _submitSpray() async {
    final id = _recordId;
    if (id == null) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Product id is missing')}),
      );
      return;
    }
    try {
      await ApiService.addCropSpray(
        id: id,
        date: _sprayDate,
        pesticide: _sprayPesticideCtrl.text.trim().isEmpty
            ? null
            : _sprayPesticideCtrl.text.trim(),
      );
      _sprayPesticideCtrl.clear();
      _sprayDate = null;
      await _load();
    } catch (e) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    }
  }

  // Submits a new harvest log for crops.
  Future<void> _submitHarvest() async {
    final id = _recordId;
    if (id == null) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Product id is missing')}),
      );
      return;
    }
    final amount =
        double.tryParse(_harvestAmountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Please enter harvest amount.')}),
      );
      return;
    }
    try {
      await ApiService.addCropHarvest(
        id: id,
        date: _harvestDate,
        amountTon: amount,
      );
      _harvestAmountCtrl.clear();
      _harvestDate = null;
      await _load();
    } catch (e) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    }
  }

  Widget _buildMilkSection(Map<String, dynamic> data) {
    final logs = (data['milkLogs'] as List?) ?? [];
    final quantitySpots = <FlSpot>[];
    final fatSpots = <FlSpot>[];
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i] as Map<String, dynamic>;
      final qty = (log['quantityLiters'] as num?)?.toDouble();
      final fat = (log['fatPercent'] as num?)?.toDouble();
      if (qty != null) {
        quantitySpots.add(FlSpot(i.toDouble(), qty));
      }
      if (fat != null) {
        fatSpots.add(FlSpot(i.toDouble(), fat));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('Milk Performance'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (quantitySpots.isEmpty)
          Text(context.tr('No data yet'))
        else
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(enabled: true),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: quantitySpots,
                    color: Colors.green,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (fatSpots.isNotEmpty)
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(enabled: true),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: fatSpots,
                    color: Colors.orange,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(context.tr('Add Milk Measurement'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _milkQuantityCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: context.tr('Quantity (L)')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _milkFatCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: context.tr('Fat (%) (optional)')),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_milkDate == null
                ? context.tr('Date: Today')
                : context.tr('Date: {value}',
                    params: {
                      'value': _milkDate!.toIso8601String().split('T').first
                    })),
            const Spacer(),
            TextButton(
              onPressed: () => _pickDate((d) => setState(() => _milkDate = d),
                  initial: _milkDate),
              child: Text(context.tr('Pick Date')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitMilk,
          child: Text(context.tr('Save')),
        ),
      ],
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    final str = value.toString();
    if (str.isEmpty) return '—';
    return str.contains('T') ? str.split('T').first : str;
  }

  Widget _buildCropSection(Map<String, dynamic> data) {
    final harvests = (data['harvests'] as List?) ?? [];
    final spots = <FlSpot>[];
    for (var i = 0; i < harvests.length; i++) {
      final h = harvests[i] as Map<String, dynamic>;
      final perHa = (h['yieldTonPerHa'] as num?)?.toDouble();
      if (perHa != null) {
        spots.add(FlSpot(i.toDouble(), perHa));
      }
    }

    final sprays = (data['sprays'] as List?) ?? [];
    final nextSprayDisplay = _formatDate(data['nextSprayDueAt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _infoChip(context.tr('Crop type'), data['cropType']?.toString()),
            _infoChip(context.tr('Area (ha)'),
                (data['areaHectares'] ?? '—').toString()),
            _infoChip(context.tr('Next spray due'), nextSprayDisplay),
          ],
        ),
        const SizedBox(height: 16),
        Text(context.tr('Harvest Yield (t/ha)'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (spots.isEmpty)
          Text(context.tr('No data yet'))
        else
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: Colors.indigo,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(context.tr('Spray History'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (sprays.isEmpty)
          Text(context.tr('No data yet'))
        else
                  ...sprays.reversed
              .map((e) => ListTile(
                    leading: const Icon(Icons.science),
                    title: Text(e['pesticide']?.toString() ?? '—'),
                    subtitle:
                        Text(_formatDate(e['sprayedAt'] ?? e['date'])),
                  ))
              .take(5),
        const SizedBox(height: 16),
        Text(context.tr('Log Spray'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _sprayPesticideCtrl,
          decoration: InputDecoration(
            labelText: context.tr('Pesticide (optional)'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_sprayDate == null
                ? context.tr('Date: Today')
                : context.tr('Date: {value}', params: {
                    'value': _sprayDate!.toIso8601String().split('T').first
                  })),
            const Spacer(),
            TextButton(
              onPressed: () => _pickDate((d) => setState(() => _sprayDate = d),
                  initial: _sprayDate),
              child: Text(context.tr('Pick Date')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitSpray,
          child: Text(context.tr('Save')),
        ),
        const SizedBox(height: 24),
        Text(context.tr('Log Harvest'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _harvestAmountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: context.tr('Harvest amount (ton)')),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_harvestDate == null
                ? context.tr('Date: Today')
                : context.tr('Date: {value}', params: {
                    'value': _harvestDate!.toIso8601String().split('T').first
                  })),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  _pickDate((d) => setState(() => _harvestDate = d),
                      initial: _harvestDate),
              child: Text(context.tr('Pick Date')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitHarvest,
          child: Text(context.tr('Save')),
        ),
      ],
    );
  }

  Widget _infoChip(String label, String? value) {
    return Chip(
      label: Text('$label: ${value ?? '—'}'),
    );
  }

  TypeFieldsConfig? _typeFieldsConfig(Map<String, dynamic> data) {
    if (_isCrop) {
      final type = data['cropType']?.toString();
      if (type == null || type.isEmpty) return null;
      return getCropFields(type);
    }
    final species = (data['species'] ?? data['animalType'])?.toString();
    if (species == null || species.isEmpty) return null;
    return getLivestockFields(species);
  }

  String? _formatHighlightValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    if (value is num) {
      final hasDecimal = value % 1 != 0;
      return hasDecimal ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
    }
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  IconData _highlightIconForValue(dynamic value) {
    if (value == null) return Icons.info_outline;
    if (value is DateTime) return Icons.event;
    if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return Icons.event;
    }
    if (value is num) return Icons.timeline;
    return Icons.label_outline;
  }

  Widget? _buildHighlightCards(Map<String, dynamic> data) {
    final highlights = data['trackingHighlights'];
    if (highlights is! List || highlights.isEmpty) return null;
    final chips = <Widget>[];
    for (final entry in highlights) {
      if (entry is! Map) continue;
      final labelKey = entry['labelKey']?.toString();
      if (labelKey == null) continue;
      final valueText = _formatHighlightValue(entry['value']);
      if (valueText == null || valueText.isEmpty) continue;
      chips.add(Chip(
        avatar: Icon(
          _highlightIconForValue(entry['value']),
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        label: Text('${context.tr(labelKey)}: $valueText'),
      ));
    }
    if (chips.isEmpty) return null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Key Tracking Points'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ],
        ),
      ),
    );
  }

  String? _formatTypeSpecificValue(
      TypeFieldDefinition field, dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      if (field.type == FieldInputType.choice) {
        return context.tr('choice.${field.key}.$trimmed');
      }
      if (field.type == FieldInputType.date) {
        return trimmed;
      }
      return trimmed;
    }
    if (value is num) {
      return field.type == FieldInputType.integer
          ? value.toInt().toString()
          : value.toString();
    }
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    return value.toString();
  }

  Widget? _buildTypeSpecificDetails(Map<String, dynamic> data) {
    final cfg = _typeFieldsConfig(data);
    final values = data['typeSpecific'];
    if (cfg == null || values is! Map || values.isEmpty) return null;

    final items = <Widget>[];
    String? currentGroup;
    for (final field in cfg.fields) {
      final raw = values[field.key];
      final formatted = _formatTypeSpecificValue(field, raw);
      if (formatted == null || formatted.isEmpty) continue;
      if (currentGroup != field.group) {
        currentGroup = field.group;
        items.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            context.tr('field.group.${field.group}'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ));
      }
      items.add(ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr(field.labelKey)),
        trailing: Text(formatted),
      ));
      items.add(const Divider(height: 1));
    }
    if (items.isEmpty) return null;
    if (items.last is Divider) items.removeLast();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Type Specific Details'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...items,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _source;
    final highlightCard = detail != null ? _buildHighlightCards(detail!) : null;
    final typeSpecificCard =
        detail != null ? _buildTypeSpecificDetails(detail!) : null;
    final title = (data['name'] ?? data['cropType'] ?? data['species'] ??
            data['animalType'] ?? context.tr('Product'))
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.tr('Delete'),
            onPressed: _confirmDelete,
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('Refresh'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : detail == null
                  ? Center(child: Text(context.tr('No data yet')))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (highlightCard != null) highlightCard,
                          if (typeSpecificCard != null) ...[
                            const SizedBox(height: 16),
                            typeSpecificCard,
                          ],
                          const SizedBox(height: 16),
                          if (!_isCrop)
                            _buildMilkSection(detail!)
                          else
                            _buildCropSection(detail!),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }
}
