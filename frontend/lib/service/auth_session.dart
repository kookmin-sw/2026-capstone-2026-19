class AuthSession {
  static String? token;
  static String? username;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  static void save({
    required String newToken,
    required String newUsername,
  }) {
    token = newToken;
    username = newUsername;
  }

  static void clear() {
    token = null;
    username = null;
  }
}