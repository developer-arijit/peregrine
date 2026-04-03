import '../storage/secure_storage.dart';

class TokenManager {

  static Future<bool> isLoggedIn() async {

    final token = await SecureStorage.getToken("access");

    if (token == null || token.isEmpty) {
      return false;
    }

    return true;
  }
}