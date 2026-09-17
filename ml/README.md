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

- **`plant_disease_train.ipynb`** - PlantVillage dataset (38 classes, 14
  crop species, ~54k images, auto-downloaded via `tensorflow_datasets`,
  no auth needed). Just open in Colab, set the runtime to a T4 GPU, and
  run all cells top to bottom.
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

## Sanity-checking accuracy

Both notebooks print a held-out classification report (per-class
precision/recall/f1) before exporting - check it's reasonable before
shipping. The cattle model in particular is trained on a small dataset
(~3.2k images across 3 classes), so don't expect PlantVillage-level
accuracy from it yet.
