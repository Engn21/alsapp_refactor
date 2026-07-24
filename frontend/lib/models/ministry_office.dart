class MinistryOffice {
  final String id;
  final String province;
  final String name;
  final String address;
  final String phone;
  final double lat;
  final double lon;

  MinistryOffice({
    required this.id,
    required this.province,
    required this.name,
    required this.address,
    required this.phone,
    required this.lat,
    required this.lon,
  });

  factory MinistryOffice.fromMap(Map<String, dynamic> m) => MinistryOffice(
        id: (m['id'] ?? '').toString(),
        province: (m['province'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        address: (m['address'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lon: (m['lon'] as num?)?.toDouble() ?? 0,
      );
}
