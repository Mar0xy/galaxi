import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendClient {
  final String baseUrl;
  final http.Client _client;

  BackendClient({String? baseUrl})
      : baseUrl = baseUrl ?? 'http://localhost:3000',
        _client = http.Client();

  Future<T> call<T>(String method, [List<dynamic>? params]) async {
    final request = {
      'method': method,
      'params': params ?? [],
    };

    final response = await _client.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        return result['result'] as T;
      } else {
        throw Exception(result['error'] ?? 'Unknown error');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  void dispose() {
    _client.close();
  }
}

// Global client instance
final backendClient = BackendClient();
