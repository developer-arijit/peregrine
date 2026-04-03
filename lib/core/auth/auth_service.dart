import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import '../storage/secure_storage.dart';
import '../../services/common_methods.dart';

class AuthService {

  static final FlutterAppAuth appAuth = FlutterAppAuth();

  static const String clientId = "e27602f7-ea03-42b5-8d79-21f445ef5ff4";
  static const String tenantId = "31f4e4bc-c60a-44a3-ab44-17643c86ee7c";
  static const String redirectUrl = "com.peregrine.sales://oauthredirect";
  static const String authority = "https://login.microsoftonline.com/$tenantId/v2.0";

  /// ---------------- LOGIN ----------------
  static Future<bool> login() async {

    try {

      final result = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUrl,
          issuer: authority,
          scopes: [
            'openid',
            'profile',
            'email',
            'offline_access',
            'https://graph.microsoft.com/User.Read'
          ],
        ),
      );


      if (result != null && result.accessToken != null) {

        final accessToken = result.accessToken!;
        final refreshToken = result.refreshToken!;

        /// Save token
        await SecureStorage.saveToken("access", accessToken);
        await SecureStorage.saveToken("refresh", refreshToken);


        /// Get user profile
        final user = await _getUserProfile(accessToken);

        if (user != null) {
          await SecureStorage.saveUserName(user["displayName"] ?? "");
          await SecureStorage.saveUserEmail(user["mail"] ?? user["userPrincipalName"] ?? "");
          await SecureStorage.saveUserId(user["id"] ?? "");

          /// ADD THIS LINE (very important)
          await getUserImage(accessToken);
        }

        return true;
      }

    } catch (e) {
      print("Login Error: $e");
    }

    return false;
  }

  /// ---------------- GET USER PROFILE ----------------
  static Future<Map<String, dynamic>?> _getUserProfile(String token) async {

    final response = await http.get(
      Uri.parse("https://graph.microsoft.com/v1.0/me"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }

    return null;
  }

  /// ---------------- GET USER IMAGE ----------------
  static Future<String?> getUserImage(String token) async {

    final response = await http.get(
      Uri.parse("https://graph.microsoft.com/v1.0/me/photo/\$value"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {

      /// Convert image to base64 and store offline
      final imageBase64 = base64Encode(response.bodyBytes);
      await SecureStorage.saveUserImage(imageBase64);

      return imageBase64;
    }

    return null;
  }

  /// ---------------- CHECK LOGIN (OFFLINE SUPPORT) ----------------
  static Future<bool> isLoggedIn() async {

    final token = await SecureStorage.getToken("access");

    if (token == null || token.isEmpty) {
      return false;
    }

    return true;
  }
}