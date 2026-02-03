import 'package:dio/dio.dart';
import '../api/base_url.dart';

class TrackingActivity {
  final String id;
  final String type;
  final String crop;
  final DateTime date;
  final String notes;
  final bool done;

  TrackingActivity({
    required this.id,
    required this.type,
    required this.crop,
    required this.date,
    required this.notes,
    required this.done,
  });

  factory TrackingActivity.fromMap(Map<String, dynamic> m) => TrackingActivity(
        id: (m['id'] ?? '').toString(),
        type: (m['type'] ?? 'other').toString(),
        crop: (m['crop'] ?? '').toString(),
        date: DateTime.tryParse((m['date'] ?? '').toString()) ?? DateTime.now(),
        notes: (m['notes'] ?? '').toString(),
        done: (m['done'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'crop': crop,
        'date': date.toIso8601String(),
        'notes': notes,
        'done': done,
      };
}

class TrackingService {
  final Dio _dio = Dio(BaseOptions(baseUrl: resolveApiBase()));

  Future<List<TrackingActivity>> list() async {
    try {
      final r = await _dio.get('/tracking');
      if (r.statusCode == 200 && r.data is List) {
        return (r.data as List)
            .cast<Map<String, dynamic>>()
            .map(TrackingActivity.fromMap)
            .toList();
      }
    } catch (_) {}
    // fallback örnekler
    final now = DateTime.now();
    return [
      TrackingActivity(
          id: 'm1',
          type: 'sowing',
          crop: 'Wheat',
          date: now.subtract(const Duration(days: 7)),
          notes: 'Autumn sowing',
          done: true),
      TrackingActivity(
          id: 'm2',
          type: 'irrigation',
          crop: 'Corn',
          date: now.subtract(const Duration(days: 2)),
          notes: 'Drip irrigation',
          done: false),
      TrackingActivity(
          id: 'm3',
          type: 'fertilization',
          crop: 'Tomato',
          date: now,
          notes: 'NPK 15-15-15',
          done: false),
    ];
  }

  Future<void> add(TrackingActivity a) async {
    try {
      await _dio.post('/tracking', data: a.toMap()..remove('id'));
    } catch (_) {}
  }

  Future<void> toggleDone(String id, bool done) async {
    try {
      await _dio.patch('/tracking/$id', data: {'done': done});
    } catch (_) {}
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/tracking/$id');
    } catch (_) {}
  }
}
