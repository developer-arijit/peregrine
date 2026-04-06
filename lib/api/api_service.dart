import 'dart:convert';
import 'package:http/http.dart' as http;

Future<dynamic> apiCall({
  required String endpoint,
  String method = "GET",
  Map<String, dynamic>? body
}) async {

  const String baseUrl = "https://peregrine-test-perebnaz.flowgear.net";
  const String token = "DklJdYl2fZYg7yrfpS7LgffLAbZmrl5zuO1X8y2NtvuTvk-JDKO8dIfiXo9KFREjWPZixrCtolf9ZMHkpTlRpQ";

  final url = Uri.parse("$baseUrl$endpoint");

  // 👇 headers
  Map<String, String> headers = {
    "Content-Type": "application/json",
  };

  // 👇 add token only if available
  headers["Authorization"] = "Bearer $token";

  http.Response response;
  try {
    Future<http.Response> request;

    if (method == "POST") {
      request = http.post(url, headers: headers, body: jsonEncode(body));
    }
    else if (method == "PUT") {
      request =  http.put(url, headers: headers, body: jsonEncode(body));
    }
    else if (method == "DELETE") {
      request =  http.delete(url, headers: headers);
    }
    else {
      request =  http.get(url, headers: headers);
    }

    // ⏱️ Timeout after 1 minute
    response = await request.timeout(const Duration(minutes: 2));

    return jsonDecode(response.body);
  } catch (e) {
    throw Exception("API Timeout or Error: $e");
  }
}