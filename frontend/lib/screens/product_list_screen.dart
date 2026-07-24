import 'package:flutter/material.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import '../services/api_service.dart';
import '../widgets/bottom_navigation.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selector.dart';
import 'product_detail_screen.dart';
import '../data/type_fields.dart';
import '../widgets/type_specific_fields.dart';

// Lists all products and supports quick add/edit.
class ProductListScreen extends StatefulWidget {
  final String userId;
  final String? focusName;
  const ProductListScreen({
    super.key,
    required this.userId,
    this.focusName,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<dynamic> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.listProductsCombined(); // crops + livestock
      final filtered = (widget.focusName == null || widget.focusName!.trim().isEmpty)
          ? list
          : list.where((e) {
              final m = _asMap(e);
              final title = (m['cropType'] ?? m['name'] ?? m['species'] ?? '').toString().toLowerCase();
              return title.contains(widget.focusName!.toLowerCase());
            }).toList();
      if (!mounted) return;
      setState(() => items = filtered);
    } catch (e) {
      if (mounted) {
        await ApiService.showAlert(
          context,
          context.tr('Load error: {message}', params: {'message': '$e'}),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  // The API stores birthDate, not an age field, so age is derived for
  // display.
  String? _ageInMonths(dynamic birthDate) {
    if (birthDate == null) return null;
    final parsed = DateTime.tryParse(birthDate.toString());
    if (parsed == null) return null;
    final months = DateTime.now().difference(parsed).inDays ~/ 30;
    return months.toString();
  }

  String? _formatHighlightValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    if (value is num) {
      final isInt = value == value.roundToDouble();
      return isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    }
    final str = value.toString();
    if (str.isEmpty) return null;
    return str;
  }

  (String title, String subtitle) _present(
      BuildContext context, Map<String, dynamic> it) {
    // Title precedence: species > name > cropType > id.
    String title =
        (it['species'] ?? it['name'] ?? it['cropType'] ?? it['id'] ?? 'Item')
            .toString();
    final specific =
        (it['specificType'] ?? it['breed'] ?? '').toString().trim();
    if (specific.isNotEmpty) {
      title = '$title ($specific)';
    }

    final highlightsRaw = it['trackingHighlights'];
    String? highlightSubtitle;
    if (highlightsRaw is List && highlightsRaw.isNotEmpty) {
      final items = <String>[];
      for (final entry in highlightsRaw) {
        if (entry is Map) {
          final labelKey = entry['labelKey']?.toString();
          final valueText = _formatHighlightValue(entry['value']);
          if (labelKey != null && valueText != null) {
            items.add('${context.tr(labelKey)}: $valueText');
          }
        }
        if (items.length >= 2) break;
      }
      if (items.isNotEmpty) {
        highlightSubtitle = items.join(' • ');
      }
    }

    if (highlightSubtitle != null) {
      return (title, highlightSubtitle);
    }

    // Subtitle fallback for legacy fields.
    final weight = it['weightKg'] ?? it['weight'];
    final age = _ageInMonths(it['birthDate']);
    final area = it['areaHectares'] ?? it['area'];
    final nextSpray = it['nextSprayDueAt'] ?? it['nextSpray'];
    String subtitle;
    if (weight != null || age != null) {
      subtitle = context.tr(
        'Weight: {weight} · Age: {age}',
        params: {
          'weight': (weight ?? '—').toString(),
          'age': (age ?? '—').toString(),
        },
      );
    } else if (area != null || nextSpray != null) {
      subtitle = context.tr(
        'Area: {area} · Next spray: {spray}',
        params: {
          'area': (area ?? '—').toString(),
          'spray': (nextSpray ?? '—').toString(),
        },
      );
    } else {
      final notes = (it['notes'] ?? it['summary'] ?? '').toString();
      subtitle = notes.isNotEmpty ? notes : '—';
    }
    return (title, subtitle);
  }

  Future<void> _openAddForm() async {
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
          left: 16, right: 16, top: 16,
        ),
        child: const _AddItemForm(),
      ),
    );
    if (result == true) {
      setState(() => loading = true);
      await _load();
    }
  }

  void _openDetail(Map<String, dynamic> it) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: it),
      ),
    ).then((value) async {
      if (value == true) {
        setState(() => loading = true);
        await _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = loading
        ? const Center(child: CircularProgressIndicator())
        : (items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inbox, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('No items found'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(context.tr('Try adding a new crop or animal.')),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final it = _asMap(items[i]);
                  final p = _present(context, it);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2,
                          color: AppTheme.primary),
                      title: Text(p.$1),
                      subtitle: Text(p.$2,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _openDetail(it),
                      trailing: TextButton(
                        child: Text(context.tr('More Info')),
                        onPressed: () => _openDetail(it),
                      ),
                    ),
                  );
                },
              ));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Your Animals or Products')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userId: widget.userId,
                ),
              ),
            );
          }, // Back to dashboard.
        ),
        actions: const [LanguageSelector()],
      ),
      body: body,
      bottomNavigationBar: BottomNavigation(
        currentIndex: 0,
        userId: widget.userId,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ----------------- Add Item Form (Crop | Livestock) -----------------
class _AddItemForm extends StatefulWidget {
  const _AddItemForm();

  @override
  State<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends State<_AddItemForm> {
  final _formKey = GlobalKey<FormState>();

  // Current product category.
  String _type = 'crop'; // 'crop' | 'livestock'

  // Selected types.
  String? _selectedCropType;
  String? _selectedLivestockType;

  // 10 crop types.
  final List<Map<String, String>> _cropTypes = [
    {'value': 'wheat', 'label': 'Buğday'},
    {'value': 'sugar beet', 'label': 'Pancar'},
    {'value': 'corn', 'label': 'Mısır'},
    {'value': 'cotton', 'label': 'Pamuk'},
    {'value': 'sunflower', 'label': 'Ayçiçeği'},
    {'value': 'tomato', 'label': 'Domates'},
    {'value': 'grape', 'label': 'Üzüm'},
    {'value': 'olive', 'label': 'Zeytin'},
    {'value': 'rice', 'label': 'Pirinç'},
    {'value': 'soybean', 'label': 'Soya'},
  ];

  // 10 livestock types.
  final List<Map<String, String>> _livestockTypes = [
    {'value': 'cow', 'label': 'İnek'},
    {'value': 'sheep', 'label': 'Koyun'},
    {'value': 'goat', 'label': 'Keçi'},
    {'value': 'chicken', 'label': 'Tavuk'},
    {'value': 'duck', 'label': 'Ördek'},
    {'value': 'turkey', 'label': 'Hindi'},
    {'value': 'bee', 'label': 'Arı'},
    {'value': 'fish', 'label': 'Balık'},
    {'value': 'buffalo', 'label': 'Manda'},
    {'value': 'camel', 'label': 'Deve'},
  ];

  // Crop form controllers.
  final _cropTypeCtrl = TextEditingController();
  final _plantingCtrl = TextEditingController();
  final _harvestCtrl = TextEditingController();
  final _notesCropCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _pesticideCtrl = TextEditingController();

  // Livestock form controllers.
  final _speciesCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesAnimalCtrl = TextEditingController();
  final _specificTypeCtrl = TextEditingController();
  final _typeSpecific = TypeSpecificFieldsController();

  @override
  void dispose() {
    _cropTypeCtrl.dispose();
    _plantingCtrl.dispose();
    _harvestCtrl.dispose();
    _notesCropCtrl.dispose();
    _areaCtrl.dispose();
    _pesticideCtrl.dispose();
    _speciesCtrl.dispose();
    _birthDateCtrl.dispose();
    _weightCtrl.dispose();
    _notesAnimalCtrl.dispose();
    _specificTypeCtrl.dispose();
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
      ctrl.text = picked.toIso8601String().split('T').first;
    }
  }

  TypeFieldsConfig? _currentTypeConfig() {
    final selected =
        _type == 'crop' ? _selectedCropType : _selectedLivestockType;
    if (selected == null || selected.trim().isEmpty) return null;
    return _type == 'crop'
        ? getCropFields(selected)
        : getLivestockFields(selected);
  }

  Widget _buildTypeSpecificSection() {
    final cfg = _currentTypeConfig();
    if (cfg == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          context.tr('Type Specific Details'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._typeSpecific.buildFields(context, cfg, () => setState(() {})),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final specificTypeValue =
          _specificTypeCtrl.text.trim().isEmpty ? null : _specificTypeCtrl.text.trim();
      final typeSpecificPayload = _typeSpecific.collect(_currentTypeConfig());

      if (_type == 'crop') {
        await ApiService.addProduct({
          'type': 'crop',
          'crop_type': _cropTypeCtrl.text.trim(),
          'planting_date': _plantingCtrl.text.trim(),
          'harvest_date': _harvestCtrl.text.trim(),
          'notes':
              _notesCropCtrl.text.trim().isEmpty ? null : _notesCropCtrl.text.trim(),
          'area': _areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim(),
          'pesticide':
              _pesticideCtrl.text.trim().isEmpty ? null : _pesticideCtrl.text.trim(),
          'specificType': specificTypeValue,
          'typeSpecific':
              typeSpecificPayload.isEmpty ? null : typeSpecificPayload,
        });
      } else {
        await ApiService.addProduct({
          'type': 'livestock',
          'species': _speciesCtrl.text.trim(),
          'birthDate':
              _birthDateCtrl.text.trim().isEmpty ? null : _birthDateCtrl.text.trim(),
          'weight': _weightCtrl.text.trim().isEmpty ? null : _weightCtrl.text.trim(),
          'notes': _notesAnimalCtrl.text.trim().isEmpty ? null : _notesAnimalCtrl.text.trim(),
          'specificType': specificTypeValue,
          'typeSpecific':
              typeSpecificPayload.isEmpty ? null : typeSpecificPayload,
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true); // Success.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Saved'))),
      );
    } catch (e) {
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Save error: {message}', params: {'message': '$e'}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCrop = _type == 'crop';

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  context.tr('Add Item'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _type,
                  items: [
                    DropdownMenuItem(
                        value: 'crop', child: Text(context.tr('Crop'))),
                    DropdownMenuItem(
                        value: 'livestock',
                        child: Text(context.tr('Livestock'))),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _type = v;
                      _selectedCropType = null;
                      _selectedLivestockType = null;
                      _cropTypeCtrl.clear();
                      _speciesCtrl.clear();
                      _specificTypeCtrl.clear();
                      _typeSpecific.reset();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (isCrop) ...[
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: context.tr('Crop type'),
                  border: const OutlineInputBorder(),
                ),
                items: _cropTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCropType = value;
                    _cropTypeCtrl.text = value ?? '';
                    _typeSpecific.reset();
                  });
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _specificTypeCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Specific type (optional)'),
                ),
              ),
              const SizedBox(height: 8),
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
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _pickDate(_plantingCtrl)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _harvestCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: context.tr('Harvest date (optional)'),
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _pickDate(_harvestCtrl)),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCropCtrl,
                minLines: 1,
                maxLines: 3,
                decoration:
                    InputDecoration(labelText: context.tr('Notes (optional)')),
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
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: context.tr('Species'),
                  border: const OutlineInputBorder(),
                ),
                items: _livestockTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLivestockType = value;
                    _speciesCtrl.text = value ?? '';
                    _typeSpecific.reset();
                  });
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _specificTypeCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Specific type (optional)'),
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesAnimalCtrl,
                minLines: 1,
                maxLines: 3,
                decoration:
                    InputDecoration(labelText: context.tr('Notes (optional)')),
              ),
            ],

            _buildTypeSpecificSection(),

            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(context.tr('Save')),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
