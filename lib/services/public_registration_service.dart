import 'dart:convert';

import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/public_enrollment_offer_model.dart';
import 'package:academyhub_mobile/model/public_registration_class_model.dart';
import 'package:http/http.dart' as http;

class PublicRegistrationException implements Exception {
  final String message;

  const PublicRegistrationException(this.message);

  @override
  String toString() => message;
}

class PublicRegistrationService {
  Future<PublicRegistrationSchoolContext> fetchPublicContext(
    String schoolId,
  ) async {
    final url = Uri.parse(
      '${ApiConfig.apiUrl}/registration-requests/public/$schoolId/context',
    );

    try {
      final response = await http.get(
        url,
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw PublicRegistrationException(_extractErrorMessage(
          response.body,
          fallback: 'Não foi possível carregar os dados da escola.',
        ));
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const PublicRegistrationException(
          'Os dados da escola não vieram no formato esperado.',
        );
      }

      final rawLogoUrl = decoded['school'] is Map<String, dynamic>
          ? (decoded['school'] as Map<String, dynamic>)['logoUrl']?.toString()
          : decoded['logoUrl']?.toString();

      return PublicRegistrationSchoolContext.fromJson(
        decoded,
        fallbackId: schoolId,
        resolvedLogoUrl: _resolveLogoUrl(rawLogoUrl),
      );
    } on PublicRegistrationException {
      rethrow;
    } catch (_) {
      throw const PublicRegistrationException(
        'Não conseguimos conectar agora. Tente novamente em instantes.',
      );
    }
  }

  Future<List<PublicRegistrationClassModel>> fetchPublicClasses(
    String schoolId,
  ) async {
    final url = Uri.parse(
      '${ApiConfig.apiUrl}/registration-requests/public/$schoolId/classes',
    );

    try {
      final response = await http.get(
        url,
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw PublicRegistrationException(_extractErrorMessage(
          response.body,
          fallback: 'Não foi possível carregar as turmas desta escola.',
        ));
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) {
        throw const PublicRegistrationException(
          'A lista de turmas não veio no formato esperado.',
        );
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PublicRegistrationClassModel.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList();
    } on PublicRegistrationException {
      rethrow;
    } catch (_) {
      throw const PublicRegistrationException(
        'Não conseguimos conectar agora. Tente novamente em instantes.',
      );
    }
  }

  Future<List<PublicEnrollmentOfferModel>> fetchPublicEnrollmentOffers({
    required String schoolId,
    required String classId,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.apiUrl}/registration-requests/public/$schoolId/offers',
    ).replace(queryParameters: {'classId': classId});

    try {
      final response = await http.get(
        url,
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw PublicRegistrationException(_extractErrorMessage(
          response.body,
          fallback:
              'Não foi possível carregar as opções de permanência desta turma.',
        ));
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) {
        throw const PublicRegistrationException(
          'A lista de opções de permanência não veio no formato esperado.',
        );
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PublicEnrollmentOfferModel.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList();
    } on PublicRegistrationException {
      rethrow;
    } catch (_) {
      throw const PublicRegistrationException(
        'Não conseguimos conectar agora. Você pode continuar com meio período ou tentar novamente.',
      );
    }
  }

  Future<void> submitRegistrationRequest(Map<String, dynamic> data) async {
    final url = Uri.parse(
      '${ApiConfig.apiUrl}/registration-requests/public/submit',
    );

    try {
      final response = await http.post(
        url,
        headers: const {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode != 201) {
        throw PublicRegistrationException(_extractErrorMessage(
          response.body,
          fallback: 'Não foi possível enviar a solicitação.',
        ));
      }
    } on PublicRegistrationException {
      rethrow;
    } catch (_) {
      throw const PublicRegistrationException(
        'Falha de conexão. Confira sua internet e tente novamente.',
      );
    }
  }

  String _extractErrorMessage(
    String responseBody, {
    required String fallback,
  }) {
    try {
      final decoded = json.decode(responseBody);
      if (decoded is Map && decoded['message'] != null) {
        final message = decoded['message'].toString().trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {
      return fallback;
    }

    return fallback;
  }

  String? _resolveLogoUrl(String? rawLogoUrl) {
    final value = rawLogoUrl?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '${ApiConfig.baseUrl}$value';
    }
    return value;
  }
}
