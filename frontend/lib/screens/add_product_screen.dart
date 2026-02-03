import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Form screen for creating a crop or livestock product.
class AddProductScreen extends StatefulWidget {
  final String userId;
  final String password;

  const AddProductScreen({super.key, required this.userId, required this.password});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // UI state for the selected product category.
  String productType = 'crop';
  final cropTypeController = TextEditingController();
  final plantingDateController = TextEditingController();
  final harvestDateController = TextEditingController();
  final animalTypeController = TextEditingController();
  final breedController = TextEditingController();
  final birthDateController = TextEditingController();

  String responseMessage = '';
  bool isLoading = false;

  // Sends the payload to the backend and updates UI state.
  void submit() async {
    setState(() { isLoading = true; responseMessage = ''; });

    final data = <String, dynamic>{
      'id': widget.userId,
      'password': widget.password,
      'type': productType,
    };

    if (productType == 'crop') {
      data.addAll({
        'crop_type': cropTypeController.text,
        'planting_date': plantingDateController.text,
        'harvest_date': harvestDateController.text,
      });
    } else {
      data.addAll({
        'animal_type': animalTypeController.text,
        'breed': breedController.text,
        'birthdate': birthDateController.text,
      });
    }

    try {
      await ApiService.addProduct(data);
      setState(() => responseMessage = '✅ Ürün başarıyla eklendi!');
    } catch (e) {
      setState(() => responseMessage = '❌ Hata: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Inputs for crop-specific fields.
  Widget cropForm() => Column(
        children: [
          TextField(controller: cropTypeController, decoration: const InputDecoration(labelText: 'Ürün Türü')),
          TextField(controller: plantingDateController, decoration: const InputDecoration(labelText: 'Ekim Tarihi (YYYY-MM-DD)')),
          TextField(controller: harvestDateController, decoration: const InputDecoration(labelText: 'Hasat Tarihi (YYYY-MM-DD)')),
        ],
      );

  // Inputs for livestock-specific fields.
  Widget livestockForm() => Column(
        children: [
          TextField(controller: animalTypeController, decoration: const InputDecoration(labelText: 'Hayvan Türü')),
          TextField(controller: breedController, decoration: const InputDecoration(labelText: 'Irk')),
          TextField(controller: birthDateController, decoration: const InputDecoration(labelText: 'Doğum Tarihi (YYYY-MM-DD)')),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ürün Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            DropdownButton<String>(
              value: productType,
              onChanged: (value) => setState(() => productType = value!),
              items: const [
                DropdownMenuItem(value: 'crop', child: Text('Tarım Ürünü')),
                DropdownMenuItem(value: 'livestock', child: Text('Hayvancılık')),
              ],
            ),
            const SizedBox(height: 16),
            productType == 'crop' ? cropForm() : livestockForm(),
            const SizedBox(height: 24),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(onPressed: submit, child: const Text('Ekle')),
            const SizedBox(height: 16),
            Text(responseMessage, style: const TextStyle(color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}
