import 'dart:convert';

import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import 'package:academyhub_mobile/services/guardian_session_exception.dart';
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

      final responseData = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      }

      final sessionException = guardianSessionExceptionFromResponse(
        statusCode: response.statusCode,
        payload: responseData,
      );
      if (sessionException != null) {
        throw sessionException;
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

  Future<GuardianPinSetupResult> linkGuardianStudentWithExistingPin({
    required String challengeId,
    required String verificationToken,
    required String pin,
  }) async {
    final response = await _post(
      '/guardian-auth/first-access/link-existing-account',
      payload: {
        'challengeId': challengeId,
        'verificationToken': verificationToken,
        'pin': pin,
      },
    );

    return GuardianPinSetupResult.fromJson(response);
  }

  Future<Map<String, dynamic>> _postPinRecovery(
    String path, {
    required Map<String, dynamic> payload,
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

      throw GuardianPinRecoveryException(
        (responseData['message'] ??
                'Não foi possível concluir a recuperação do PIN.')
            .toString(),
        code: responseData['code']?.toString(),
        statusCode: response.statusCode,
      );
    } on GuardianPinRecoveryException {
      rethrow;
    } on Exception {
      throw const GuardianPinRecoveryException(
        'Não foi possível conectar ao servidor.',
      );
    }
  }

  Future<GuardianPinRecoveryStartResult> startPinRecovery({
    required String cpf,
    required String studentFullName,
    required String studentBirthDate,
    required String guardianBirthDate,
    String? schoolPublicId,
  }) async {
    final payload = <String, dynamic>{
      'cpf': cpf,
      'studentFullName': studentFullName,
      'studentBirthDate': studentBirthDate,
      'guardianBirthDate': guardianBirthDate,
    };
    if ((schoolPublicId ?? '').trim().isNotEmpty) {
      payload['schoolPublicId'] = schoolPublicId!.trim();
    }

    final response = await _postPinRecovery(
      '/guardian-auth/pin-recovery/start',
      payload: payload,
    );
    return GuardianPinRecoveryStartResult.fromJson(response);
  }

  Future<GuardianPinRecoveryResult> completePinRecovery({
    required String challengeId,
    required String verificationToken,
    required String newPin,
  }) async {
    final response = await _postPinRecovery(
      '/guardian-auth/pin-recovery/complete',
      payload: {
        'challengeId': challengeId,
        'verificationToken': verificationToken,
        'newPin': newPin,
      },
    );
    return GuardianPinRecoveryResult.fromJson(response);
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

  Future<Map<String, dynamic>> getGuardianInvoices({
    required String token,
    String? studentId,
  }) {
    final normalizedStudentId = (studentId ?? '').trim();
    return _getAuthorized(
      '/guardian-auth/invoices',
      token: token,
      queryParameters: normalizedStudentId.isEmpty
          ? null
          : {'studentId': normalizedStudentId},
    );
  }

  Future<List<int>> downloadGuardianBatchPdf({
    required String token,
    required List<String> invoiceIds,
    String? studentId,
  }) async {
    final response = await http.post(
      _buildUri('/guardian-auth/invoices/batch-print'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'invoiceIds': invoiceIds,
        if ((studentId ?? '').trim().isNotEmpty) 'studentId': studentId!.trim(),
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    String message = 'Não foi possível gerar o PDF do boleto.';
    Map<String, dynamic> responseData = const {};
    try {
      responseData = _decodeResponse(response);
      message = (responseData['message'] ?? message).toString();
    } catch (_) {}

    final sessionException = guardianSessionExceptionFromResponse(
      statusCode: response.statusCode,
      payload: responseData,
      fallbackMessage: message,
    );
    if (sessionException != null) {
      throw sessionException;
    }

    throw Exception(message);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (body.trim().isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'data': decoded};
  }
}
