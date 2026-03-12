import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/model/registration_request_model.dart';
import 'package:academyhub_mobile/services/enrollment_service.dart';
import 'package:academyhub_mobile/services/student_service.dart'; // Importação estava errada no seu snippet
import 'package:academyhub_mobile/services/registration_request_service.dart';
import 'package:flutter/material.dart';

/// Provider específico para a tela de Gestão de Participantes.
class ParticipantsDashboardProvider with ChangeNotifier {
  // --- Serviços ---
  final StudentService _studentService = StudentService();
  final EnrollmentService _enrollmentService = EnrollmentService();
  final RegistrationRequestService _requestService =
      RegistrationRequestService();

  // --- Cache de Dados (Memória) ---
  List<Student> _students = [];
  List<Enrollment> _activeEnrollments = [];
  List<RegistrationRequest> _requests = [];

  // --- Estado da UI ---
  bool _isLoading = false;
  String? _error;

  // --- Getters ---
  List<Student> get students => _students;
  List<Enrollment> get activeEnrollments => _activeEnrollments;
  List<RegistrationRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Helper: Verifica se já existem dados em memória para exibição imediata
  bool get hasData => _students.isNotEmpty || _requests.isNotEmpty;

  /// Helper: Mapa O(1) para verificar status de matrícula rapidamente
  Map<String, Enrollment> get activeEnrollmentMap {
    // Atenção: Depende da estrutura do seu EnrollmentModel.
    // Se Enrollment tiver studentId direto, use e.studentId.
    // Se tiver objeto Student, use e.student.id.
    // Vou assumir student.id baseado no seu código anterior.
    return {for (var e in _activeEnrollments) e.student.id: e};
  }

  /// Estratégia SWR:
  Future<void> fetchDashboardData(String token,
      {bool forceRefresh = false}) async {
    if (!hasData || forceRefresh) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // Busca paralela para performance
      final results = await Future.wait([
        _studentService.getStudents(token),
        _enrollmentService.getEnrollments(token, filter: {'status': 'Ativa'}),

        // [CORREÇÃO CRÍTICA]: Chama o novo método que traz TUDO (Pendente, Aprovado, Rejeitado)
        _requestService.getAllRequests(token),
      ]);

      // Processamento dos dados
      var rawStudents = List<Student>.from(results[0] as List<Student>);
      _students = rawStudents.reversed.toList();

      _activeEnrollments =
          List<Enrollment>.from(results[1] as List<Enrollment>);

      var rawRequests = List<RegistrationRequest>.from(
          results[2] as List<RegistrationRequest>);

      // Ordenação e armazenamento
      _requests = rawRequests.reversed.toList();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      debugPrint("Erro Dashboard Provider: $_error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atualiza apenas as solicitações (Ex: via WebSocket)
  Future<void> refreshRequestsOnly(String token) async {
    try {
      // [CORREÇÃO]: Usa o método novo aqui também
      final newRequests = await _requestService.getAllRequests(token);
      _requests = newRequests.reversed.toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Erro silent refresh requests: $e");
    }
  }

  /// Remove item localmente
  /// NOTA: Com a nova lógica de abas (Histórico), talvez você não queira remover da lista,
  /// mas sim alterar o status do objeto para 'APPROVED'/'REJECTED' para ele trocar de aba.
  void removeRequestLocally(String requestId) {
    // Opção 1: Remover (o item some da tela até o próximo refresh)
    // _requests.removeWhere((r) => r.id == requestId);

    // Opção 2 (Recomendada): Forçar refresh via API no controlador da tela
    // O método na ScreenParticipantes já chama _initData() após aprovar,
    // então o refresh acontecerá automaticamente.
    // Manteremos a remoção por compatibilidade com a UI otimista se desejar:
    _requests.removeWhere((r) => r.id == requestId);
    notifyListeners();
  }
}
