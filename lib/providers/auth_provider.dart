import 'dart:convert';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart'
    as http; // [ADICIONADO] Necessário para chamada do link

import 'package:academyhub_mobile/model/user_model.dart';
import '../services/auth_service.dart';
import '../services/auth_student_service.dart';
import 'school_provider.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final AuthStudentService _authStudentService = AuthStudentService();

  User? _user;
  String? _token;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  bool get isProfessor => _user?.roles.contains('Professor') ?? false;

  bool get isStudent =>
      (_user?.roles.contains('Aluno') ?? false) ||
      (_user?.roles.contains('Student') ?? false);

  Future<void> login(
      String identifier, String password, BuildContext context) async {
    try {
      debugPrint('--- [AuthProvider] Iniciando login para: $identifier ---');

      Map<String, dynamic> response;
      Map<String, dynamic> rawUser;

      if (identifier.contains('@')) {
        debugPrint(
            '👨‍🏫 [AuthProvider] E-mail detectado. Roteando para fluxo de Staff.');
        response = await _authService.login(identifier, password);
        rawUser = response['user'];
      } else {
        debugPrint(
            '🎓 [AuthProvider] Sem arroba. Tentando fluxo de Aluno/Matrícula...');
        try {
          response = await _authStudentService.login(identifier, password);

          final studentData = response['student'];
          rawUser = {
            "_id": studentData['id'],
            "fullName": studentData['fullName'],
            "email": "",
            "username": studentData['enrollmentNumber'],
            "roles": ["Student"],
            "status": "Ativo",
            "school_id": studentData['school']['id'],
            "profilePictureUrl": studentData['profilePictureUrl'],
            "staffProfiles": [],
          };
        } catch (e) {
          final errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains('não encontrado') ||
              errorMsg.contains('incorreta')) {
            debugPrint(
                '🔄 [AuthProvider] Não é aluno. Tentando como Username de Staff...');
            response = await _authService.login(identifier, password);
            rawUser = response['user'];
          } else {
            rethrow;
          }
        }
      }

      debugPrint('🔍 [DEBUG FLUTTER] Resposta Recebida da API:');
      try {
        final rawAddress = rawUser['address'];
        debugPrint(' 🆔 User ID: ${rawUser['_id']}');
        debugPrint(' 📦 Address (RuntimeType): ${rawAddress.runtimeType}');
        debugPrint(' 📄 Address (Valor): $rawAddress');

        if (rawAddress is String) {
          debugPrint(
              '❌ PERIGO: Address veio como STRING! O User.fromJson provavelmente vai falhar.');
        } else if (rawAddress is Map) {
          debugPrint('✅ OK: Address veio como MAP.');
        } else if (rawAddress == null) {
          debugPrint('⚠️ AVISO: Address veio NULO.');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao printar debug (ignorando): $e');
      }
      debugPrint('----------------------------------------');

      _user = User.fromJson(rawUser);
      _token = response['token'];

      debugPrint('✅ [AuthProvider] Login bem-sucedido! Objeto User criado.');
      debugPrint('   - Token recebido: ${_token?.substring(0, 15)}...');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', _token!);
      await prefs.setString('userData', json.encode(rawUser));
      debugPrint(
          '💾 [AuthProvider] Token e usuário salvos no SharedPreferences.');

      if (_user != null && _token != null) {
        final schoolId = _user!.schoolId;

        if (schoolId.isNotEmpty) {
          debugPrint(
              '🔄 [AuthProvider] Disparando carregamento da Escola ID: $schoolId');

          if (context.mounted) {
            Provider.of<SchoolProvider>(context, listen: false)
                .loadSchoolData(schoolId, _token!);
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AuthProvider] Erro no login: $e');
      rethrow;
    }
  }

  // =================================================================
  // [NOVO] LÓGICA DO MAGIC LINK DO WHATSAPP
  // =================================================================
  Future<bool> loginWithMagicLink(
      String magicToken, BuildContext context) async {
    try {
      debugPrint('--- [AuthProvider] Iniciando login via Magic Link ---');

      // ⚠️ ATENÇÃO: Coloquei a URL base mockada aqui.
      // Substitua pelo endereço real da sua API (ex: https://api.eyecode.com.br/api)
      const String baseUrl = '${ApiConfig.baseUrl}/api';

      final url =
          Uri.parse('$baseUrl/auth/student/access-by-token?token=$magicToken');

      final httpResponse = await http.get(url);

      if (httpResponse.statusCode == 200) {
        final responseData = json.decode(httpResponse.body);
        final studentData = responseData['student'];

        // O MESMO mapeamento usado no login de aluno acima
        final Map<String, dynamic> rawUser = {
          "_id": studentData['id'],
          "fullName": studentData['fullName'],
          "email": "",
          "username": studentData['enrollmentNumber'],
          "roles": ["Student"],
          "status": "Ativo",
          "school_id": studentData['school']['id'],
          "profilePictureUrl": studentData['profilePictureUrl'],
          "staffProfiles": [],
        };

        _user = User.fromJson(rawUser);
        _token = responseData['token'];

        debugPrint('✅ [AuthProvider] Magic Link aceito! Objeto User criado.');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', _token!);
        await prefs.setString('userData', json.encode(rawUser));

        if (_user != null && _token != null) {
          final schoolId = _user!.schoolId;
          if (schoolId.isNotEmpty && context.mounted) {
            Provider.of<SchoolProvider>(context, listen: false)
                .loadSchoolData(schoolId, _token!);
          }
        }

        notifyListeners();
        return true;
      } else {
        final error = json.decode(httpResponse.body);
        debugPrint('❌ [AuthProvider] Magic Link falhou: ${error['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [AuthProvider] Erro grave no Magic Link: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('userData');

    await prefs.remove('student_token');
    await prefs.remove('student_data');
    await prefs.remove('user_role');

    debugPrint(
        '🗑️ [AuthProvider] Token e usuário removidos do SharedPreferences.');

    notifyListeners();
  }

  Future<bool> tryAutoLogin(BuildContext context) async {
    debugPrint('--- [AuthProvider] Tentando auto-login... ---');
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey('authToken')) {
      debugPrint(
          '🟡 [AuthProvider] Nenhum token encontrado. Auto-login falhou.');
      return false;
    }

    _token = prefs.getString('authToken');
    final userDataString = prefs.getString('userData');

    debugPrint('✅ [AuthProvider] Dados encontrados no SharedPreferences!');

    if (userDataString != null) {
      try {
        final userDataMap = json.decode(userDataString);
        _user = User.fromJson(userDataMap);

        notifyListeners();
        debugPrint(
            '✅ [AuthProvider] Auto-login bem-sucedido. Notificando ouvintes.');

        if (_user != null && _token != null) {
          final schoolId = _user!.schoolId;

          if (schoolId.isNotEmpty) {
            debugPrint(
                '🔄 [AuthProvider] Auto-login: Carregando Escola ID: $schoolId');
            if (context.mounted) {
              Provider.of<SchoolProvider>(context, listen: false)
                  .loadSchoolData(schoolId, _token!);
            }
          }
        }
        return true;
      } catch (e) {
        debugPrint(
            '❌ [AuthProvider] Erro ao processar dados salvos no auto-login: $e');
        await logout();
        return false;
      }
    }

    return false;
  }
}
