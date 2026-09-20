import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'disease_classifier_service.dart' show DiagnosisResult, DiagnosisModel;

const _inputSize = 224;

final Map<DiagnosisModel, Interpreter> _interpreters = {};
final Map<DiagnosisModel, List<String>> _labels = {};

Future<bool> _ensureLoaded(DiagnosisModel model) async {
  if (_interpreters.containsKey(model)) return true;
  try {
    final interpreter = await Interpreter.fromAsset(model.modelAsset);
    final labelsText = await rootBundle.loadString(model.labelsAsset);
    final labels = labelsText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    _interpreters[model] = interpreter;
    _labels[model] = labels;
    return true;
  } catch (e) {
    debugPrint('[DiseaseClassifier] failed to load $model: $e');
    return false;
  }
}

/// Real on-device inference (Android/iOS/desktop - tflite_flutter uses
/// dart:ffi, which isn't available on web; see disease_classifier_web.dart
/// for that platform's stub).
Future<DiagnosisResult?> classify(
  XFile photo,
  DiagnosisModel model, {
  String? labelPrefix,
}) async {
  if (!await _ensureLoaded(model)) return null;
  final interpreter = _interpreters[model]!;
  final labels = _labels[model]!;

  try {
    final bytes = await photo.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    // Bilinear, like tf.image.resize in the training notebooks - copyResize
    // defaults to nearest-neighbour, which shifts confidences on real photos.
    final resized = img.copyResize(
      decoded,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
        }),
      ),
    ];
    final output = [List.filled(labels.length, 0.0)];

    interpreter.run(input, output);

    final scores = output[0];
    final candidates = [
      for (var i = 0; i < labels.length; i++)
        if (labelPrefix == null || labels[i].startsWith(labelPrefix)) i,
    ];
    if (candidates.isEmpty) return null;

    var bestIndex = candidates.first;
    var total = 0.0;
    for (final i in candidates) {
      total += scores[i];
      if (scores[i] > scores[bestIndex]) bestIndex = i;
    }
    final confidence = total > 0 ? scores[bestIndex] / total : 0.0;
    return DiagnosisResult(label: labels[bestIndex], confidence: confidence);
  } catch (e) {
    debugPrint('[DiseaseClassifier] classify($model) failed: $e');
    return null;
  }
}
