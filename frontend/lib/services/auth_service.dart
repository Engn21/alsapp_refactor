import '../api/api_client.dart';

class CropsService {
  final Api _api = Api();

  Future<List<dynamic>> list() => _api.listCrops();

  Future<void> create({
    required String cropType,
    required DateTime plantingDate,
    DateTime? harvestDate,
    String? notes,
  }) =>
      _api.createCrop(
        cropType: cropType,
        plantingDate: plantingDate,
        harvestDate: harvestDate,
        notes: notes,
      );
}
   



