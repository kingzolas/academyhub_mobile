import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/horario_model.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/horario_provider.dart';
import 'package:academyhub_mobile/services/class_service.dart';
import 'package:academyhub_mobile/services/horario_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('erro HTTP de horários permanece distinguível de lista vazia', () async {
    final provider = HorarioProvider(horarioService: _FailingHorarioService());

    await provider.fetchHorarios(
      'token-de-teste',
      filter: const {'teacherId': 'teacher-1'},
      debugScreen: 'provider_test',
    );

    expect(provider.horarios, isEmpty);
    expect(provider.error, isNotNull);
    expect(provider.isLoading, isFalse);
  });

  test('erro HTTP de turmas permanece distinguível de lista vazia', () async {
    final provider = ClassProvider(classService: _FailingClassService());

    await provider.fetchClasses('token-de-teste');

    expect(provider.classes, isEmpty);
    expect(provider.error, isNotNull);
    expect(provider.isLoading, isFalse);
  });

  test('resposta vazia válida de turmas não cria estado de erro', () async {
    final provider = ClassProvider(classService: _EmptyClassService());

    await provider.fetchClasses('token-de-teste');

    expect(provider.classes, isEmpty);
    expect(provider.error, isNull);
  });
}

class _FailingHorarioService extends HorarioService {
  @override
  Future<List<HorarioModel>> getHorarios(
    String token, {
    Map<String, String>? filter,
    String debugScreen = 'unknown',
  }) {
    throw Exception('HTTP 500');
  }
}

class _FailingClassService extends ClassService {
  @override
  Future<List<ClassModel>> getAllClasses(
    String? token, {
    Map<String, String>? filter,
  }) {
    throw Exception('HTTP 403');
  }
}

class _EmptyClassService extends ClassService {
  @override
  Future<List<ClassModel>> getAllClasses(
    String? token, {
    Map<String, String>? filter,
  }) async {
    return const [];
  }
}
