import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const String baseUrl = "http://10.212.9.232:5000";

  // ================= GENERIC GET =================
  static Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('GET $path failed (${res.statusCode}): ${res.body}');
    }
  }

  // ================= STATS =================
  static Future<Map<String, dynamic>> getStats() async {
    final data = await _get('/api/stats');
    return data as Map<String, dynamic>;
  }

  // ================= PAST RESULTS =================
  static Future<List<dynamic>> getPastResults() async {
    final data = await _get('/api/past-results');
    return data as List<dynamic>;
  }

  // ================= DELETE RESULT =================
  static Future<void> deleteResult(String filename, String timestamp) async {
    final uri = Uri.parse(
      '$baseUrl/api/delete-result?filename=${Uri.encodeComponent(filename)}&timestamp=${Uri.encodeComponent(timestamp)}',
    );

    final res = await http.delete(uri);

    if (res.statusCode != 200) {
      throw Exception('Delete failed (${res.statusCode}): ${res.body}');
    }
  }

  // ================= QUALITY GRADING =================
  static Future<Map<String, dynamic>> summarizeQuality({
    required XFile file,
    required String fruit,
  }) async {
    final uri = Uri.parse('$baseUrl/summarize_quality');
    final request = http.MultipartRequest('POST', uri);

    final Uint8List fileBytes = await file.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: file.name,
    ));

    request.fields['fruit'] = fruit;

    final streamed = await request.send();
    final resString = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return jsonDecode(resString) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Quality grading failed (${streamed.statusCode}): $resString');
    }
  }

  // ================= PRICE PREDICTION =================
  static Future<Map<String, dynamic>> predictPrice({
    required XFile file,
    required String market,
    required String variety,
    required String arrivals,
    required String fruit,
  }) async {
    final uri = Uri.parse('$baseUrl/predict_price');
    final request = http.MultipartRequest('POST', uri);

    request.fields['market'] = market;
    request.fields['variety'] = variety;
    request.fields['arrivals'] = arrivals;
    request.fields['fruit'] = fruit;

    final Uint8List fileBytes = await file.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: file.name,
    ));

    final streamed = await request.send();
    final resString = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return jsonDecode(resString) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Price prediction failed (${streamed.statusCode}): $resString');
    }
  }

  // ================= MARKET RECOMMENDATION =================
  static Future<Map<String, dynamic>> getMarketRecommendation({
    required String location,
    required String quality,
    required String fruit,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/recommend_market'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "location": location,
        "quality": quality,
        "fruit": fruit,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Market recommendation failed (${res.statusCode}): ${res.body}');
    }
  }
}