import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart' show XFile;

import 'disease_classifier_web.dart'
    if (dart.library.io) 'disease_classifier_native.dart' as impl;

class DiagnosisResult {
  final String label;
  final double confidence;

  const DiagnosisResult({required this.label, required this.confidence});

  /// PlantVillage-style label made readable, e.g. "Tomato - Late blight".
  String get prettyLabel =>
      label.replaceAll('___', ' - ').replaceAll('_', ' ').trim();

  String get confidencePercent =>
      (confidence * 100).clamp(0, 100).toStringAsFixed(0);
}

/// Crop types (the app's `cropType` values) the plant model *can* be trained
/// to diagnose, mapped to their label prefix in the model. Whether a crop is
/// actually offered depends on the shipped model - see
/// [DiseaseClassifierService.availablePlantCrops] - because a crop the model
/// never saw (wheat, olive, cotton, ... with the PlantVillage-only model)
/// would get a confident answer about the wrong species. Soybean is left out
/// on purpose: PlantVillage has only a "healthy" class for it, so the model
/// could never report a disease.
///
/// Wheat and olive come from the extra field-photo datasets in
/// `ml/plant_disease_train.ipynb`; they switch on by themselves once a model
/// trained with them (labels `Wheat___...`, `Olive___...`) is dropped in.
const Map<String, String> plantLabelPrefixByCrop = {
  'wheat': 'Wheat___',
  'olive': 'Olive___',
  'corn': 'Corn_(maize)___',
  'tomato': 'Tomato___',
  'grape': 'Grape___',
};

enum DiagnosisModel {
  plant('assets/models/plant_disease.tflite', 'assets/models/plant_labels.txt'),
  cattle('assets/models/cattle_disease.tflite', 'assets/models/cattle_labels.txt');

  final String modelAsset;
  final String labelsAsset;
  const DiagnosisModel(this.modelAsset, this.labelsAsset);
}

/// Runs the on-device MobileNetV2 classifiers trained via the notebooks in
/// `ml/` - photos never leave the device. Models are trained externally
/// (Google Colab, see ml/README.md) and shipped as Flutter assets.
///
/// The real implementation (disease_classifier_native.dart) only compiles
/// on platforms with dart:io, since tflite_flutter is FFI-based; on web,
/// disease_classifier_web.dart is used instead and always reports the
/// feature as unavailable, via the conditional import above.
class DiseaseClassifierService {
  static Set<String>? _availableCrops;

  /// The app crop types (keys of [plantLabelPrefixByCrop]) the *shipped* plant
  /// model has labels for. Read from the labels asset, so replacing the model
  /// files is all it takes to add a crop.
  static Future<Set<String>> availablePlantCrops() async {
    final cached = _availableCrops;
    if (cached != null) return cached;
    try {
      final text = await rootBundle.loadString(DiagnosisModel.plant.labelsAsset);
      final prefixes = <String>{
        for (final line in text.split('\n'))
          if (line.contains('___')) '${line.trim().split('___').first}___',
      };
      return _availableCrops = {
        for (final e in plantLabelPrefixByCrop.entries)
          if (prefixes.contains(e.value)) e.key,
      };
    } catch (e) {
      debugPrint('[DiseaseClassifier] could not read plant labels: $e');
      return <String>{};
    }
  }

  /// Returns null if this platform doesn't support on-device inference,
  /// the model asset isn't available yet (not trained/shipped), or the
  /// photo couldn't be classified for any other reason.
  ///
  /// [labelPrefix] restricts the answer to labels starting with it (e.g.
  /// `Tomato___`) and renormalizes the confidence over just those - the
  /// app already knows which crop the photo is of, so the model shouldn't be
  /// free to answer with another species' disease.
  static Future<DiagnosisResult?> classify(
    XFile photo,
    DiagnosisModel model, {
    String? labelPrefix,
  }) {
    return impl.classify(photo, model, labelPrefix: labelPrefix);
  }
}
