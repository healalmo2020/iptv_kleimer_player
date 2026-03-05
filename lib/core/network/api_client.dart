import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> getMap(
    String path, {
    required Map<String, String> query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception('Request failed with status: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      return body;
    }

    throw Exception('Expected JSON object response');
  }

  Future<List<dynamic>> getList(
    String path, {
    required Map<String, String> query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception('Request failed with status: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is List<dynamic>) {
      return body;
    }

    throw Exception('Expected JSON list response');
  }
}
