import 'package:flutter/material.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import '../services/api_service.dart';
import '../widgets/bottom_navigation.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selector.dart';
import 'product_detail_screen.dart';
import '../data/type_fields.dart';

// Lists all products and supports quick add/edit.
class ProductListScreen extends StatefulWidget {
  final String userId;
  final String password;
  final String? focusName;
  const ProductListScreen({
    super.key,
    required this.userId,
    required this.password,
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
    final weight = it['weight'];
    final age = it['age'];
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
                  password: widget.password,
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
        password: widget.password,
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
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _tagIdCtrl = TextEditingController();
  final _notesAnimalCtrl = TextEditingController();
  final _specificTypeCtrl = TextEditingController();
  final Map<String, TextEditingController> _typeFieldControllers = {};
  final Map<String, dynamic> _typeSpecificValues = {};

  @override
  void dispose() {
    _cropTypeCtrl.dispose();
    _plantingCtrl.dispose();
    _harvestCtrl.dispose();
    _notesCropCtrl.dispose();
    _areaCtrl.dispose();
    _pesticideCtrl.dispose();
    _speciesCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _tagIdCtrl.dispose();
    _notesAnimalCtrl.dispose();
    _specificTypeCtrl.dispose();
    for (final controller in _typeFieldControllers.values) {
      controller.dispose();
    }
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

  void _resetTypeSpecific() {
    for (final controller in _typeFieldControllers.values) {
      controller.dispose();
    }
    _typeFieldControllers.clear();
    _typeSpecificValues.clear();
  }

  TypeFieldsConfig? _currentTypeConfig() {
    final selected =
        _type == 'crop' ? _selectedCropType : _selectedLivestockType;
    if (selected == null || selected.trim().isEmpty) return null;
    return _type == 'crop'
        ? getCropFields(selected)
        : getLivestockFields(selected);
  }

  TextEditingController _controllerForField(String key) {
    if (_typeFieldControllers.containsKey(key)) {
      final controller = _typeFieldControllers[key]!;
      final expected = (_typeSpecificValues[key] ?? '').toString();
      if (controller.text != expected) {
        controller.text = expected;
      }
      return controller;
    }
    final controller = TextEditingController(
      text: (_typeSpecificValues[key] ?? '').toString(),
    );
    controller.addListener(() {
      _typeSpecificValues[key] = controller.text;
    });
    _typeFieldControllers[key] = controller;
    return controller;
  }

  TypeFieldDefinition? _findTypeField(String key) {
    final cfg = _currentTypeConfig();
    if (cfg == null) return null;
    for (final field in cfg.fields) {
      if (field.key == key) return field;
    }
    return null;
  }

  void _maybePopulateAutoNext(
    TypeFieldDefinition field,
    String dateValue,
  ) {
    final auto = field.autoNext;
    if (auto == null || dateValue.isEmpty) return;
    final cfg = _currentTypeConfig();
    if (cfg == null) return;
    final targetField = _findTypeField(auto.key);
    if (targetField == null) return;

    final existing = _typeSpecificValues[targetField.key]?.toString().trim();
    if (existing != null && existing.isNotEmpty) return;

    final parsed = DateTime.tryParse(dateValue);
    if (parsed == null) return;
    final computed =
        parsed.add(Duration(days: auto.intervalDays)).toIso8601String();
    final formatted = computed.split('T').first;
    _typeSpecificValues[targetField.key] = formatted;
    final controller = _typeFieldControllers[targetField.key];
    if (controller != null && controller.text != formatted) {
      controller.text = formatted;
    }
  }

  Future<void> _pickTypeSpecificDate(TypeFieldDefinition field) async {
    final now = DateTime.now();
    final currentValue = _typeSpecificValues[field.key]?.toString();
    DateTime initialDate =
        currentValue != null ? DateTime.tryParse(currentValue) ?? now : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      final formatted = picked.toIso8601String().split('T').first;
      setState(() {
        _typeSpecificValues[field.key] = formatted;
      });
      final controller = _controllerForField(field.key);
      if (controller.text != formatted) {
        controller.text = formatted;
      }
      _maybePopulateAutoNext(field, formatted);
    }
  }

  Map<String, dynamic> _collectTypeSpecific() {
    final cfg = _currentTypeConfig();
    if (cfg == null) return {};
    final result = <String, dynamic>{};
    for (final field in cfg.fields) {
      if (!_typeSpecificValues.containsKey(field.key)) continue;
      final raw = _typeSpecificValues[field.key];
      if (raw == null) continue;
      String? asString;
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;
        asString = trimmed;
      } else if (raw is DateTime) {
        asString = raw.toIso8601String().split('T').first;
      } else {
        asString = raw.toString();
        if (asString.trim().isEmpty) continue;
      }

      switch (field.type) {
        case FieldInputType.number:
          final parsedNum = double.tryParse(asString ?? '');
          result[field.key] = parsedNum ?? asString;
          break;
        case FieldInputType.integer:
          final parsedInt = int.tryParse(asString ?? '');
          if (parsedInt != null) {
            result[field.key] = parsedInt;
          } else {
            final parsedDouble = double.tryParse(asString ?? '');
            result[field.key] =
                parsedDouble != null ? parsedDouble.round() : asString;
          }
          break;
        default:
          result[field.key] = asString;
      }
    }
    return result;
  }

  Widget _buildTypeSpecificInput(
    TypeFieldDefinition field,
    Set<String> autoComputedTargets,
  ) {
    final isAutoComputed = autoComputedTargets.contains(field.key);
    final label = context.tr(field.labelKey);
    final helper = isAutoComputed
        ? context.tr('field.autoComputedHint')
        : null;

    switch (field.type) {
      case FieldInputType.choice:
        final currentValue = _typeSpecificValues[field.key]?.toString();
        final choices = field.choices ?? [];
        return DropdownButtonFormField<String>(
          value: currentValue != null && currentValue.isNotEmpty
              ? currentValue
              : null,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
          ),
          items: choices
              .map((choice) => DropdownMenuItem<String>(
                    value: choice,
                    child: Text(
                        context.tr('choice.${field.key}.$choice')),
                  ))
              .toList(),
          onChanged: (val) {
            setState(() {
              _typeSpecificValues[field.key] = val ?? '';
            });
          },
        );
      case FieldInputType.date:
        final controller = _controllerForField(field.key);
        return TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _pickTypeSpecificDate(field),
            ),
          ),
          onTap: () => _pickTypeSpecificDate(field),
        );
      case FieldInputType.number:
      case FieldInputType.integer:
        final controller = _controllerForField(field.key);
        return TextFormField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
          ),
          onChanged: (value) {
            setState(() {
              _typeSpecificValues[field.key] = value;
            });
          },
        );
      case FieldInputType.text:
      default:
        final controller = _controllerForField(field.key);
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
          ),
        );
    }
  }

  Widget _buildTypeSpecificSection() {
    final cfg = _currentTypeConfig();
    if (cfg == null) return const SizedBox.shrink();
    final autoComputedTargets = <String>{};
    for (final field in cfg.fields) {
      final auto = field.autoNext;
      if (auto != null) autoComputedTargets.add(auto.key);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          context.tr('Type Specific Details'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...cfg.fields.map(
          (field) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _buildTypeSpecificInput(field, autoComputedTargets),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final specificTypeValue =
          _specificTypeCtrl.text.trim().isEmpty ? null : _specificTypeCtrl.text.trim();
      final typeSpecificPayload = _collectTypeSpecific();

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
          'age': _ageCtrl.text.trim().isEmpty ? null : _ageCtrl.text.trim(),
          'weight': _weightCtrl.text.trim().isEmpty ? null : _weightCtrl.text.trim(),
          'tagId': _tagIdCtrl.text.trim().isEmpty ? null : _tagIdCtrl.text.trim(),
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
                      _resetTypeSpecific();
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
                    _resetTypeSpecific();
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
                    _resetTypeSpecific();
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
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Age (months)'),
                  hintText: 'e.g. 12',
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
                controller: _tagIdCtrl,
                decoration:
                    InputDecoration(labelText: context.tr('Tag ID (optional)')),
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
