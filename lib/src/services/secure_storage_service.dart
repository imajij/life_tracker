import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Keys
  static const String _geminiApiKeyKey = 'gemini_api_key';
  static const String _userIdKey = 'user_id';

  // Gemini API key
  Future<void> saveGeminiApiKey(String key) async {
    await _storage.write(key: _geminiApiKeyKey, value: key);
  }

  Future<String?> getGeminiApiKey() async {
    return await _storage.read(key: _geminiApiKeyKey);
  }

  Future<void> deleteGeminiApiKey() async {
    await _storage.delete(key: _geminiApiKeyKey);
  }

  Future<bool> hasGeminiApiKey() async {
    final key = await getGeminiApiKey();
    return key != null && key.isNotEmpty;
  }

  // User ID
  Future<void> saveUserId(int userId) async {
    await _storage.write(key: _userIdKey, value: userId.toString());
  }

  Future<int?> getUserId() async {
    final id = await _storage.read(key: _userIdKey);
    return id != null ? int.tryParse(id) : null;
  }

  // Clear all data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
