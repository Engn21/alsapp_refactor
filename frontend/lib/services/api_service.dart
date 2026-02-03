import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../utils/jwt.dart'; // decodeJwtPayload & extractProfileFromClaims

class ApiService {
  // -------- Base URL (eski davranış + API_BASE_URL desteği) --------
  static String _normalizeBase(String raw) {
    var v = raw.trim();
    // sondaki /'ları temizle
    v = v.replaceAll(RegExp(r'/+$'), '');
    // /api yoksa ekle
    final hasApi = RegExp(r'(^|/)api($|/)').hasMatch(Uri.tryParse(v)?.path ?? '');
    if (!hasApi) v = '$v/api';
    return v;
  }

  static String _defaultHostForPlatform() {
    const ipv4Local = 'http://127.0.0.1:8080';
    if (kIsWeb) return ipv4Local;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8080';
      }
    } catch (_) {
      // defaultTargetPlatform bazı ortamlarda exception fırlatabiliyor;
      // bu durumda varsayılan localhost'u kullan.
    }
    return ipv4Local;
  }

  static String get _baseUrl {
    // 1) Senin kullandığın anahtar (öncelik)
    const bUrl = String.fromEnvironment('API_BASE_URL'); // örn: http://127.0.0.1:8080
    if (bUrl.isNotEmpty) return _normalizeBase(bUrl);

    // 2) Eski anahtar
    const b = String.fromEnvironment('API_BASE');
    if (b.isNotEmpty) return _normalizeBase(b);

    // 3) Platforma göre default host
    return _normalizeBase(_defaultHostForPlatform());
  }

  static String get baseUrl => _baseUrl;

  // -------- Session --------
  static AuthSession? session;

  // -------- Auth --------
  static Future<void> signup(
    String name,
    String email,
    String password,
    String roleIgnored,
  ) async {
    final uri = Uri.parse('$_baseUrl/auth/register');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'fullName': name,
        'role': roleIgnored, // 'farmer' | 'ministry'
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Register failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Login -> returns JWT token
  static Future<String> login(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Login failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = (data['token'] as String?) ?? '';

    // JWT decode + session doldur (ESKİ AKIŞ)
    try {
      final claims = decodeJwtPayload(token);
      final profile = extractProfileFromClaims(claims);
      session = AuthSession(
        token: token,
        email: profile.email,
        role: profile.role,
        userId: profile.id,
        name: (profile.name ?? '').trim().isEmpty ? null : profile.name!.trim(),
      );
    } catch (_) {
      session = AuthSession(
        token: token,
        email: email,
        role: 'User',
        name: null,
      );
    }

    // Email fallback (ESKİ AKIŞ)
    try {
      final s = session;
      if (s != null && !s.email.contains('@')) {
        session = AuthSession(
          token: s.token,
          email: email,
          role: s.role,
          userId: s.userId,
          name: s.name,
        );
      }
    } catch (_) {}

    // /auth/me ile kesinleştir (ESKİ AKIŞ)
    await fetchMe();
    return token;
  }

  static Future<void> fetchMe() async {
    final t = session?.token;
    if (t == null || t.isEmpty) return;

    final res = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) {
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      session = AuthSession(
        token: t,
        email: (m['email'] as String?) ?? session?.email ?? '',
        role: (m['role'] as String?) ?? session?.role ?? 'User',
        userId: (m['id'] as String?) ?? session?.userId,
        name: (m['fullName'] as String?)?.trim().isEmpty == true
            ? null
            : (m['fullName'] as String?)?.trim(),
      );
    }
  }

  // -------- Common headers --------
  static Map<String, String> _authHeader([String? token]) {
    final t = token ?? session?.token;
    return (t != null && t.isNotEmpty) ? {'Authorization': 'Bearer $t'} : {};
  }

  static Map<String, dynamic>? _normalizeTypeSpecificMap(
      Map<String, dynamic>? input) {
    if (input == null) return null;
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      if (value == null) return;
      if (value is DateTime) {
        result[key] = value.toIso8601String().split('T').first;
      } else if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          result[key] = trimmed;
        }
      } else {
        result[key] = value;
      }
    });
    return result.isEmpty ? null : result;
  }

  static Map<String, dynamic> _normalizePatchBody(
      Map<String, dynamic>? input) {
    if (input == null) return <String, dynamic>{};
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  // -------- Crops --------
  static Future<List<dynamic>> listCrops({String? token}) async {
    final uri = Uri.parse('$_baseUrl/crops');
    final res = await http.get(uri, headers: _authHeader(token));
    if (res.statusCode != 200) {
      throw Exception('List crops failed: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body);
    return (body is List) ? body : (body['items'] as List<dynamic>? ?? []);
  }

static Future<void> createCrop({
  required String cropType,
  required DateTime plantingDate,
  DateTime? harvestDate,
  String? notes,
  double? areaHectares,
  String? pesticide,
  String? specificType,
  Map<String, dynamic>? typeSpecific,
  String? token,
}) async {
  final uri = Uri.parse('$_baseUrl/crops');
  final typeSpecificPayload = _normalizeTypeSpecificMap(typeSpecific);
  final body = <String, dynamic>{
    'cropType': cropType,
    'plantingDate': plantingDate.toIso8601String(),
    if (harvestDate != null) 'harvestDate': harvestDate.toIso8601String(),
    if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    if (areaHectares != null) 'area': areaHectares,
    if (pesticide != null && pesticide.trim().isNotEmpty)
      'pesticideType': pesticide.trim(),
    if (specificType != null && specificType.trim().isNotEmpty)
      'specificType': specificType.trim(),
    if (typeSpecificPayload != null) 'typeSpecific': typeSpecificPayload,
  };

  final res = await http.post(
    uri,
    headers: {..._authHeader(token), 'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Create crop failed: ${res.statusCode} ${res.body}');
  }
}


  /// AddProduct (ESKİ DAVRANIŞ)
  static Future<void> addProduct(Map<String, dynamic> data) async {
    final type = (data['type'] as String? ?? 'crop').toLowerCase();

    if (type == 'crop') {
      final cropType = (data['crop_type'] as String? ?? '').trim();
      final plantingStr = (data['planting_date'] as String? ?? '').trim();
      final harvestStr = (data['harvest_date'] as String? ?? '').trim();
      final areaStr = (data['area'] ?? data['area_ha'] ?? data['area_hectares'] ?? '')
          .toString()
          .trim();
      final pesticide = (data['pesticide'] ?? data['pesticide_type'] ?? '')
          .toString()
          .trim();
      if (cropType.isEmpty || plantingStr.isEmpty) {
        throw Exception('Lütfen ürün türü ve ekim tarihini doldurunuz.');
      }
      DateTime parseDate(String s) => DateTime.parse(s);
      await createCrop(
        cropType: cropType,
        plantingDate: parseDate(plantingStr),
        harvestDate: harvestStr.isEmpty ? null : parseDate(harvestStr),
        notes: (data['notes'] as String?)?.trim(),
        areaHectares:
            areaStr.isEmpty ? null : double.tryParse(areaStr.replaceAll(',', '.')),
        pesticide: pesticide.isEmpty ? null : pesticide,
        specificType: (data['specificType'] ?? data['specific_type'])?.toString(),
        typeSpecific: data['typeSpecific'] is Map
            ? Map<String, dynamic>.from(data['typeSpecific'] as Map)
            : null,
      );
      return;
    }

    if (type == 'livestock') {
      final species = (data['species'] ?? data['animal_type'] ?? '').toString().trim();
      if (species.isEmpty) {
        throw Exception('Hayvancılık türü (species) gerekli.');
      }
      int? ageMonths;
      final ageRaw = (data['age'] ?? data['ageMonths'])?.toString().trim();
      if (ageRaw != null && ageRaw.isNotEmpty) {
        ageMonths = int.tryParse(ageRaw);
      }
      double? weightKg;
      final weightRaw = (data['weight'] ?? data['weightKg'])?.toString().trim();
      if (weightRaw != null && weightRaw.isNotEmpty) {
        weightKg = double.tryParse(weightRaw);
      }

      final rawDailyFeed =
          data['dailyFeedKg'] ?? data['daily_feed'] ?? data['feedKg'];
      double? dailyFeedKg;
      if (rawDailyFeed != null) {
        if (rawDailyFeed is num) {
          dailyFeedKg = rawDailyFeed.toDouble();
        } else {
          final str = rawDailyFeed.toString().trim();
          if (str.isNotEmpty) {
            dailyFeedKg = double.tryParse(str);
          }
        }
      }

      DateTime? lastCheckupDate;
      final rawCheckup =
          data['lastCheckupDate'] ?? data['last_checkup_date'];
      if (rawCheckup != null) {
        if (rawCheckup is DateTime) {
          lastCheckupDate = rawCheckup;
        } else {
          final str = rawCheckup.toString().trim();
          if (str.isNotEmpty) {
            lastCheckupDate = DateTime.parse(str);
          }
        }
      }

      final specificType =
          (data['specificType'] ?? data['specific_type'])?.toString();

      await createLivestock(
        species: species,
        ageMonths: ageMonths,
        weightKg: weightKg,
        tagId: (data['tagId'] as String?)?.trim(),
        notes: (data['notes'] as String?)?.trim(),
        dailyFeedKg: dailyFeedKg,
        healthStatus: (data['healthStatus'] as String?)?.trim(),
        vaccineStatus: (data['vaccineStatus'] as String?)?.trim(),
        lastCheckupDate: lastCheckupDate,
        specificType: specificType,
        typeSpecific: data['typeSpecific'] is Map
            ? Map<String, dynamic>.from(data['typeSpecific'] as Map)
            : null,
      );
      return;
    }

    throw Exception('Desteklenmeyen ürün tipi: $type');
  }
// ================= LIVESTOCK (opsiyonel) =================
static Future<List<dynamic>> listLivestock({String? token}) async {
  final uri = Uri.parse('$_baseUrl/livestock');
  final res = await http.get(uri, headers: _authHeader(token));
  if (res.statusCode == 404) return <dynamic>[]; // endpoint yoksa sessizce boş
  if (res.statusCode != 200) {
    throw Exception('List livestock failed: ${res.statusCode} ${res.body}');
  }
  final body = jsonDecode(res.body);
  return (body is List) ? body : (body['items'] as List<dynamic>? ?? []);
}

  static Future<Map<String, dynamic>> livestockDetail(String id) async {
    final uri = Uri.parse('$_baseUrl/livestock/$id');
    final res = await http.get(uri, headers: _authHeader());
    if (res.statusCode != 200) {
      throw Exception('Livestock detail failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteLivestock(String id) async {
    final uri = Uri.parse('$_baseUrl/livestock/$id');
    final res = await http.delete(uri, headers: _authHeader());
    if (res.statusCode != 204) {
      throw Exception('Delete livestock failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> addMilkMeasurement({
    required String id,
    required double quantityLiters,
    double? fatPercent,
    DateTime? date,
  }) async {
    final uri = Uri.parse('$_baseUrl/livestock/$id/milk');
    final body = <String, dynamic>{
      'quantity': quantityLiters,
      if (fatPercent != null) 'fat': fatPercent,
      if (date != null) 'date': date.toIso8601String(),
    };
    final res = await http.post(
      uri,
      headers: {..._authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Milk record failed: ${res.statusCode} ${res.body}');
    }
  }

/// Crops + Livestock birlikte (UI için pratik)
static Future<List<dynamic>> listProductsCombined() async {
  List<dynamic> crops = [];
  List<dynamic> animals = [];
  await Future.wait([
    () async { try { crops = await listCrops(); } catch (e) { debugPrint('[products] crops err: $e'); } }(),
    () async { try { animals = await listLivestock(); } catch (e) { debugPrint('[products] livestock err: $e'); } }(),
  ]);
  return [...crops, ...animals];
}

  static Future<Map<String, dynamic>> cropDetail(String id) async {
    final uri = Uri.parse('$_baseUrl/crops/$id');
    final res = await http.get(uri, headers: _authHeader());
    if (res.statusCode != 200) {
      throw Exception('Crop detail failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteCrop(String id) async {
    final uri = Uri.parse('$_baseUrl/crops/$id');
    final res = await http.delete(uri, headers: _authHeader());
    if (res.statusCode != 204) {
      throw Exception('Delete crop failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> addCropSpray({
    required String id,
    DateTime? date,
    String? pesticide,
  }) async {
    final uri = Uri.parse('$_baseUrl/crops/$id/spray');
    final body = <String, dynamic>{
      if (date != null) 'date': date.toIso8601String(),
      if (pesticide != null && pesticide.trim().isNotEmpty)
        'pesticide': pesticide.trim(),
    };
    final res = await http.post(
      uri,
      headers: {..._authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Crop spray log failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> addCropHarvest({
    required String id,
    DateTime? date,
    required double amountTon,
  }) async {
    final uri = Uri.parse('$_baseUrl/crops/$id/harvest');
    final body = <String, dynamic>{
      'amount': amountTon,
      if (date != null) 'date': date.toIso8601String(),
    };
    final res = await http.post(
      uri,
      headers: {..._authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Crop harvest log failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> addCropQuality({
    required String id,
    DateTime? date,
    double? proteinPercent,
    double? moisturePercent,
    double? sugarPercent,
    double? oilPercent,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/crops/$id/quality');
    final body = <String, dynamic>{
      if (date != null) 'date': date.toIso8601String(),
      if (proteinPercent != null) 'proteinPercent': proteinPercent,
      if (moisturePercent != null) 'moisturePercent': moisturePercent,
      if (sugarPercent != null) 'sugarPercent': sugarPercent,
      if (oilPercent != null) 'oilPercent': oilPercent,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final res = await http.post(
      uri,
      headers: {..._authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Crop quality log failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> createLivestock({
    required String species,
    int? ageMonths,
    double? weightKg,
    String? tagId,
    String? notes,
    double? dailyFeedKg,
    String? healthStatus,
    String? vaccineStatus,
    DateTime? lastCheckupDate,
    String? specificType,
    Map<String, dynamic>? typeSpecific,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl/livestock');
    final typeSpecificPayload = _normalizeTypeSpecificMap(typeSpecific);
    final body = <String, dynamic>{
      'species': species,
      if (ageMonths != null) 'age': ageMonths,
      if (weightKg != null) 'weight': weightKg,
      if (tagId != null && tagId.isNotEmpty) 'tagId': tagId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (dailyFeedKg != null) 'dailyFeedKg': dailyFeedKg,
      if (healthStatus != null && healthStatus.trim().isNotEmpty)
        'healthStatus': healthStatus.trim(),
      if (vaccineStatus != null && vaccineStatus.trim().isNotEmpty)
        'vaccineStatus': vaccineStatus.trim(),
      if (lastCheckupDate != null)
        'lastCheckupDate': lastCheckupDate.toIso8601String(),
      if (specificType != null && specificType.trim().isNotEmpty)
        'specificType': specificType.trim(),
      if (typeSpecificPayload != null) 'typeSpecific': typeSpecificPayload,
    };

    final res = await http.post(
      uri,
      headers: {..._authHeader(token), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create livestock failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Map<String, dynamic>> updateCrop(
    String id, {
    Map<String, dynamic>? fields,
    Map<String, dynamic>? typeSpecific,
  }) async {
    final uri = Uri.parse('$_baseUrl/crops/$id');
    final payload = _normalizePatchBody(fields);
    final typeSpecificPayload = _normalizeTypeSpecificMap(typeSpecific);
    if (typeSpecificPayload != null) {
      payload['typeSpecific'] = typeSpecificPayload;
    }

    final res = await http.patch(
      uri,
      headers: {..._authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update crop failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateLivestock(
    String id, {
    Map<String, dynamic>? fields,
    Map<String, dynamic>? typeSpecific,
  }) async {
    final uri = Uri.parse('$_baseUrl/livestock/$id');
    final payload = _normalizePatchBody(fields);
    final typeSpecificPayload = _normalizeTypeSpecificMap(typeSpecific);
    if (typeSpecificPayload != null) {
      payload['typeSpecific'] = typeSpecificPayload;
    }

    final res = await http.patch(
      uri,
      headers: {..._authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update livestock failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ===================== Weather (ek) =====================
  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static WeatherMetrics _metricsFromOpenWeather(Map<String, dynamic> json) {
    final mainStr = (json['weather']?[0]?['main'] ?? '').toString();
    final description = (json['weather']?[0]?['description'] ?? '').toString();

    double? kelvin = _toDouble(json['main']?['temp']);
    final double? c = (kelvin != null) ? (kelvin - 273.15) : null;

    final int? hum = (json['main']?['humidity'] is num)
        ? (json['main']['humidity'] as num).toInt()
        : null;

    final double? wind = _toDouble(json['wind']?['speed']);
    final double? windMax = _toDouble(json['wind']?['gust']);

    double? kelvinMin = _toDouble(json['main']?['temp_min']);
    double? kelvinMax = _toDouble(json['main']?['temp_max']);
    final double? tempMinC = kelvinMin != null ? (kelvinMin - 273.15) : null;
    final double? tempMaxC = kelvinMax != null ? (kelvinMax - 273.15) : null;

    final daily = json['daily'];
    final bool isDaily = daily is Map<String, dynamic>;
    final bool? hasRain =
        (daily is Map<String, dynamic>) ? daily['hasRain'] as bool? : null;
    final double? dailyTempMin =
        (daily is Map<String, dynamic>) ? _toDouble(daily['tempMinC']) : null;
    final double? dailyTempMax =
        (daily is Map<String, dynamic>) ? _toDouble(daily['tempMaxC']) : null;
    final double? dailyWindMax =
        (daily is Map<String, dynamic>) ? _toDouble(daily['windMax']) : null;

    final String? providedSummary =
        (daily is Map<String, dynamic>) && daily['summary'] is String
            ? (daily['summary'] as String)
            : (json['summary'] is String ? json['summary'] as String : null);

    return WeatherMetrics(
      main: mainStr,
      description: description.isEmpty ? null : description,
      tempC: c,
      humidity: hum,
      windSpeed: wind,
      tempMinC: dailyTempMin ?? tempMinC,
      tempMaxC: dailyTempMax ?? tempMaxC,
      windMax: dailyWindMax ?? windMax,
      isDaily: isDaily,
      hasRain: hasRain,
      summaryText: providedSummary,
    );
  }

  static Future<WeatherMetrics?> quickWeatherMetricsByCoords({
    required double lat,
    required double lon,
    bool daily = false,
  }) async {
    Future<WeatherMetrics?> fetch(String endpoint) async {
      final uri = Uri.parse('$_baseUrl$endpoint').replace(
        queryParameters: {'lat': '$lat', 'lon': '$lon'},
      );
      try {
        final res = await http.get(uri, headers: _authHeader());
        if (res.statusCode == 200) {
          final m = jsonDecode(res.body) as Map<String, dynamic>;
          return _metricsFromOpenWeather(m);
        }
      } catch (_) {
        // swallow – we'll attempt fallback below
      }
      return null;
    }

    final primary = daily ? '/weather/daily' : '/weather';
    final metrics = await fetch(primary);
    if (metrics != null) return metrics;
    if (primary != '/weather') {
      return fetch('/weather');
    }
    return null;
  }

  static Future<String?> quickWeatherSummary({
    required String userId,
    required String password,
  }) async {
    return quickWeatherSummaryByCoords(lat: 41.015137, lon: 28.979530);
  }

  static Future<String?> quickWeatherSummaryByCoords({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse('$_baseUrl/weather/summary')
        .replace(queryParameters: {'lat': '$lat', 'lon': '$lon'});
    try {
      final res = await http.get(uri, headers: _authHeader());
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final s = (m['summary'] ?? m['description'] ?? '').toString().trim();
        return s.isEmpty ? '—' : s;
      }
      return '—';
    } catch (_) {
      return '—';
    }
  }

  // -------- UI helper --------
  static Future<void> showAlert(BuildContext context, String s) async {
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Alert'),
          content: Text(s),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  static Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await signup(name, email, password, role);
  }

  // ===================== Support Programs =====================

  static Future<List<dynamic>> listSupports({
    String? category,
    String? cropType,
    String? livestockType,
    String? status = 'active',
    String? lang = 'tr',
    String? token,
  }) async {
    final queryParams = <String, String>{
      if (category != null) 'category': category,
      if (cropType != null) 'cropType': cropType,
      if (livestockType != null) 'livestockType': livestockType,
      if (status != null) 'status': status,
      if (lang != null) 'lang': lang,
    };

    final uri = Uri.parse('$_baseUrl/supports').replace(queryParameters: queryParams);
    final res = await http.get(uri, headers: _authHeader(token));

    if (res.statusCode == 404) return <dynamic>[];
    if (res.statusCode != 200) {
      throw Exception('List supports failed: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(res.body);
    return (body is List) ? body : [];
  }

  static Future<Map<String, dynamic>> getSupportDetail(String id, {String? lang = 'tr'}) async {
    final uri = Uri.parse('$_baseUrl/supports/$id').replace(
      queryParameters: {'lang': lang ?? 'tr'},
    );
    final res = await http.get(uri, headers: _authHeader());
    if (res.statusCode != 200) {
      throw Exception('Support detail failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

// ---- Weather metrics basit DTO ----
class WeatherMetrics {
  final String main; // example: "Rain", "Clouds"
  final String? description;
  final double? tempC; // °C
  final int? humidity; // %
  final double? windSpeed; // m/s
  final double? tempMinC;
  final double? tempMaxC;
  final double? windMax;
  final bool isDaily;
  final bool? hasRain;
  final String? summaryText;
  const WeatherMetrics({
    required this.main,
    this.description,
    this.tempC,
    this.humidity,
    this.windSpeed,
    this.tempMinC,
    this.tempMaxC,
    this.windMax,
    this.isDaily = false,
    this.hasRain,
    this.summaryText,
  });
  String summary() {
    if (summaryText != null && summaryText!.isNotEmpty) return summaryText!;
    final t = (tempC != null) ? '${tempC!.toStringAsFixed(1)}°C' : '';
    return t.isEmpty ? main : '$main / $t';
  }
}

// ---- Session model ----
class AuthSession {
  final String token;
  final String email;
  final String role;
  final String? userId;
  final String? name;
  const AuthSession({
    required this.token,
    required this.email,
    required this.role,
    this.userId,
    this.name,
  });
}
