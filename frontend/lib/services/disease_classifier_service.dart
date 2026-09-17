import 'package:image_picker/image_picker.dart' show XFile;

import 'disease_classifier_web.dart'
    if (dart.library.io) 'disease_classifier_native.dart' as impl;

class DiagnosisResult {
  final String label;
  final double confidence;

  const DiagnosisResult({required this.label, required this.confidence});
}

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
  /// Returns null if this platform doesn't support on-device inference,
  /// the model asset isn't available yet (not trained/shipped), or the
  /// photo couldn't be classified for any other reason.
  static Future<DiagnosisResult?> classify(XFile photo, DiagnosisModel model) {
    return impl.classify(photo, model);
  }
}
