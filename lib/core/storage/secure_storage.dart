import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class SecureStorage {

  static const storage = FlutterSecureStorage();

  /// TOKEN
  static Future saveToken(String type,String token) =>
      storage.write(key: "${type}token", value: token);

  static Future<String?> getToken(String type) =>
      storage.read(key: "${type}token");

  /// USER NAME
  static Future saveUserName(String name) =>
      storage.write(key: "name", value: name);

  static Future<String?> getUserName() =>
      storage.read(key: "name");

  /// EMAIL
  static Future saveUserEmail(String email) =>
      storage.write(key: "email", value: email);

  static Future<String?> getUserEmail() =>
      storage.read(key: "email");

  /// USER ID
  static Future saveUserId(String id) =>
      storage.write(key: "id", value: id);

  static Future<String?> getUserId() =>
      storage.read(key: "id");

  /// IMAGE (base64 for offline use)
  static Future saveUserImage(String img) =>
      storage.write(key: "image", value: img);

  static Future<String?> getUserImage() =>
      storage.read(key: "image");

  /// Write value
  static Future<void> write({required String key, required String value}) async {
    await storage.write(key: key, value: value);
  }

  /// Read value
  static Future<String?> read({required String key}) async {
    return await storage.read(key: key);
  }

  /// Delete single value
  static Future<void> delete({required String key}) async {
    await storage.delete(key: key);
  }

  /// ---------------- LOGOUT ----------------
  static Future<void> logout() async {
    await storage.deleteAll();
  }

}