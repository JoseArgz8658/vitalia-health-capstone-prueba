import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthFailure implements Exception {
  const AuthFailure(this.message, [this.status]);
  final String message;
  final int? status;
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = Uri.parse(baseUrl ?? const String.fromEnvironment(
          'VITALIA_API_URL', defaultValue: 'http://127.0.0.1:3000'));
  final http.Client _client;
  final Uri _base;
  String? _token;
  DateTime? expiresAt;
  bool get hasSession => _token != null;
  void clear() { _token = null; expiresAt = null; }
  void close() { clear(); _client.close(); }

  Future<Map<String, dynamic>> _request(String path,
      {Map<String, String>? body, bool get = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    try {
      final uri = _base.resolve('/api/auth/$path');
      final response = await (get
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body ?? {})))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        if (path != 'login') clear();
        throw AuthFailure(path == 'login' ? 'Correo o contraseña incorrectos.'
            : 'La sesión terminó. Ingresa nuevamente.', 401);
      }
      if (response.statusCode == 429) {
        throw const AuthFailure('Espera antes de volver a intentar.', 429);
      }
      if (response.statusCode >= 400) {
        throw AuthFailure('No se pudo completar la solicitud. Intenta nuevamente.',
            response.statusCode);
      }
      if (response.statusCode == 204) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on AuthFailure { rethrow; }
    on TimeoutException { throw const AuthFailure('El servidor tardó demasiado en responder.'); }
    catch (_) { throw const AuthFailure('No se pudo conectar con el servidor.'); }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    clear();
    try {
      final data = await _request('login', body: {'email': email.trim(), 'password': password});
      _token = data['token'] as String;
      expiresAt = DateTime.parse(data['expiresAt'] as String);
      if (!expiresAt!.isAfter(DateTime.now())) throw const AuthFailure('La sesión terminó.');
      return await me();
    } catch (_) { clear(); rethrow; }
  }
  Future<Map<String, dynamic>> me() async {
    final data = await _request('me', get: true);
    final user = data['user'] as Map<String, dynamic>;
    if (!['paciente', 'profesional', 'administrador'].contains(user['role'])) {
      clear();
      throw const AuthFailure('La cuenta no tiene un rol autorizado.');
    }
    return user;
  }
  Future<void> register(String email, String password) async {
    await _request('register', body: {'email': email.trim(), 'password': password});
  }
  Future<void> logout() async {
    try { await _request('logout'); } finally { clear(); }
  }
}
