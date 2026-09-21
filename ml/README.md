# On-device disease diagnosis models

Two Colab notebooks that train small MobileNetV2 classifiers and export
them as `.tflite` files for the Flutter app's "Diagnose with photo"
feature (`frontend/lib/services/disease_classifier_native.dart`). This
runs entirely on-device - no API costs, works offline, photos never leave
the phone.

## Why Colab, not locally

Training needs TensorFlow + a few GB of dataset + checkpoints. Do this in
[Google Colab](https://colab.research.google.com) (free GPU, nothing
touches your machine's disk) rather than installing TensorFlow locally.

## Notebooks

- **`plant_disease_train.ipynb`** - PlantVillage (38 classes, 14 crop
  species, ~54k lab-style leaf photos, auto-downloaded via
  `tensorflow_datasets`) **plus wheat and olive field photos** from Kaggle
  (PlantVillage has neither, and they're this app's main crops). Labels are
  `<Crop>___<Condition>`. Open in Colab, set the runtime to a T4 GPU, add the
  same `KAGGLE_USERNAME` / `KAGGLE_KEY` secrets as for the cattle notebook,
  and run all cells top to bottom. The notebook prints what it found in each
  Kaggle dataset - check that table - and ends with a **per-crop accuracy**
  printout: look at the Wheat and Olive lines before shipping.
- **`cattle_disease_train.ipynb`** - a Kaggle cattle-disease dataset
  (healthy / lumpy skin disease / foot-and-mouth disease, ~3.2k images).
  Needs a free Kaggle API token (kaggle.com -> Settings -> API -> Create
  New Token) added as two Colab secrets, `KAGGLE_USERNAME` and
  `KAGGLE_KEY` - details are in the notebook's first cell.

  **v1 scope:** cattle only. Public datasets for sheep/goat/poultry/bee
  disease are too sparse/scattered right now - add them the same way
  later once better data exists.

## After training

Each notebook ends by downloading two files. Drop them straight into
`frontend/assets/models/`, overwriting the placeholders:

- `plant_disease.tflite`, `plant_labels.txt`
- `cattle_disease.tflite`, `cattle_labels.txt`

No code changes needed - the app already points at these exact paths
(`frontend/lib/services/disease_classifier_service.dart`). Just
`flutter run` again after replacing them.

Which crops the app offers photo diagnosis for is read from
`plant_labels.txt` itself: a crop (wheat, olive, tomato, corn, grape - see
`plantLabelPrefixByCrop`) appears in the chat and on its detail page only if
the labels contain its `<Crop>___` prefix. So the wheat/olive options switch
on the moment a model trained with them is dropped in, and stay off (with an
"Other crop" explanation in the chat) until then.

**Export as plain float32.** Don't set `converter.optimizations`: current
TensorFlow then emits `FULLY_CONNECTED` v12, which the TFLite runtimes
`tflite_flutter` bundles for macOS (2.11) and iOS (2.12) can't load
(`Unable to create interpreter`). Both notebooks already do this.

## Sanity-checking accuracy

Both notebooks print a held-out classification report (per-class
precision/recall/f1) before exporting - check it's reasonable before
shipping. The cattle model in particular is trained on a small dataset
(~3.2k images across 3 classes), so don't expect PlantVillage-level
accuracy from it yet.
