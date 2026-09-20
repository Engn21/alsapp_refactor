import 'package:image_picker/image_picker.dart' show XFile;

import 'disease_classifier_service.dart' show DiagnosisResult, DiagnosisModel;

/// tflite_flutter is FFI-based and unavailable on web - the photo diagnosis
/// feature is native-platform only (Android/iOS/desktop) for now.
Future<DiagnosisResult?> classify(
  XFile photo,
  DiagnosisModel model, {
  String? labelPrefix,
}) async =>
    null;
