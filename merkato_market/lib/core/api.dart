import 'dart:convert';
import 'package:http/http.dart' as http;

/// Override at build time: flutter run --dart-define=API_URL=http://192.168.1.5:3000
/// 10.0.2.2 is how the Android emulator reaches your PC's localhost.
const kApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

String errText(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';

class ApiClient {
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response r;
    try {
      r = await call().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(0, 'Cannot reach the server. Check your connection.');
    }
    final body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode, (body is Map ? body['error'] as String? : null) ?? 'Request failed (${r.statusCode})');
    }
    return body;
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send(() => http.get(Uri.parse('$kApiUrl$path').replace(queryParameters: query), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send(() => http.post(Uri.parse('$kApiUrl$path'), headers: _headers, body: jsonEncode(body ?? {})));
}
