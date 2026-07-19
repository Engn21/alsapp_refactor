import 'dart:convert';

/// Minimal, dependency-free JWT payload decoder.
/// Throws [FormatException] if token is invalid.
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException('Invalid JWT: must have 3 parts');
  }
  final payloadB64 = base64Url.normalize(parts[1]);
  final jsonStr = utf8.decode(base64Url.decode(payloadB64));
  final map = json.decode(jsonStr);
  if (map is! Map<String, dynamic>) {
    throw const FormatException('Invalid JWT payload');
  }
  return map;
}

/// Returns true if the token's `exp` claim is in the past, or if the
/// token can't be decoded at all. Tokens without an `exp` claim are
/// treated as non-expiring.
bool isJwtExpired(String token) {
  try {
    final claims = decodeJwtPayload(token);
    final exp = claims['exp'];
    if (exp is! num) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    return DateTime.now().isAfter(expiry);
  } catch (_) {
    return true;
  }
}

/// Best-effort extraction with sensible fallbacks.
/// Adjust keys to match your auth server if needed.
class JwtProfile {
  final String email;
  final String role;
  final String? id;   // optional (sub/uid/etc.)
  final String? name; // optional

  JwtProfile({required this.email, required this.role, this.id, this.name});
}

JwtProfile extractProfileFromClaims(Map<String, dynamic> c) {
  String pickString(dynamic v) => v?.toString() ?? '';

  // Email candidates
  final email = [
    c['email'],
    c['upn'],
    c['preferred_username'],
    c['sub'],
  ].map(pickString).firstWhere((s) => s.isNotEmpty,
      orElse: () => 'unknown@example.com');

  // Name candidates
  final name = [
    c['name'],
    c['given_name'],
    c['preferred_username'],
  ].map(pickString).firstWhere((s) => s.isNotEmpty, orElse: () => email.split('@').first);

  // Role candidates (string or first of list)
  String role = 'User';
  if (c['role'] != null) {
    role = pickString(c['role']);
  } else if (c['roles'] is List && (c['roles'] as List).isNotEmpty) {
    role = pickString((c['roles'] as List).first);
  }

  // ID candidates
  final id = [
    c['sub'], c['uid'], c['user_id'], c['id'],
  ].map((v) => v?.toString()).firstWhere((s) => s != null && s!.isNotEmpty, orElse: () => null);

  return JwtProfile(email: email, role: role, id: id, name: name);
}
