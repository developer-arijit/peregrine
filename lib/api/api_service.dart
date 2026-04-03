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

  if (method == "POST") {
    response = await http.post(url, headers: headers, body: jsonEncode(body));
  }
  else if (method == "PUT") {
    response = await http.put(url, headers: headers, body: jsonEncode(body));
  }
  else if (method == "DELETE") {
    response = await http.delete(url, headers: headers);
  }
  else {
    response = await http.get(url, headers: headers);
  }

  return jsonDecode(response.body);
}