import 'package:flutter/foundation.dart';
import 'package:academyhub_mobile/model/schoolyear_model.dart';
import 'package:academyhub_mobile/model/term_model.dart';
import 'package:academyhub_mobile/services/schoolyear_service.dart';
import 'package:academyhub_mobile/services/term_service.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';

class AcademicCalendarProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  final SchoolYearService _schoolYearService = SchoolYearService();
  final TermService _termService = TermService();

  AcademicCalendarProvider(this._authProvider) {
    // Opcional: Se seu AuthProvider notifica sobre login,
    // você pode ouvir aqui para carregar os anos letivos.
  }

  String? get _token => _authProvider.token;

  List<SchoolYearModel> _schoolYears = [];
  List<SchoolYearModel> get schoolYears => _schoolYears;

  List<TermModel> _terms = [];
  List<TermModel> get terms => _terms;

  SchoolYearModel? _selectedSchoolYear;
  SchoolYearModel? get selectedSchoolYear => _selectedSchoolYear;

  bool _isLoadingYears = false;
  bool get isLoadingYears => _isLoadingYears;

  bool _isLoadingTerms = false;
  bool get isLoadingTerms => _isLoadingTerms;

  String? _error;
  String? get error => _error;

  void clearError() {
    _error = null;
  }

  // [REMOVIDO] _setLoading e _setError
  // É mais claro e seguro definir _isLoadingYears e _isLoadingTerms
  // separadamente dentro de cada método.

  /// Busca todos os anos letivos (ex: 2024, 2025)
  /// [AJUSTADO] Este método agora SÓ busca os anos letivos.
  Future<void> fetchSchoolYears() async {
    _isLoadingYears = true;
    _error = null;
    notifyListeners();

    if (_token == null) {
      _error = "Usuário não autenticado.";
      _isLoadingYears = false;
      notifyListeners();
      return;
    }

    try {
      _schoolYears = await _schoolYearService.find(_token!, {});
      _schoolYears.sort((a, b) => b.year.compareTo(a.year));

      // [REMOVIDO] Não vamos mais selecionar um ano ou buscar períodos aqui.
      // A tela principal (SchoolYearScreen) só precisa da lista.

      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingYears = false;
      notifyListeners();
    }
  }

  /// [AJUSTADO] Este método agora SÓ define o estado.
  /// Ele não busca mais dados na rede.
  void selectSchoolYear(SchoolYearModel schoolYear) {
    _selectedSchoolYear = schoolYear;
    _terms = []; // Limpa os termos antigos
    _error = null;
    notifyListeners();
  }

  /// [NOVO MÉTODO - CORRIGE O ERRO 1]
  /// Busca os períodos (bimestres) APENAS para o ano já selecionado.
  /// Chamado pelo SchoolYearDetailsPopup.
  Future<void> fetchTermsForSelectedYear() async {
    if (_token == null) {
      _error = "Usuário não autenticado.";
      notifyListeners();
      return;
    }
    if (_selectedSchoolYear == null) {
      _error = "Nenhum ano letivo selecionado para buscar períodos.";
      notifyListeners();
      return;
    }

    _isLoadingTerms = true;
    _error = null;
    notifyListeners(); // Mostra o loading no popup

    try {
      _terms = await _termService
          .find(_token!, {'schoolYearId': _selectedSchoolYear!.id});
      _terms.sort((a, b) => a.startDate.compareTo(b.startDate));
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingTerms = false;
      notifyListeners(); // Atualiza o popup com os dados ou erro
    }
  }

  /// Cria um novo ano letivo
  Future<void> createSchoolYear(Map<String, dynamic> data) async {
    if (_token == null) throw Exception("Usuário não autenticado.");

    // [AJUSTADO] Usa o loading específico de ANOS
    _isLoadingYears = true;
    _error = null;
    notifyListeners();

    try {
      await _schoolYearService.create(_token!, data);
      await fetchSchoolYears(); // Recarrega a lista de anos
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      throw Exception('Falha ao criar Ano Letivo: $_error');
    } finally {
      _isLoadingYears = false;
      notifyListeners();
    }
  }

  /// [NOVO MÉTODO - CORRIGE O ERRO 2]
  /// Atualiza um ano letivo existente
  Future<void> updateSchoolYear(String id, Map<String, dynamic> data) async {
    if (_token == null) throw Exception("Usuário não autenticado.");

    _isLoadingYears = true;
    _error = null;
    notifyListeners();

    try {
      await _schoolYearService.update(_token!, id, data);
      await fetchSchoolYears(); // Recarrega a lista
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      throw Exception('Falha ao atualizar Ano Letivo: $_error');
    } finally {
      _isLoadingYears = false;
      notifyListeners();
    }
  }

  /// [NOVO MÉTODO] Deleta um ano letivo
  Future<void> deleteSchoolYear(String id) async {
    if (_token == null) throw Exception("Usuário não autenticado.");

    _isLoadingYears = true;
    _error = null;
    notifyListeners();

    try {
      await _schoolYearService.delete(_token!, id);
      // Remove localmente para resposta rápida da UI
      _schoolYears.removeWhere((year) => year.id == id);
      if (_selectedSchoolYear?.id == id) {
        _selectedSchoolYear = null;
        _terms = [];
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      throw Exception('Falha ao deletar Ano Letivo: $_error');
    } finally {
      _isLoadingYears = false;
      notifyListeners();
    }
  }

  /// Cria um novo período (bimestre/férias)
  Future<void> createTerm(Map<String, dynamic> data) async {
    if (_token == null) throw Exception("Usuário não autenticado.");

    // [AJUSTADO] Usa o loading específico de TERMOS
    _isLoadingTerms = true;
    _error = null;
    notifyListeners();

    try {
      await _termService.create(_token!, data);
      // [AJUSTADO] Recarrega apenas os termos do ano selecionado
      await fetchTermsForSelectedYear();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      throw Exception('Falha ao criar Período: $_error');
    } finally {
      _isLoadingTerms = false;
      notifyListeners();
    }
  }

  /// [NOVO MÉTODO] Atualiza um período existente
  Future<void> updateTerm(String id, Map<String, dynamic> data) async {
    if (_token == null) throw Exception("Usuário não autenticado.");

    _isLoadingTerms = true;
    _error = null;
    notifyListeners();

    try {
      await _termService.update(_token!, id, data);
      await fetchTermsForSelectedYear(); // Recarrega os termos
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      throw Exception('Falha ao atualizar Período: $_error');
    } finally {
      _isLoadingTerms = false;
      notifyListeners();
    }
  }

  /// [NOVO MÉTODO] Deleta um período
  Future<void> deleteTerm(String id) async {
    if (_token == null) throw Exception("Usuário não autenticado.");

    _isLoadingTerms = true;
    _error = null;
    notifyListeners();

    try {
      await _termService.delete(_token!, id);
      // Remove localmente
      _terms.removeWhere((term) => term.id == id);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      throw Exception('Falha ao deletar Período: $_error');
    } finally {
      _isLoadingTerms = false;
      notifyListeners();
    }
  }
}
