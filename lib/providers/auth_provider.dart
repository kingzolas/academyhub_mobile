import 'dart:convert';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/screens/loginPage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:academyhub_mobile/model/user_model.dart';
import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import '../services/auth_service.dart';
import '../services/auth_student_service.dart';
import '../services/guardian_auth_service.dart';
import 'school_provider.dart';

// Imports dos Providers que precisam ser limpos no logout
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/student_provider.dart';
import 'package:academyhub_mobile/providers/horario_provider.dart';
import 'package:academyhub_mobile/providers/academic_calendar_provider.dart';
import 'package:academyhub_mobile/providers/attendance_provider.dart';
import 'package:academyhub_mobile/providers/user_provider.dart';
import 'package:academyhub_mobile/providers/report_card_provider.dart';

// [NOVO] Imports para a navegação global forçada
import '../services/navigation_service.dart';
// import '../screens/auth/login_screen.dart'; // Ajuste este caminho para a sua tela de Login real

class AuthProvider with ChangeNotifier {
  static const String _authTokenKey = 'authToken';
  static const String _userDataKey = 'userData';
  static const String _guardianSessionDataKey = 'guardianSessionData';
  static const String _sessionPrincipalKey = 'session_principal';
  static const String _studentTokenKey = 'student_token';
  static const String _studentDataKey = 'student_data';
  static const String _userRoleKey = 'user_role';

  final AuthService _authService = AuthService();
  final AuthStudentService _authStudentService = AuthStudentService();
  final GuardianAuthService _guardianAuthService = GuardianAuthService();

  User? _user;
  String? _token;
  GuardianSession? _guardianSession;
  String? _sessionPrincipal;

  User? get user => _user;
  String? get token => _token;
  GuardianSession? get guardianSession => _guardianSession;
  String? get guardianSelectedStudentId => _guardianSession?.selectedStudentId;
  bool get isAuthenticated => _token != null;
  bool get isGuardian =>
      _sessionPrincipal == 'guardian' && _guardianSession != null;

  bool get isProfessor => _user?.roles.contains('Professor') ?? false;

  bool get isStudent =>
      (_user?.roles.contains('Aluno') ?? false) ||
      (_user?.roles.contains('Student') ?? false);

  Future<void> _persistStandardSession(Map<String, dynamic> rawUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, _token!);
    await prefs.setString(_userDataKey, json.encode(rawUser));
    await prefs.remove(_guardianSessionDataKey);
    await prefs.setString(
        _sessionPrincipalKey, isStudent ? 'student' : 'staff');
  }

  Future<void> _persistGuardianSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, _token!);
    await prefs.setString(
      _guardianSessionDataKey,
      json.encode(_guardianSession!.toJson()),
    );
    await prefs.remove(_userDataKey);
    await prefs.remove(_studentTokenKey);
    await prefs.remove(_studentDataKey);
    await prefs.remove(_userRoleKey);
    await prefs.setString(_sessionPrincipalKey, 'guardian');
  }

  String? _pickGuardianSelectedStudentId(
    GuardianSession session, {
    String? preferredStudentId,
  }) {
    final normalizedPreferred = (preferredStudentId ?? '').trim();
    if (session.hasLinkedStudent(normalizedPreferred)) {
      return normalizedPreferred;
    }

    final defaultStudentId = session.defaultStudent?.id;
    if (session.hasLinkedStudent(defaultStudentId)) {
      return defaultStudentId;
    }

    if (session.linkedStudents.isNotEmpty) {
      return session.linkedStudents.first.id;
    }

    return null;
  }

  Future<void> setGuardianSelectedStudentId(String? studentId) async {
    if (_guardianSession == null) return;

    final resolvedStudentId = _pickGuardianSelectedStudentId(
      _guardianSession!,
      preferredStudentId: studentId,
    );

    _guardianSession = _guardianSession!.copyWith(
      selectedStudentId: resolvedStudentId,
      clearSelectedStudentId: resolvedStudentId == null,
    );

    await _persistGuardianSession();
    notifyListeners();
  }

  // =================================================================
  // FUNÇÃO GLOBAL PARA LIMPEZA DE CACHE DOS PROVIDERS
  // =================================================================
  static void clearAppCache(BuildContext context) {
    debugPrint(
        '🧹 [AuthProvider] Iniciando limpeza de cache dos Providers globais...');
    try {
      // Importante: A flag listen: false é OBRIGATÓRIA aqui.
      Provider.of<ClassProvider>(context, listen: false).clear();
      Provider.of<StudentProvider>(context, listen: false).clear();
      Provider.of<HorarioProvider>(context, listen: false).clear();
      Provider.of<AcademicCalendarProvider>(context, listen: false).clear();
      Provider.of<AttendanceProvider>(context, listen: false).clear();
      Provider.of<UserProvider>(context, listen: false).clear();
      Provider.of<ReportCardProvider>(context, listen: false).clear();

      debugPrint('✅ [AuthProvider] Cache limpo com sucesso.');
    } catch (e) {
      debugPrint(
          '⚠️ [AuthProvider] Aviso na limpeza de cache: Algum provider não possui o método clear(). Erro: $e');
    }
  }

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
      _guardianSession = null;
      _sessionPrincipal = isStudent ? 'student' : 'staff';

      debugPrint('✅ [AuthProvider] Login bem-sucedido! Objeto User criado.');
      debugPrint('   - Token recebido: ${_token?.substring(0, 15)}...');

      await _persistStandardSession(rawUser);
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
  // LÓGICA DO MAGIC LINK DO WHATSAPP
  // =================================================================
  Future<bool> loginWithMagicLink(
      String magicToken, BuildContext context) async {
    try {
      debugPrint('--- [AuthProvider] Iniciando login via Magic Link ---');

      const String baseUrl = '${ApiConfig.baseUrl}/api';

      final url =
          Uri.parse('$baseUrl/auth/student/access-by-token?token=$magicToken');

      final httpResponse = await http.get(url);

      if (httpResponse.statusCode == 200) {
        final responseData = json.decode(httpResponse.body);
        final studentData = responseData['student'];

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
        _guardianSession = null;
        _sessionPrincipal = 'student';

        debugPrint('✅ [AuthProvider] Magic Link aceito! Objeto User criado.');

        await _persistStandardSession(rawUser);

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

  // =================================================================
  // [AJUSTADO] FUNÇÃO DE LOGOUT COM REDIRECIONAMENTO GLOBAL
  // =================================================================
  Future<void> logout([BuildContext? context]) async {
    // 1. Tenta limpar o cache dos providers usando o context passado ou o global
    final activeContext =
        context ?? NavigationService.navigatorKey.currentContext;

    if (activeContext != null && activeContext.mounted) {
      clearAppCache(activeContext);
    } else {
      debugPrint(
          '⚠️ [AuthProvider] Nenhum Context válido encontrado. Cache local em memória pode não ter sido limpo.');
    }

    // 2. Apaga as variáveis locais da sessão
    _user = null;
    _token = null;
    _guardianSession = null;
    _sessionPrincipal = null;

    // 3. Remove do armazenamento permanente
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_guardianSessionDataKey);
    await prefs.remove(_studentTokenKey);
    await prefs.remove(_studentDataKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_sessionPrincipalKey);

    debugPrint(
        '🗑️ [AuthProvider] Sessão encerrada e dados removidos do SharedPreferences.');

    // 4. Avisa a UI para redesenhar variáveis que dependam de autenticação
    notifyListeners();

    // 5. O PULO DO GATO: Força o redirecionamento global e apaga o histórico de navegação
    if (NavigationService.navigatorKey.currentState != null) {
      debugPrint('🚪 [AuthProvider] Redirecionando para a tela de Login...');
      NavigationService.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Loginpage()),
        (Route<dynamic> route) =>
            false, // Remove todas as telas anteriores da pilha
      );
    } else {
      debugPrint(
          '❌ [AuthProvider] navigatorKey.currentState está NULO. Não foi possível redirecionar.');
    }
  }

  Future<bool> tryAutoLogin(BuildContext context) async {
    debugPrint('--- [AuthProvider] Tentando auto-login... ---');
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_authTokenKey)) {
      debugPrint(
          '🟡 [AuthProvider] Nenhum token encontrado. Auto-login falhou.');
      return false;
    }

    _token = prefs.getString(_authTokenKey);
    final sessionPrincipal = prefs.getString(_sessionPrincipalKey);

    if (sessionPrincipal == 'guardian') {
      final guardianSessionString = prefs.getString(_guardianSessionDataKey);

      if (guardianSessionString == null) {
        if (context.mounted) {
          await logout(context);
        } else {
          await logout();
        }
        return false;
      }

      try {
        _user = null;
        _guardianSession =
            GuardianSession.fromJson(json.decode(guardianSessionString));
        _sessionPrincipal = 'guardian';
        notifyListeners();
        debugPrint(
            '✅ [AuthProvider] Auto-login de responsavel restaurado com sucesso.');
        return true;
      } catch (e) {
        debugPrint(
            '❌ [AuthProvider] Erro ao restaurar sessao de responsavel: $e');
        if (context.mounted) {
          await logout(context);
        } else {
          await logout();
        }
        return false;
      }
    }

    final userDataString = prefs.getString(_userDataKey);

    debugPrint('✅ [AuthProvider] Dados encontrados no SharedPreferences!');

    if (userDataString != null) {
      try {
        final userDataMap = json.decode(userDataString);
        _user = User.fromJson(userDataMap);
        _guardianSession = null;
        _sessionPrincipal =
            sessionPrincipal ?? (isStudent ? 'student' : 'staff');

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
        // Usando o context se houver erro e precisar forçar o logout
        if (context.mounted) {
          await logout(context);
        } else {
          await logout();
        }
        return false;
      }
    }

    return false;
  }

  Future<GuardianFirstAccessStartResult> startGuardianFirstAccess({
    String? schoolPublicId,
    required String studentFullName,
    required String birthDate,
  }) {
    return _guardianAuthService.startGuardianFirstAccess(
      schoolPublicId: schoolPublicId,
      studentFullName: studentFullName,
      birthDate: birthDate,
    );
  }

  Future<GuardianVerificationResult> verifyGuardianResponsible({
    required String challengeId,
    required String optionId,
    required String cpf,
  }) {
    return _guardianAuthService.verifyGuardianResponsible(
      challengeId: challengeId,
      optionId: optionId,
      cpf: cpf,
    );
  }

  Future<GuardianPinSetupResult> setGuardianPin({
    required String challengeId,
    required String verificationToken,
    required String pin,
  }) {
    return _guardianAuthService.setGuardianPin(
      challengeId: challengeId,
      verificationToken: verificationToken,
      pin: pin,
    );
  }

  Future<GuardianPinSetupResult> linkGuardianStudentWithExistingPin({
    required String challengeId,
    required String verificationToken,
    required String pin,
  }) {
    return _guardianAuthService.linkGuardianStudentWithExistingPin(
      challengeId: challengeId,
      verificationToken: verificationToken,
      pin: pin,
    );
  }

  Future<GuardianLoginResult> loginGuardian({
    String? schoolPublicId,
    required String cpf,
    required String pin,
  }) async {
    try {
      final previousSelectedStudentId = _guardianSession?.selectedStudentId;
      final result = await _guardianAuthService.loginGuardian(
        schoolPublicId: schoolPublicId,
        cpf: cpf,
        pin: pin,
      );

      if (!result.isAuthenticated || result.session == null) {
        return result;
      }

      _user = null;
      final resolvedSession = result.session!.copyWith(
        selectedStudentId: _pickGuardianSelectedStudentId(
          result.session!,
          preferredStudentId: previousSelectedStudentId,
        ),
      );
      _guardianSession = resolvedSession;
      _token = resolvedSession.token;
      _sessionPrincipal = 'guardian';

      await _persistGuardianSession();

      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('❌ [AuthProvider] Erro no login do responsavel: $e');
      rethrow;
    }
  }
}
