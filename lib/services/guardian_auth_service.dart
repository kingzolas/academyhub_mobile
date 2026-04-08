import 'dart:convert';

import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import 'package:http/http.dart' as http;

class GuardianAuthService {
  Uri _buildUri(String path) => Uri.parse('${ApiConfig.apiUrl}$path');

  Future<Map<String, dynamic>> _getAuthorized(
    String path, {
    required String token,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await http.get(
        _buildUri(path).replace(queryParameters: queryParameters),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData =
          jsonDecode(response.body.isEmpty ? '{}' : response.body)
              as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      }

      throw Exception(
        (responseData['message'] ?? 'Não foi possível concluir a operação.')
            .toString(),
      );
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Não foi possível conectar ao servidor.');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> payload,
    Set<int> allowedStatusCodes = const {},
  }) async {
    try {
      final response = await http.post(
        _buildUri(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final responseData =
          jsonDecode(response.body.isEmpty ? '{}' : response.body)
              as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      }

      if (allowedStatusCodes.contains(response.statusCode)) {
        return responseData;
      }

      throw Exception(
        (responseData['message'] ?? 'Não foi possível concluir a operação.')
            .toString(),
      );
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Não foi possível conectar ao servidor.');
    }
  }

  Future<GuardianFirstAccessStartResult> startGuardianFirstAccess({
    String? schoolPublicId,
    required String studentFullName,
    required String birthDate,
  }) async {
    final payload = <String, dynamic>{
      'studentFullName': studentFullName,
      'birthDate': birthDate,
    };

    if ((schoolPublicId ?? '').trim().isNotEmpty) {
      payload['schoolPublicId'] = schoolPublicId!.trim();
    }

    final response = await _post(
      '/guardian-auth/first-access/start',
      payload: payload,
      allowedStatusCodes: const {409},
    );

    return GuardianFirstAccessStartResult.fromJson(response);
  }

  Future<GuardianVerificationResult> verifyGuardianResponsible({
    required String challengeId,
    required String optionId,
    required String cpf,
  }) async {
    final response = await _post(
      '/guardian-auth/first-access/verify-responsible',
      payload: {
        'challengeId': challengeId,
        'optionId': optionId,
        'cpf': cpf,
      },
    );

    return GuardianVerificationResult.fromJson(response);
  }

  Future<GuardianPinSetupResult> setGuardianPin({
    required String challengeId,
    required String verificationToken,
    required String pin,
  }) async {
    final response = await _post(
      '/guardian-auth/first-access/set-pin',
      payload: {
        'challengeId': challengeId,
        'verificationToken': verificationToken,
        'pin': pin,
      },
    );

    return GuardianPinSetupResult.fromJson(response);
  }

  Future<GuardianLoginResult> loginGuardian({
    String? schoolPublicId,
    required String cpf,
    required String pin,
  }) async {
    final payload = <String, dynamic>{
      'identifier': cpf,
      'pin': pin,
    };

    if ((schoolPublicId ?? '').trim().isNotEmpty) {
      payload['schoolPublicId'] = schoolPublicId!.trim();
    }

    final response = await _post(
      '/guardian-auth/login',
      payload: payload,
      allowedStatusCodes: const {409},
    );

    return GuardianLoginResult.fromJson(
      response,
      schoolPublicId: schoolPublicId,
    );
  }

  Future<GuardianPortalHomeData> getGuardianPortalHome({
    required String token,
    String? studentId,
  }) async {
    final normalizedStudentId = (studentId ?? '').trim();
    final response = await _getAuthorized(
      '/guardian-auth/portal/home',
      token: token,
      queryParameters: normalizedStudentId.isEmpty
          ? null
          : {'studentId': normalizedStudentId},
    );

    return GuardianPortalHomeData.fromJson(response);
  }

  Future<GuardianScheduleData> getGuardianSchedule({
    required String token,
    required String studentId,
  }) async {
    final response = await _getAuthorized(
      '/guardian-auth/students/$studentId/schedule',
      token: token,
    );

    return GuardianScheduleData.fromJson(response);
  }

  Future<GuardianAttendanceScreenData> getGuardianAttendance({
    required String token,
    required String studentId,
  }) async {
    final response = await _getAuthorized(
      '/guardian-auth/students/$studentId/attendance',
      token: token,
    );

    return GuardianAttendanceScreenData.fromJson(response);
  }

  Future<GuardianActivitiesScreenData> getGuardianActivities({
    required String token,
    required String studentId,
  }) async {
    final response = await _getAuthorized(
      '/guardian-auth/students/$studentId/activities',
      token: token,
    );

    return GuardianActivitiesScreenData.fromJson(response);
  }
}
