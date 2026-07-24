import 'package:flutter/material.dart';
import '../data/type_fields.dart';
import '../l10n/app_localizations.dart';

/// Field rendering, auto-next-date computation, and value collection for a
/// [TypeFieldsConfig]. Shared by the add-item form and the edit form so
/// their handling of choice/date/number/text fields can't drift apart.
class TypeSpecificFieldsController {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> values;

  TypeSpecificFieldsController([Map<String, dynamic>? initialValues])
      : values = Map<String, dynamic>.from(initialValues ?? {});

  void reset() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    values.clear();
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  TextEditingController _controllerFor(String key) {
    final existing = _controllers[key];
    final expected = (values[key] ?? '').toString();
    if (existing != null) {
      if (existing.text != expected) existing.text = expected;
      return existing;
    }
    final controller = TextEditingController(text: expected);
    controller.addListener(() => values[key] = controller.text);
    _controllers[key] = controller;
    return controller;
  }

  TypeFieldDefinition? _findField(TypeFieldsConfig cfg, String key) {
    for (final field in cfg.fields) {
      if (field.key == key) return field;
    }
    return null;
  }

  void _maybePopulateAutoNext(
    TypeFieldsConfig cfg,
    TypeFieldDefinition field,
    String dateValue,
  ) {
    final auto = field.autoNext;
    if (auto == null || dateValue.isEmpty) return;
    final targetField = _findField(cfg, auto.key);
    if (targetField == null) return;

    final existing = values[targetField.key]?.toString().trim();
    if (existing != null && existing.isNotEmpty) return;

    final parsed = DateTime.tryParse(dateValue);
    if (parsed == null) return;
    final formatted = parsed
        .add(Duration(days: auto.intervalDays))
        .toIso8601String()
        .split('T')
        .first;
    values[targetField.key] = formatted;
    final controller = _controllers[targetField.key];
    if (controller != null && controller.text != formatted) {
      controller.text = formatted;
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    TypeFieldsConfig cfg,
    TypeFieldDefinition field,
    VoidCallback onChanged,
  ) async {
    final now = DateTime.now();
    final currentValue = values[field.key]?.toString();
    final initialDate =
        currentValue != null ? DateTime.tryParse(currentValue) ?? now : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    final formatted = picked.toIso8601String().split('T').first;
    values[field.key] = formatted;
    final controller = _controllerFor(field.key);
    if (controller.text != formatted) controller.text = formatted;
    _maybePopulateAutoNext(cfg, field, formatted);
    onChanged();
  }

  /// Builds the input widgets for every field in [cfg]. [onChanged] is
  /// called after any field value changes so the caller can rebuild.
  List<Widget> buildFields(
    BuildContext context,
    TypeFieldsConfig cfg,
    VoidCallback onChanged,
  ) {
    final autoComputedTargets = <String>{
      for (final field in cfg.fields)
        if (field.autoNext != null) field.autoNext!.key,
    };

    return cfg.fields.map((field) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _buildField(context, cfg, field, autoComputedTargets, onChanged),
      );
    }).toList();
  }

  Widget _buildField(
    BuildContext context,
    TypeFieldsConfig cfg,
    TypeFieldDefinition field,
    Set<String> autoComputedTargets,
    VoidCallback onChanged,
  ) {
    final isAutoComputed = autoComputedTargets.contains(field.key);
    final label = context.tr(field.labelKey);
    final helper =
        isAutoComputed ? context.tr('field.autoComputedHint') : null;

    switch (field.type) {
      case FieldInputType.choice:
        final currentValue = values[field.key]?.toString();
        final choices = field.choices ?? [];
        return DropdownButtonFormField<String>(
          value: currentValue != null && currentValue.isNotEmpty
              ? currentValue
              : null,
          decoration: InputDecoration(labelText: label, helperText: helper),
          items: choices
              .map((choice) => DropdownMenuItem<String>(
                    value: choice,
                    child: Text(context.tr('choice.${field.key}.$choice')),
                  ))
              .toList(),
          onChanged: (val) {
            values[field.key] = val ?? '';
            onChanged();
          },
        );
      case FieldInputType.date:
        final controller = _controllerFor(field.key);
        return TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _pickDate(context, cfg, field, onChanged),
            ),
          ),
          onTap: () => _pickDate(context, cfg, field, onChanged),
        );
      case FieldInputType.number:
      case FieldInputType.integer:
        final controller = _controllerFor(field.key);
        return TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, helperText: helper),
          onChanged: (value) {
            values[field.key] = value;
            onChanged();
          },
        );
      case FieldInputType.text:
        final controller = _controllerFor(field.key);
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label, helperText: helper),
        );
    }
  }

  /// Collects the current values into a payload ready for the API,
  /// coercing numbers/integers and dropping empty entries.
  Map<String, dynamic> collect(TypeFieldsConfig? cfg) {
    if (cfg == null) return {};
    final result = <String, dynamic>{};
    for (final field in cfg.fields) {
      if (!values.containsKey(field.key)) continue;
      final raw = values[field.key];
      if (raw == null) continue;
      String asString;
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
          result[field.key] = double.tryParse(asString) ?? asString;
          break;
        case FieldInputType.integer:
          final parsedInt = int.tryParse(asString);
          if (parsedInt != null) {
            result[field.key] = parsedInt;
          } else {
            final parsedDouble = double.tryParse(asString);
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
}
