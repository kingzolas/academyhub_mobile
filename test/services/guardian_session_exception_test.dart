import 'package:academyhub_mobile/services/guardian_session_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guardianSessionExceptionFromResponse', () {
    test('treats 401 as guardian session failure and preserves details', () {
      final exception = guardianSessionExceptionFromResponse(
        statusCode: 401,
        payload: {
          'message': 'Token de responsavel invalido.',
          'code': 'guardian_token_invalid',
        },
      );

      expect(exception, isNotNull);
      expect(exception!.statusCode, 401);
      expect(exception.message, 'Token de responsavel invalido.');
      expect(exception.code, 'guardian_token_invalid');
      expect(exception.isGuardianAuthFailure, isTrue);
    });

    test('detects explicit guardian token codes on 403', () {
      final exception = guardianSessionExceptionFromResponse(
        statusCode: 403,
        payload: {
          'message': 'Sessao expirada.',
          'code': 'guardian_token_expired',
        },
      );

      expect(exception, isNotNull);
      expect(exception!.code, 'guardian_token_expired');
    });

    test('detects accented guardian token messages on 403', () {
      final exception = guardianSessionExceptionFromResponse(
        statusCode: 403,
        payload: {
          'message': 'Token de respons\u00e1vel inv\u00e1lido.',
        },
      );

      expect(exception, isNotNull);
    });

    test('does not treat ordinary 403 permission errors as logout', () {
      final exception = guardianSessionExceptionFromResponse(
        statusCode: 403,
        payload: {
          'message': 'Responsavel sem autorizacao para acessar este documento.',
        },
      );

      expect(exception, isNull);
    });

    test('does not treat ordinary server errors as logout', () {
      final exception = guardianSessionExceptionFromResponse(
        statusCode: 500,
        payload: {
          'message': 'Falha interna ao carregar dados.',
        },
      );

      expect(exception, isNull);
    });
  });
}
