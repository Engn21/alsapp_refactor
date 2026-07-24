import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../data/type_fields.dart';
import '../widgets/type_specific_fields.dart';

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

  final _eggCountCtrl = TextEditingController();
  final _eggWeightCtrl = TextEditingController();
  DateTime? _eggDate;

  final _honeyAmountCtrl = TextEditingController();
  final _honeyQualityCtrl = TextEditingController();
  DateTime? _honeyDate;

  final _sprayPesticideCtrl = TextEditingController();
  DateTime? _sprayDate;

  final _harvestAmountCtrl = TextEditingController();
  DateTime? _harvestDate;

  final _qualityProteinCtrl = TextEditingController();
  final _qualityMoistureCtrl = TextEditingController();
  final _qualitySugarCtrl = TextEditingController();
  final _qualityOilCtrl = TextEditingController();
  DateTime? _qualityDate;

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

  // Only these livestock types actually produce milk; the rest (poultry,
  // bees, fish) have no milk data, so the milk section must not show for
  // them. Sheep is included for dairy breeds (e.g. Sakız, Awassi).
  static const _dairyLivestockTypes = {'cow', 'goat', 'buffalo', 'camel', 'sheep'};

  bool get _isDairy {
    if (_isCrop) return false;
    final species =
        (_source['species'] ?? _source['animalType'])?.toString().toLowerCase();
    return species != null && _dairyLivestockTypes.contains(species);
  }

  // Turkey is meat-focused and isn't tracked for egg-laying, matching the
  // backend's threshold config (no minDailyEggs for turkey).
  static const _layingLivestockTypes = {'chicken', 'duck'};

  bool get _isLayer {
    if (_isCrop) return false;
    final species =
        (_source['species'] ?? _source['animalType'])?.toString().toLowerCase();
    return species != null && _layingLivestockTypes.contains(species);
  }

  bool get _isBee {
    if (_isCrop) return false;
    final species =
        (_source['species'] ?? _source['animalType'])?.toString().toLowerCase();
    return species == 'bee';
  }

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
    _qualityProteinCtrl.dispose();
    _qualityMoistureCtrl.dispose();
    _qualitySugarCtrl.dispose();
    _qualityOilCtrl.dispose();
    _eggCountCtrl.dispose();
    _eggWeightCtrl.dispose();
    _honeyAmountCtrl.dispose();
    _honeyQualityCtrl.dispose();
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

  // Opens the edit form for the current record; reloads on success.
  Future<void> _openEditForm() async {
    final id = _recordId;
    if (id == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: _EditItemForm(
          id: id,
          isCrop: _isCrop,
          data: _source,
        ),
      ),
    );
    if (result == true) {
      await _load();
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
      if (!mounted) return;
      setState(() => detail = data);
    } catch (e) {
      if (!mounted) return;
      // A 404 here almost always means the record was deleted (e.g. from
      // an old notification linking to it) - show a plain explanation
      // instead of dumping the raw exception text.
      final notFound = e.toString().contains('404');
      setState(() {
        error = notFound
            ? context.tr('This record no longer exists. It may have been deleted.')
            : context.tr('Load error: {message}', params: {'message': '$e'});
      });
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
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    }
  }

  // Submits a new quality log (protein/moisture/sugar/oil) for crops.
  Future<void> _submitQuality() async {
    final id = _recordId;
    if (id == null) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Product id is missing')}),
      );
      return;
    }
    double? parse(String text) =>
        text.trim().isEmpty ? null : double.tryParse(text.replaceAll(',', '.'));
    final protein = parse(_qualityProteinCtrl.text);
    final moisture = parse(_qualityMoistureCtrl.text);
    final sugar = parse(_qualitySugarCtrl.text);
    final oil = parse(_qualityOilCtrl.text);
    if (protein == null && moisture == null && sugar == null && oil == null) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Enter at least one quality value.')}),
      );
      return;
    }
    try {
      await ApiService.addCropQuality(
        id: id,
        date: _qualityDate,
        proteinPercent: protein,
        moisturePercent: moisture,
        sugarPercent: sugar,
        oilPercent: oil,
      );
      _qualityProteinCtrl.clear();
      _qualityMoistureCtrl.clear();
      _qualitySugarCtrl.clear();
      _qualityOilCtrl.clear();
      _qualityDate = null;
      await _load();
    } catch (e) {
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    }
  }

  // Submits a new egg count log for chicken/duck.
  Future<void> _submitEgg() async {
    final id = _recordId;
    if (id == null) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Product id is missing')}),
      );
      return;
    }
    final count = int.tryParse(_eggCountCtrl.text.trim());
    if (count == null || count < 0) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Please enter egg count.')}),
      );
      return;
    }
    final weight =
        _eggWeightCtrl.text.trim().isEmpty ? null : double.tryParse(_eggWeightCtrl.text.replaceAll(',', '.'));
    try {
      await ApiService.addEggData(
        id: id,
        eggCount: count,
        avgWeightGram: weight,
        date: _eggDate,
      );
      _eggCountCtrl.clear();
      _eggWeightCtrl.clear();
      _eggDate = null;
      await _load();
    } catch (e) {
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    }
  }

  // Submits a new honey harvest log for bees.
  Future<void> _submitHoney() async {
    final id = _recordId;
    if (id == null) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Product id is missing')}),
      );
      return;
    }
    final amount = double.tryParse(_honeyAmountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}',
            params: {'message': context.tr('Please enter honey amount.')}),
      );
      return;
    }
    try {
      await ApiService.addHoneyData(
        id: id,
        amountKg: amount,
        qualityGrade: _honeyQualityCtrl.text,
        date: _honeyDate,
      );
      _honeyAmountCtrl.clear();
      _honeyQualityCtrl.clear();
      _honeyDate = null;
      await _load();
    } catch (e) {
      if (!mounted) return;
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

  Widget _buildEggSection(Map<String, dynamic> data) {
    final logs = (data['eggLogs'] as List?) ?? [];
    final countSpots = <FlSpot>[];
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i] as Map<String, dynamic>;
      final count = (log['eggCount'] as num?)?.toDouble();
      if (count != null) {
        countSpots.add(FlSpot(i.toDouble(), count));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('Egg Production'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (countSpots.isEmpty)
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
                    spots: countSpots,
                    color: Colors.brown,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(context.tr('Add Egg Count'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _eggCountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.tr('Egg count')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _eggWeightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: context.tr('Average weight (g) (optional)')),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_eggDate == null
                ? context.tr('Date: Today')
                : context.tr('Date: {value}',
                    params: {
                      'value': _eggDate!.toIso8601String().split('T').first
                    })),
            const Spacer(),
            TextButton(
              onPressed: () => _pickDate((d) => setState(() => _eggDate = d),
                  initial: _eggDate),
              child: Text(context.tr('Pick Date')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitEgg,
          child: Text(context.tr('Save')),
        ),
      ],
    );
  }

  String _formatHoneyLog(Map<String, dynamic> log) {
    final amount = (log['amountKg'] as num?)?.toDouble();
    final quality = log['qualityGrade']?.toString();
    final amountText =
        amount != null ? '${amount.toStringAsFixed(1)} kg' : '—';
    return quality != null && quality.isNotEmpty
        ? '$amountText · $quality'
        : amountText;
  }

  Widget _buildHoneySection(Map<String, dynamic> data) {
    final logs = ((data['honeyLogs'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('Honey Harvest History'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          Text(context.tr('No data yet'))
        else
          ...logs.reversed.take(5).map((e) => ListTile(
                leading: const Icon(Icons.hive_outlined),
                title: Text(_formatHoneyLog(e)),
                subtitle: Text(_formatDate(e['measuredAt'])),
              )),
        const SizedBox(height: 16),
        Text(context.tr('Log Honey Harvest'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _honeyAmountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: context.tr('Amount (kg)')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _honeyQualityCtrl,
          decoration: InputDecoration(
              labelText: context.tr('Quality grade (optional)')),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_honeyDate == null
                ? context.tr('Date: Today')
                : context.tr('Date: {value}',
                    params: {
                      'value': _honeyDate!.toIso8601String().split('T').first
                    })),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  _pickDate((d) => setState(() => _honeyDate = d),
                      initial: _honeyDate),
              child: Text(context.tr('Pick Date')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitHoney,
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
    // yieldTonPerHa is only stored on a harvest if the crop already had an
    // area set at the time it was logged. Older/arealess harvests still
    // have amountTon, so fall back to computing yield from the crop's
    // current area, and finally to plotting the raw amount, rather than
    // showing an empty chart that looks like the harvest wasn't saved.
    final areaHectares = (data['areaHectares'] as num?)?.toDouble();
    final spots = <FlSpot>[];
    final amountSpots = <FlSpot>[];
    for (var i = 0; i < harvests.length; i++) {
      final h = harvests[i] as Map<String, dynamic>;
      final amount = (h['amountTon'] as num?)?.toDouble();
      var perHa = (h['yieldTonPerHa'] as num?)?.toDouble();
      if (perHa == null &&
          amount != null &&
          areaHectares != null &&
          areaHectares > 0) {
        perHa = amount / areaHectares;
      }
      if (perHa != null) {
        spots.add(FlSpot(i.toDouble(), perHa));
      }
      if (amount != null) {
        amountSpots.add(FlSpot(i.toDouble(), amount));
      }
    }
    final showAmountFallback = spots.isEmpty && amountSpots.isNotEmpty;

    final sprays = (data['sprays'] as List?) ?? [];
    final nextSprayDisplay = _formatDate(data['nextSprayDueAt']);
    final qualityLogs = ((data['qualityLogs'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

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
        Text(
            showAmountFallback
                ? context.tr('Harvest Amount (ton)')
                : context.tr('Harvest Yield (t/ha)'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (spots.isEmpty && amountSpots.isEmpty)
          Text(context.tr('No data yet'))
        else ...[
          if (showAmountFallback) ...[
            Text(context.tr('Set crop area to see yield per hectare.'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: showAmountFallback ? amountSpots : spots,
                    color: Colors.indigo,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          decoration: InputDecoration(
            labelText: context.tr('Harvest amount (ton)'),
            // Cotton's yield threshold assumes raw seed cotton; ginned
            // lint weight is much lower and would read as a crop failure.
            helperText: data['cropType']?.toString().toLowerCase() == 'cotton'
                ? context.tr('Seed cotton weight (unginned), not lint.')
                : null,
          ),
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
        const SizedBox(height: 24),
        Text(context.tr('Quality History'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (qualityLogs.isEmpty)
          Text(context.tr('No data yet'))
        else
          ...qualityLogs.reversed.take(5).map((e) => ListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text(_formatQualityLog(e)),
                subtitle: Text(_formatDate(e['measuredAt'])),
              )),
        const SizedBox(height: 16),
        Text(context.tr('Log Quality'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _qualityProteinCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: context.tr('Protein (%) (optional)')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _qualityMoistureCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: context.tr('Moisture (%) (optional)')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _qualitySugarCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: context.tr('Sugar (%) (optional)')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _qualityOilCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: context.tr('Oil (%) (optional)')),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_qualityDate == null
                ? context.tr('Date: Today')
                : context.tr('Date: {value}', params: {
                    'value': _qualityDate!.toIso8601String().split('T').first
                  })),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  _pickDate((d) => setState(() => _qualityDate = d),
                      initial: _qualityDate),
              child: Text(context.tr('Pick Date')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitQuality,
          child: Text(context.tr('Save')),
        ),
      ],
    );
  }

  String _formatQualityLog(Map<String, dynamic> log) {
    final parts = <String>[];
    final protein = (log['proteinPercent'] as num?)?.toDouble();
    final moisture = (log['moisturePercent'] as num?)?.toDouble();
    final sugar = (log['sugarPercent'] as num?)?.toDouble();
    final oil = (log['oilPercent'] as num?)?.toDouble();
    if (protein != null) {
      parts.add('${context.tr('Protein')}: ${protein.toStringAsFixed(1)}%');
    }
    if (moisture != null) {
      parts.add('${context.tr('Moisture')}: ${moisture.toStringAsFixed(1)}%');
    }
    if (sugar != null) {
      parts.add('${context.tr('Sugar')}: ${sugar.toStringAsFixed(1)}%');
    }
    if (oil != null) {
      parts.add('${context.tr('Oil')}: ${oil.toStringAsFixed(1)}%');
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
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
            icon: const Icon(Icons.edit_outlined),
            tooltip: context.tr('Edit'),
            onPressed: detail == null ? null : _openEditForm,
          ),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: Text(context.tr('Back to list')),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  ),
                )
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
                          if (_isCrop)
                            _buildCropSection(detail!)
                          else if (_isDairy)
                            _buildMilkSection(detail!)
                          else if (_isLayer)
                            _buildEggSection(detail!)
                          else if (_isBee)
                            _buildHoneySection(detail!),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }
}

// ----------------- Edit Item Form (Crop | Livestock) -----------------
class _EditItemForm extends StatefulWidget {
  final String id;
  final bool isCrop;
  final Map<String, dynamic> data;

  const _EditItemForm({
    required this.id,
    required this.isCrop,
    required this.data,
  });

  @override
  State<_EditItemForm> createState() => _EditItemFormState();
}

class _EditItemFormState extends State<_EditItemForm> {
  late final _specificTypeCtrl = TextEditingController(
    text: (widget.data['specificType'] ?? '').toString(),
  );
  late final _notesCtrl = TextEditingController(
    text: (widget.data['notes'] ?? '').toString(),
  );

  // Crop-only controllers.
  late final _areaCtrl = TextEditingController(
    text: (widget.data['areaHectares'] ?? '').toString(),
  );
  late final _pesticideCtrl = TextEditingController(
    text: (widget.data['pesticide'] ?? '').toString(),
  );
  late final _plantingCtrl = TextEditingController(
    text: _dateOnly(widget.data['plantingDate']),
  );
  late final _harvestCtrl = TextEditingController(
    text: _dateOnly(widget.data['harvestDate']),
  );

  // Livestock-only controllers.
  late final _weightCtrl = TextEditingController(
    text: (widget.data['weightKg'] ?? '').toString(),
  );
  late final _birthDateCtrl = TextEditingController(
    text: _dateOnly(widget.data['birthDate']),
  );

  late final TypeSpecificFieldsController _typeSpecific =
      TypeSpecificFieldsController(
    widget.data['typeSpecific'] is Map
        ? Map<String, dynamic>.from(widget.data['typeSpecific'] as Map)
        : null,
  );

  bool _saving = false;

  static String _dateOnly(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    return str.contains('T') ? str.split('T').first : str;
  }

  TypeFieldsConfig? _typeConfig() {
    final typeKey = widget.isCrop
        ? widget.data['cropType']?.toString()
        : (widget.data['species'] ?? widget.data['animalType'])?.toString();
    if (typeKey == null || typeKey.trim().isEmpty) return null;
    return widget.isCrop ? getCropFields(typeKey) : getLivestockFields(typeKey);
  }

  @override
  void dispose() {
    _specificTypeCtrl.dispose();
    _notesCtrl.dispose();
    _areaCtrl.dispose();
    _pesticideCtrl.dispose();
    _plantingCtrl.dispose();
    _harvestCtrl.dispose();
    _weightCtrl.dispose();
    _birthDateCtrl.dispose();
    _typeSpecific.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(ctrl.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => ctrl.text = picked.toIso8601String().split('T').first);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final typeSpecificPayload = _typeSpecific.collect(_typeConfig());
      final specificType = _specificTypeCtrl.text.trim();
      final notes = _notesCtrl.text.trim();

      if (widget.isCrop) {
        await ApiService.updateCrop(
          widget.id,
          fields: {
            'specificType': specificType.isEmpty ? null : specificType,
            'notes': notes.isEmpty ? null : notes,
            'area': _areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim(),
            'pesticide':
                _pesticideCtrl.text.trim().isEmpty ? null : _pesticideCtrl.text.trim(),
            'plantingDate':
                _plantingCtrl.text.trim().isEmpty ? null : _plantingCtrl.text.trim(),
            'harvestDate':
                _harvestCtrl.text.trim().isEmpty ? null : _harvestCtrl.text.trim(),
          },
          typeSpecific: typeSpecificPayload.isEmpty ? null : typeSpecificPayload,
        );
      } else {
        await ApiService.updateLivestock(
          widget.id,
          fields: {
            'specificType': specificType.isEmpty ? null : specificType,
            'notes': notes.isEmpty ? null : notes,
            'weight': _weightCtrl.text.trim().isEmpty ? null : _weightCtrl.text.trim(),
            'birthDate':
                _birthDateCtrl.text.trim().isEmpty ? null : _birthDateCtrl.text.trim(),
          },
          typeSpecific: typeSpecificPayload.isEmpty ? null : typeSpecificPayload,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Saved'))),
      );
    } catch (e) {
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Edit Item'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _specificTypeCtrl,
            decoration:
                InputDecoration(labelText: context.tr('Specific type (optional)')),
          ),
          const SizedBox(height: 8),
          if (widget.isCrop) ...[
            TextFormField(
              controller: _areaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('Area (ha)'),
                hintText: 'e.g. 2.5',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _plantingCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: context.tr('Planting date'),
                hintText: 'YYYY-MM-DD',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(_plantingCtrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _harvestCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: context.tr('Harvest date (optional)'),
                hintText: 'YYYY-MM-DD',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(_harvestCtrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pesticideCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Pesticide (optional)'),
                hintText: 'e.g. Fungicide',
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _birthDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: context.tr('Birth date (optional)'),
                hintText: 'YYYY-MM-DD',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(_birthDateCtrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('Weight (kg)'),
                hintText: 'e.g. 250',
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(labelText: context.tr('Notes (optional)')),
          ),
          if (cfg != null) ...[
            const SizedBox(height: 16),
            Text(
              context.tr('Type Specific Details'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._typeSpecific.buildFields(context, cfg, () => setState(() {})),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('Save')),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
