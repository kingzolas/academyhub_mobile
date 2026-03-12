import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Models
import 'package:academyhub_mobile/model/horario_model.dart';
import 'package:academyhub_mobile/model/evento_model.dart';
import 'package:academyhub_mobile/model/term_model.dart';
import 'package:academyhub_mobile/model/course_load_model.dart';

// Services
import 'package:academyhub_mobile/services/horario_service.dart';
import 'package:academyhub_mobile/services/evento_service.dart';
import 'package:academyhub_mobile/services/term_service.dart';
import 'package:academyhub_mobile/services/course_load_service.dart';

// Provider de Autenticação
import 'package:academyhub_mobile/providers/auth_provider.dart';

class ScheduleProvider with ChangeNotifier {
  final AuthProvider _authProvider;

  // Services
  final HorarioService _horarioService = HorarioService();
  final EventoService _eventoService = EventoService();
  final TermService _termService = TermService();
  final CourseLoadService _courseLoadService = CourseLoadService();

  // Construtor
  ScheduleProvider(this._authProvider);

  // Helper para pegar token
  String? get _token => _authProvider.token;

  // --- Estado Interno ---
  String? _currentClassId;
  String? _currentTermId;
  TermModel? _currentTerm;

  // Variável para armazenar o termo selecionado manualmente
  TermModel? _selectedTerm;

  List<HorarioModel> _horarios = [];
  List<EventoModel> _eventos = [];
  List<CourseLoadModel> _cargas = [];

  bool _isLoading = false;
  String? _error;

  // --- Getters Públicos ---
  List<HorarioModel> get horarios => List.unmodifiable(_horarios);
  List<EventoModel> get eventos => List.unmodifiable(_eventos);
  List<CourseLoadModel> get cargas => List.unmodifiable(_cargas);

  // Getter inteligente: Retorna o selecionado se houver, senão o atual (fallback)
  TermModel? get currentTerm => _selectedTerm ?? _currentTerm;

  // Getter inteligente para o ID do termo usado nas requisições
  String? get currentTermId => _selectedTerm?.id ?? _currentTermId;

  String? get currentClassId => _currentClassId;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Helpers de Estado ---
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? errorMsg) {
    _error = errorMsg?.replaceAll('Exception: ', '');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSchedule() {
    _currentClassId = null;
    _currentTermId = null;
    _currentTerm = null;
    _selectedTerm = null; // Limpa a seleção manual também
    _horarios = [];
    _eventos = [];
    _cargas = [];
    _error = null;
    notifyListeners();
  }

  // --- Lógica de Negócio ---

  Future<TermModel?> _findCurrentTerm(String token) async {
    try {
      final allTerms = await _termService.find(token, {});
      final today = DateTime.now();

      for (var term in allTerms) {
        if (term.tipo == 'Letivo' &&
            (today.isAfter(term.startDate) ||
                isSameDay(today, term.startDate)) &&
            (today.isBefore(term.endDate) || isSameDay(today, term.endDate))) {
          return term;
        }
      }

      // Fallback: Retorna o primeiro período letivo se estivermos nas férias
      final letivos = allTerms.where((t) => t.tipo == 'Letivo').toList();
      if (letivos.isNotEmpty) return letivos.first;

      return null;
    } catch (e) {
      debugPrint('Erro ao buscar período: $e');
      throw Exception('Falha ao determinar o período letivo atual.');
    }
  }

  // --- NOVO MÉTODO PARA O DROPDOWN (PARTE 2 DA SOLUÇÃO) ---
  void selectTerm(TermModel term) {
    _selectedTerm = term;
    // Opcional: Atualizar _currentTermId também para manter sincronia interna se necessário
    _currentTermId = term.id;

    // Se já estivermos visualizando uma turma, recarrega os dados para o novo ano/bimestre
    if (_currentClassId != null) {
      fetchScheduleData(_currentClassId!);
    }
    notifyListeners();
  }
  // ---------------------------------------------------------

  /// Busca TUDO (Horários, Eventos, Cargas) para a tela de Calendário/Horário
  Future<void> fetchScheduleData(String classId) async {
    if (_token == null) {
      _setError("Usuário não autenticado.");
      return;
    }
    final token = _token!;

    _setLoading(true);
    _setError(null);
    _currentClassId = classId;

    try {
      // 1. Garante o Termo Atual (se nenhum foi selecionado manualmente ainda)
      if (_selectedTerm == null && _currentTerm == null) {
        final term = await _findCurrentTerm(token);
        if (term == null) throw Exception('Nenhum período letivo encontrado.');
        _currentTerm = term;
        _currentTermId = term.id;
      }

      // Define qual ID de termo usar (o selecionado tem prioridade)
      final termIdUsado = _selectedTerm?.id ?? _currentTermId;

      if (termIdUsado == null) {
        throw Exception("Não foi possível identificar o ano letivo.");
      }

      // 2. Busca dados em paralelo usando o termo correto
      final results = await Future.wait([
        _horarioService.getHorarios(token,
            filter: {'classId': classId, 'termId': termIdUsado}),
        _eventoService.getEventos(token, filter: {'classId': classId}),
        _eventoService.getEventos(token, filter: {'isSchoolWide': 'true'}),
        _courseLoadService.find(token, termIdUsado, classId),
      ]);

      _horarios = results[0] as List<HorarioModel>;

      final classEvents = results[1] as List<EventoModel>;
      final schoolEvents = results[2] as List<EventoModel>;
      _eventos = [...classEvents, ...schoolEvents];

      _cargas = results[3] as List<CourseLoadModel>;

      // Ordenação
      _horarios.sort((a, b) => a.startTime.compareTo(b.startTime));
      _eventos.sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('Erro no fetchScheduleData: $e');
      _setError(e.toString());
      // Limpa dados para evitar estado inconsistente
      _horarios = [];
      _eventos = [];
      _cargas = [];
    } finally {
      _setLoading(false);
    }
  }

  /// [CORRIGIDO] Busca APENAS horários. Aceita classId opcional para uso na tela de Notas.
  Future<void> fetchHorariosOnly({String? classId}) async {
    if (_token == null) return;

    // Usa o ID passado ou o que está no estado
    final targetClassId = classId ?? _currentClassId;

    // Se não tivermos turma nem termo, tenta buscar o termo primeiro ou aborta
    if (targetClassId == null) return;

    // Se não tiver termo definido, tenta buscar o padrão
    if (_selectedTerm == null && _currentTermId == null) {
      try {
        final term = await _findCurrentTerm(_token!);
        if (term != null) {
          _currentTerm = term;
          _currentTermId = term.id;
        } else {
          return; // Não tem como buscar horário sem termo
        }
      } catch (e) {
        return;
      }
    }

    final termIdUsado = _selectedTerm?.id ?? _currentTermId;

    try {
      _horarios = await _horarioService.getHorarios(_token!, filter: {
        'classId': targetClassId,
        if (termIdUsado != null) 'termId': termIdUsado
      });

      _horarios.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
    } catch (e) {
      debugPrint("Erro fetchHorariosOnly: $e");
      _setError(e.toString());
    }
  }

  /// Busca APENAS eventos (Turma + Escola)
  Future<void> fetchEventosOnly({required String classId}) async {
    if (_token == null) return;

    try {
      final results = await Future.wait([
        _eventoService.getEventos(_token!, filter: {'classId': classId}),
        _eventoService.getEventos(_token!, filter: {'isSchoolWide': 'true'}),
      ]);

      final classEvents = results[0] as List<EventoModel>;
      final schoolEvents = results[1] as List<EventoModel>;

      _eventos = [...classEvents, ...schoolEvents];
      _eventos.sort((a, b) => a.date.compareTo(b.date));

      notifyListeners();
    } catch (e) {
      debugPrint("Erro fetchEventosOnly: $e");
      _setError(e.toString());
    }
  }

  // --- CRUD Actions ---

  Future<void> createHorario(HorarioModel horario) async {
    if (_token == null) throw Exception('Não autenticado.');

    // Garante que o horário criado use o termo que está sendo visualizado
    final termIdParaCriacao = _selectedTerm?.id ?? _currentTermId;

    // Se o model já vier com termId (ex: do formulário), usa ele. Senão injeta o atual.
    // Mas geralmente o formulário já deve pegar o termId do provider.

    await _horarioService.createHorario(horario, _token!);
    await fetchHorariosOnly(classId: horario.classInfo.id);
  }

  Future<void> updateHorario(
      String horarioId, Map<String, dynamic> data) async {
    if (_token == null) throw Exception('Não autenticado.');
    await _horarioService.updateHorario(horarioId, data, _token!);
    // Atualiza a lista atual
    await fetchHorariosOnly(classId: _currentClassId);
  }

  Future<void> deleteHorario(String horarioId) async {
    if (_token == null) throw Exception('Não autenticado.');
    await _horarioService.deleteHorario(horarioId, _token!);
    await fetchHorariosOnly(classId: _currentClassId);
  }

  // --- WebSocket Updates ---

  void addHorarioFromEvent(HorarioModel horario) {
    final termIdUsado = _selectedTerm?.id ?? _currentTermId;

    if (horario.classInfo.id == _currentClassId &&
        horario.termId == termIdUsado) {
      _horarios.add(horario);
      _horarios.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
    }
  }

  void updateHorarioFromEvent(HorarioModel horario) {
    final termIdUsado = _selectedTerm?.id ?? _currentTermId;

    if (horario.classInfo.id == _currentClassId &&
        horario.termId == termIdUsado) {
      final index = _horarios.indexWhere((h) => h.id == horario.id);
      if (index != -1) {
        _horarios[index] = horario;
        _horarios.sort((a, b) => a.startTime.compareTo(b.startTime));
        notifyListeners();
      }
    }
  }

  void removeHorarioFromEvent(HorarioModel horario) {
    if (horario.classInfo.id == _currentClassId) {
      _horarios.removeWhere((h) => h.id == horario.id);
      notifyListeners();
    }
  }

  // Método de compatibilidade (caso o front antigo chame setTerm)
  void setTerm(TermModel term) {
    selectTerm(term);
  }

  // --- Utils ---
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
