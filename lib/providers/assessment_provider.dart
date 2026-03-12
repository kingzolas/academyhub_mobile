import 'package:flutter/material.dart';
import '../model/assessment_models.dart';
import '../services/assessment_service.dart';
import '../services/assessment_attempt_service.dart';

class AssessmentProvider with ChangeNotifier {
  final AssessmentService _service = AssessmentService();
  final AssessmentAttemptService _attemptService = AssessmentAttemptService();

  List<Assessment> _assessments = [];
  List<Assessment> get assessments => _assessments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Busca avaliações de uma turma
  Future<void> fetchAssessmentsByClass(String classId) async {
    _setLoading(true);
    try {
      _assessments = await _service.getByClass(classId);
      // Ordena: Drafts primeiro, depois Publicadas (mais recentes primeiro)
      _assessments.sort((a, b) {
        if (a.status == 'DRAFT' && b.status != 'DRAFT') return -1;
        if (a.status != 'DRAFT' && b.status == 'DRAFT') return 1;
        return (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now());
      });
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Cria Rascunho com IA
  Future<Assessment?> createDraftWithAI({
    required String topic,
    required String difficulty,
    required int quantity,
    required String classId,
    required String subjectId,
    String? description,
  }) async {
    _setLoading(true);
    try {
      final newAssessment = await _service.createDraft(
        topic: topic,
        difficulty: difficulty,
        quantity: quantity,
        classId: classId,
        subjectId: subjectId,
        description: description,
      );
      // Adiciona na lista localmente para feedback imediato
      _assessments.insert(0, newAssessment);
      notifyListeners();
      return newAssessment;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // --- MÉTODO NOVO CORRIGIDO ---
  // Este método unifica a atualização de status
  Future<bool> updateAssessmentStatus(
      String assessmentId, String newStatus) async {
    _setLoading(true);
    try {
      // Se o status for PUBLICAR, chamamos o serviço de publicação existente
      if (newStatus == 'PUBLISHED') {
        await _service.publishAssessment(assessmentId);
      } else {
        // Futuramente, se tiver um endpoint para fechar prova, adicione aqui:
        // await _service.closeAssessment(assessmentId);
        throw UnimplementedError(
            "Status $newStatus ainda não implementado no serviço");
      }

      // Atualiza a lista localmente para refletir a mudança na UI imediatamente
      final index = _assessments.indexWhere((a) => a.id == assessmentId);
      if (index != -1) {
        // Recarrega a lista da turma para garantir consistência
        await fetchAssessmentsByClass(_assessments[index].classId!);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Mantive este método para compatibilidade, caso use em outro lugar
  Future<bool> publishAssessment(String assessmentId) async {
    return updateAssessmentStatus(assessmentId, 'PUBLISHED');
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
