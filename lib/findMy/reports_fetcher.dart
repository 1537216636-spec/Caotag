import 'dart:convert';
import 'package:http/http.dart' as http;

class ReportsFetcher {
  static const _seemooEndpoint = "https://3d72b52ccb74452cbc4916fc0b256ad6.hn.takin.cc/query";

  static Future<List<dynamic>> fetchLocationReports(List<String> keys) async {
    if (keys.isEmpty) return [];
    final payload = {
      "idArray": keys,
      "dateTimeRange": {},
      "mode": "realtime",
    };
    final payloadJson = jsonEncode(payload);
    final base64Payload = base64Encode(utf8.encode(payloadJson));

    print("🔑 Number of keys sent: ${keys.length}");
    print("📝 Payload JSON length: ${payloadJson.length}");
    print("📦 Base64 length: ${base64Payload.length}");
    print('📤 Full Base64: $base64Payload');
    final requestBody = jsonEncode({"data": base64Payload});
    print("📨 Request body length: ${requestBody.length}");

    final response = await http.post(
      Uri.parse(_seemooEndpoint),
      headers: {"Content-Type": "application/json"},
      body: requestBody,
    );

    print("📥 Response status: ${response.statusCode}");
    print("📥 Response body: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded["data"] as List<dynamic>? ?? [];
      print("✅ Parsed reports count: ${data.length}");
      return data;
    } else {
      print("❌ Server error: ${response.body}");
      throw Exception("Failed with status ${response.statusCode}: ${response.body}");
    }
  }
}