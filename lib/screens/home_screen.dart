import 'package:flutter/material.dart';
import '../core/auth/token_manager.dart';
import 'login_screen.dart';
import 'new_order_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api/api_service.dart';
import '../db/database_helper.dart';
import '../core/storage/secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_appauth/flutter_appauth.dart';

class HomeScreen extends StatefulWidget {

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    checkLogin(context);
  }

  Future<void> checkLogin(BuildContext context) async {

    bool loggedIn = await TokenManager.isLoggedIn();

    /// If user not logged in → go to login screen
    if (!loggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
      return;
    }

    /// Check internet connection
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {
      try {
        String refreshToken = await SecureStorage.getToken("refresh") ?? "";

        String? accessToken = await getAccessTokenFromRefreshToken(refreshToken);

        if (accessToken != null) {
          await SecureStorage.saveToken("access", accessToken);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => NewOrderScreen()),
          );
          return;
        }

        final data = await apiCall(endpoint: "/customers");
        if (data != null) {
          await DatabaseHelper.instance.insertOrUpdateApiResponse(data);
        }

        final user = await _getUserProfile(accessToken);

        if (user != null) {
          await SecureStorage.saveUserName(user["displayName"] ?? "");
          await SecureStorage.saveUserEmail(
              user["mail"] ?? user["userPrincipalName"] ?? "");
          await SecureStorage.saveUserId(user["id"] ?? "");

          /// 🔥 Do NOT await this
          getUserImage(accessToken);
        }

      } catch (e) {
        print("App initialize failed reason: $e");
      }
    }

    /// Finally go to home screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NewOrderScreen()),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
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
  static Future<String?> getAccessTokenFromRefreshToken(String refreshToken) async {
    try {
       final FlutterAppAuth appAuth = FlutterAppAuth();
       const String clientId = "e27602f7-ea03-42b5-8d79-21f445ef5ff4";
       const String tenantId = "31f4e4bc-c60a-44a3-ab44-17643c86ee7c";
       const String redirectUrl = "com.peregrine.sales://oauthredirect";
       const String authority =  "https://login.microsoftonline.com/$tenantId/v2.0";

      final result = await appAuth.token(
        TokenRequest(
          clientId,
          redirectUrl,
          issuer: authority,
          refreshToken: refreshToken,
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
        return result.accessToken!;
      }

    } catch (e) {
      print("Refresh token failed: $e");
    }

    return null;
  }
}