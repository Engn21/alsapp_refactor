String resolveApiBase() {
  const custom = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (custom.isNotEmpty) return custom;
  // Mac veya web için 127.0.0.1, Android emulator için 10.0.2.2
  return const String.fromEnvironment('FLUTTER_WEB_USE_SKIA', defaultValue: '') == ''
      ? 'http://10.0.2.2:8080'
      : 'http://127.0.0.1:8080';
}
