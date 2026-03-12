import 'dart:convert';

import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/util/cidades_ibge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:intl/intl.dart' as intl;
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

// Importe seus serviços e configs
import '../../config/api_config.dart';
import '../../services/student_service.dart';

// --- Helper de Decoração (Adaptado para Dark Mode) ---
InputDecoration buildInputDecoration(
    BuildContext context, String label, IconData icon,
    {String? hintText}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // Cores adaptativas
  final Color contentColor =
      isDark ? Colors.grey.shade400 : Colors.grey.shade700;
  final Color fillColor =
      isDark ? Colors.grey.shade800 : const Color(0xffD0DFE9);
  final Color borderColor =
      isDark ? Colors.grey.shade600 : Colors.grey.shade300;

  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(
        color: contentColor.withOpacity(0.9),
        fontWeight: FontWeight.w500,
        fontSize: 15.sp),
    hintText: hintText,
    hintStyle: GoogleFonts.inter(
        color: contentColor.withOpacity(0.7), fontSize: 15.sp),
    filled: true,
    fillColor: fillColor,
    prefixIcon: Icon(icon, color: contentColor, size: 20.sp),
    contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 15.w),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: borderColor, width: 0.8)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: borderColor, width: 1.0)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(
            color: isDark ? Colors.blueAccent : const Color(0xFF007AFF),
            width: 1.8)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.2)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.8)),
    isDense: true,
  );
}

class CadastroAlunoDialog extends StatefulWidget {
  final VoidCallback? onSaveSuccess;

  const CadastroAlunoDialog({super.key, this.onSaveSuccess});

  @override
  State<CadastroAlunoDialog> createState() => _CadastroAlunoDialogState();
}

class _CadastroAlunoDialogState extends State<CadastroAlunoDialog> {
  // --- Controles de Página ---
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // --- Chaves de Formulário ---
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  // --- LÓGICA FINANCEIRA / IDADE ---
  bool _isUnderAge = false; // Se é menor de 18
  bool _isStudentResponsible = false; // Se o aluno paga a conta

  // --- DADOS DO ALUNO ---
  final _studentFullNameController = TextEditingController();
  final _studentBirthDateController = TextEditingController();
  final _studentNationalityController =
      TextEditingController(text: 'Brasileira');
  final _studentPhoneController = TextEditingController();
  final _studentEmailController = TextEditingController();
  final _studentRgController = TextEditingController();
  final _studentCpfController = TextEditingController();
  String? _studentGender;
  String? _studentRace;

  // --- ENDEREÇO ---
  final _addressStreetController = TextEditingController();
  final _addressNeighborhoodController = TextEditingController();
  final _addressNumberController = TextEditingController();
  final _addressBlockController = TextEditingController();
  final _addressLotController = TextEditingController();
  StateModel? _selectedState;
  CityModel? _selectedCity;

  // --- SAÚDE ---
  bool _hasHealthProblem = false;
  final _healthProblemDetailsController = TextEditingController();
  bool _takesMedication = false;
  final _medicationDetailsController = TextEditingController();
  bool _hasDisability = false;
  final _disabilityDetailsController = TextEditingController();
  bool _hasAllergy = false;
  final _allergyDetailsController = TextEditingController();
  bool _hasMedicationAllergy = false;
  final _medicationAllergyDetailsController = TextEditingController();
  bool _hasVisionProblem = false;
  final _visionProblemDetailsController = TextEditingController();
  final _feverMedicationController = TextEditingController();
  final _foodObservationsController = TextEditingController();

  // --- TUTORES E AUTORIZADOS ---
  final List<Map<String, dynamic>> _tutors = [];
  final List<Map<String, TextEditingController>> _authorizedPickups = [];

  // --- SERVIÇOS ---
  final StudentService _studentService = StudentService();
  final LocationService _locationService = LocationService();

  bool _isLoading = false;
  List<StateModel> _states = [];
  List<CityModel> _cities = [];
  bool _isLoadingCities = false;

  final _stateSearchController = TextEditingController();
  final _citySearchController = TextEditingController();

  // --- MÁSCARAS ---
  final _dateMask = MaskTextInputFormatter(
      mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
  final _phoneMask = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _rgMask = MaskTextInputFormatter(
      mask: '##.###.###-#', filter: {"#": RegExp(r'[0-9A-Za-z]')});

  @override
  void initState() {
    super.initState();
    _fetchStates();

    // Inicializa listas
    if (_authorizedPickups.isEmpty) _addAuthorizedPerson();
    if (_tutors.isEmpty) _addTutor();

    // Listener para recalcular idade quando a data muda
    _studentBirthDateController.addListener(_calculateAgeLogic);
  }

  // --- LÓGICA DE CÁLCULO DE IDADE ---
  void _calculateAgeLogic() {
    final text = _studentBirthDateController.text;
    if (text.length == 10) {
      try {
        final birthDate = intl.DateFormat('dd/MM/yyyy').parseStrict(text);
        final today = DateTime.now();
        int age = today.year - birthDate.year;

        if (today.month < birthDate.month ||
            (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }

        setState(() {
          if (age < 18) {
            _isUnderAge = true;
            _isStudentResponsible = false;
          } else {
            _isUnderAge = false;
          }
        });
      } catch (e) {
        // Data inválida, ignora
      }
    }
  }

  void _addTutor() {
    if (_tutors.length < 2) {
      setState(() {
        _tutors.add({
          'fullName': TextEditingController(),
          'birthDate': TextEditingController(),
          'nationality': TextEditingController(text: 'Brasileira'),
          'phone': TextEditingController(),
          'rg': TextEditingController(),
          'cpf': TextEditingController(),
          'email': TextEditingController(),
          'gender': null,
          'relationship': null,
          'isAddressSame': true,
        });
      });
    }
  }

  void _removeTutor(int index) {
    setState(() {
      _tutors[index]['fullName'].dispose();
      _tutors[index]['birthDate'].dispose();
      _tutors[index]['nationality'].dispose();
      _tutors[index]['phone'].dispose();
      _tutors[index]['rg'].dispose();
      _tutors[index]['cpf'].dispose();
      _tutors[index]['email'].dispose();
      _tutors.removeAt(index);
    });
  }

  void _addAuthorizedPerson() {
    if (_authorizedPickups.length < 3) {
      setState(() {
        _authorizedPickups.add({
          'fullName': TextEditingController(),
          'relationship': TextEditingController(),
          'phoneNumber': TextEditingController(),
        });
      });
    }
  }

  void _removeAuthorizedPerson(int index) {
    setState(() {
      _authorizedPickups[index]['fullName']!.dispose();
      _authorizedPickups[index]['relationship']!.dispose();
      _authorizedPickups[index]['phoneNumber']!.dispose();
      _authorizedPickups.removeAt(index);
    });
  }

  Future<void> _fetchStates() async {
    try {
      final states = await _locationService.fetchStates();
      if (mounted) setState(() => _states = states);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erro ao carregar estados: ${e.toString()}"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _fetchCities(StateModel state) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCity = null;
    });
    try {
      final cities = await _locationService.fetchCities(state.id);
      if (mounted)
        setState(() {
          _cities = cities;
          _isLoadingCities = false;
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erro ao carregar cidades: ${e.toString()}"),
          backgroundColor: Colors.red,
        ));
        setState(() => _isLoadingCities = false);
      }
    }
  }

  @override
  void dispose() {
    _studentBirthDateController.removeListener(_calculateAgeLogic);
    _pageController.dispose();
    _studentFullNameController.dispose();
    _studentBirthDateController.dispose();
    _studentNationalityController.dispose();
    _studentPhoneController.dispose();
    _studentEmailController.dispose();
    _studentRgController.dispose();
    _studentCpfController.dispose();
    _addressStreetController.dispose();
    _addressNeighborhoodController.dispose();
    _addressNumberController.dispose();
    _addressBlockController.dispose();
    _addressLotController.dispose();
    _healthProblemDetailsController.dispose();
    _medicationDetailsController.dispose();
    _disabilityDetailsController.dispose();
    _allergyDetailsController.dispose();
    _medicationAllergyDetailsController.dispose();
    _visionProblemDetailsController.dispose();
    _feverMedicationController.dispose();
    _foodObservationsController.dispose();

    for (var tutor in _tutors) {
      (tutor['fullName'] as TextEditingController).dispose();
      (tutor['birthDate'] as TextEditingController).dispose();
      (tutor['nationality'] as TextEditingController).dispose();
      (tutor['phone'] as TextEditingController).dispose();
      (tutor['rg'] as TextEditingController).dispose();
      (tutor['cpf'] as TextEditingController).dispose();
      (tutor['email'] as TextEditingController).dispose();
    }

    _stateSearchController.dispose();
    _citySearchController.dispose();

    for (var controllerMap in _authorizedPickups) {
      controllerMap.forEach((key, controller) => controller.dispose());
    }
    super.dispose();
  }

  void _resetForm() {
    _step1Key.currentState?.reset();
    _step2Key.currentState?.reset();
    _step3Key.currentState?.reset();

    _studentFullNameController.clear();
    _studentBirthDateController.clear();
    _studentNationalityController.text = 'Brasileira';
    _studentPhoneController.clear();
    _studentEmailController.clear();
    _studentRgController.clear();
    _studentCpfController.clear();
    _addressStreetController.clear();
    _addressNeighborhoodController.clear();
    _addressNumberController.clear();
    _addressBlockController.clear();
    _addressLotController.clear();

    _healthProblemDetailsController.clear();
    _medicationDetailsController.clear();
    _disabilityDetailsController.clear();
    _allergyDetailsController.clear();
    _medicationAllergyDetailsController.clear();
    _visionProblemDetailsController.clear();
    _feverMedicationController.clear();
    _foodObservationsController.clear();

    for (var controllerMap in _authorizedPickups) {
      controllerMap.forEach((key, controller) => controller.clear());
    }

    for (var tutor in _tutors) {
      (tutor['fullName'] as TextEditingController).clear();
      (tutor['birthDate'] as TextEditingController).clear();
      (tutor['nationality'] as TextEditingController).text = 'Brasileira';
      (tutor['phone'] as TextEditingController).clear();
      (tutor['rg'] as TextEditingController).clear();
      (tutor['cpf'] as TextEditingController).clear();
      (tutor['email'] as TextEditingController).clear();
    }

    setState(() {
      _studentGender = null;
      _studentRace = null;
      _selectedState = null;
      _selectedCity = null;
      _cities = [];
      _hasHealthProblem = false;
      _takesMedication = false;
      _hasDisability = false;
      _hasAllergy = false;
      _hasMedicationAllergy = false;
      _hasVisionProblem = false;
      _authorizedPickups.clear();
      _addAuthorizedPerson();
      _tutors.clear();
      _addTutor();
      _currentPage = 0;

      // Reset dos estados financeiros
      _isUnderAge = false;
      _isStudentResponsible = false;
    });

    _pageController.jumpToPage(0);
  }

  // --- NAVEGAÇÃO ---
  bool _validateStep(int step) {
    final keys = [_step1Key, _step2Key, _step3Key];
    return keys[step].currentState?.validate() ?? false;
  }

  void _nextPage() {
    if (_validateStep(_currentPage)) {
      if (_currentPage < 2) {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      } else {
        _submitForm();
      }
    }
  }

  void _previousPage() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  Future<void> _selectDate(BuildContext context,
      {required TextEditingController controller,
      DateTime? initialDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = intl.DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  String? _parseDateToISO(String dateString) {
    try {
      return intl.DateFormat('dd/MM/yyyy')
          .parseStrict(dateString)
          .toIso8601String();
    } catch (e) {
      return null;
    }
  }

  void _debugPrintAllFields() {
    debugPrint('--- [DEBUG] DADOS ---');
    debugPrint('Nome: ${_studentFullNameController.text}');
    debugPrint('Resp Financeiro: ${_isStudentResponsible ? "ALUNO" : "TUTOR"}');
  }

  // --- SUBMISSÃO COM VALIDAÇÃO FINANCEIRA ---
  Future<void> _submitForm() async {
    _debugPrintAllFields();

    // Validação de Etapas Visual (para feedback)
    if (!_validateStep(0)) {
      _showError('Verifique os campos de Aluno e Endereço.', 0);
      return;
    }
    if (!_validateStep(1)) {
      _showError('Verifique os campos da Ficha de Saúde.', 1);
      return;
    }

    if (_isStudentResponsible) {
      // Se aluno paga, validações de tutor não são críticas
    } else {
      // Se aluno NÃO paga (menor ou dependente), PRECISA de tutor com CPF.
      if (_tutors.isEmpty) {
        _showError("É necessário cadastrar um Tutor/Responsável.", 2);
        return;
      }
      if ((_tutors[0]['cpf'] as TextEditingController).text.isEmpty) {
        _showError(
            "O CPF do primeiro responsável é obrigatório para cobrança.", 2);
        return;
      }
    }

    if (!_validateStep(2)) {
      _showError('Verifique os campos de Tutor e Autorizados.', 2);
      return;
    }

    setState(() => _isLoading = true);

    final studentAddress = {
      "street": _addressStreetController.text,
      "neighborhood": _addressNeighborhoodController.text,
      "number": _addressNumberController.text,
      "block": _addressBlockController.text,
      "lot": _addressLotController.text,
      "city": _selectedCity?.nome,
      "state": _selectedState?.sigla,
    };

    final authorizedPickupsData = _authorizedPickups
        .where((p) => p['fullName']!.text.isNotEmpty)
        .map((c) => {
              "fullName": c['fullName']!.text,
              "relationship": c['relationship']!.text,
              "phoneNumber": c['phoneNumber']!.text,
            })
        .toList();

    final tutorsData = _tutors.map((tutor) {
      bool isAddressSame = tutor['isAddressSame'] as bool;
      return {
        "fullName": (tutor['fullName'] as TextEditingController).text,
        "birthDate":
            _parseDateToISO((tutor['birthDate'] as TextEditingController).text),
        "gender": tutor['gender'],
        "nationality": (tutor['nationality'] as TextEditingController).text,
        "phoneNumber": (tutor['phone'] as TextEditingController).text,
        "rg": (tutor['rg'] as TextEditingController).text,
        "cpf": (tutor['cpf'] as TextEditingController).text,
        "email": (tutor['email'] as TextEditingController).text,
        "relationship": tutor['relationship'],
        "address": isAddressSame ? studentAddress : studentAddress,
      };
    }).toList();

    final studentData = {
      "fullName": _studentFullNameController.text,
      "birthDate": _parseDateToISO(_studentBirthDateController.text),
      "gender": _studentGender,
      "race": _studentRace,
      "nationality": _studentNationalityController.text,
      "phoneNumber": _studentPhoneController.text,
      "email": _studentEmailController.text,
      "rg": _studentRgController.text,
      "cpf": _studentCpfController.text,
      "address": studentAddress,
      "tutors": tutorsData,
      "financialResp": _isStudentResponsible ? 'STUDENT' : 'TUTOR',
      "healthInfo": {
        "hasHealthProblem": _hasHealthProblem,
        "healthProblemDetails": _healthProblemDetailsController.text,
        "takesMedication": _takesMedication,
        "medicationDetails": _medicationDetailsController.text,
        "hasDisability": _hasDisability,
        "disabilityDetails": _disabilityDetailsController.text,
        "hasAllergy": _hasAllergy,
        "allergyDetails": _allergyDetailsController.text,
        "hasMedicationAllergy": _hasMedicationAllergy,
        "medicationAllergyDetails": _medicationAllergyDetailsController.text,
        "hasVisionProblem": _hasVisionProblem,
        "visionProblemDetails": _visionProblemDetailsController.text,
        "feverMedication": _feverMedicationController.text,
        "foodObservations": _foodObservationsController.text,
      },
      "authorizedPickups": authorizedPickupsData,
    };

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String? authToken = authProvider.token;

    if (authToken == null) {
      _showError('Erro de autenticação! Faça login novamente.', 0);
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _studentService.createStudent(studentData, authToken);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Aluno cadastrado com sucesso!'),
          backgroundColor: const Color(0xff34C759),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
              bottom: 20.h,
              right: 20.w,
              left: MediaQuery.of(context).size.width * 0.7),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ));
      }
      _resetForm();
      widget.onSaveSuccess?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
              bottom: 20.h,
              right: 20.w,
              left: MediaQuery.of(context).size.width * 0.7),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg, int page) {
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  // =======================================================================
  // --- BUILD UI (Dark Mode Adapted) ---
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cores de Background
    final dialogBg = theme.cardColor;
    final headerBg = isDark ? Colors.grey[900] : Colors.black;
    final headerIconColor = Colors.white;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      backgroundColor: dialogBg,
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 15.h),
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: headerBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(PhosphorIcons.student_fill,
                  color: headerIconColor, size: 26.sp),
              SizedBox(width: 12.w),
              Text('Novo Aluno',
                  style: GoogleFonts.sairaCondensed(
                      fontWeight: FontWeight.bold,
                      fontSize: 22.sp,
                      color: headerIconColor)),
            ]),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(),
                tooltip: 'Fechar'),
          ],
        ),
      ),
      content: SizedBox(
        width: 700.w,
        height: 700.h,
        child: Column(
          children: [
            _buildStepIndicator(isDark),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  KeepAlivePage(child: _buildStep1AlunoEndereco(isDark)),
                  KeepAlivePage(child: _buildStep2Saude(isDark)),
                  KeepAlivePage(child: _buildStep3Responsaveis(isDark)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_currentPage > 0)
          TextButton.icon(
            icon: const Icon(PhosphorIcons.arrow_left),
            label: const Text('Voltar'),
            style: TextButton.styleFrom(
                foregroundColor:
                    isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            onPressed: _isLoading ? null : _previousPage,
          )
        else
          const SizedBox.shrink(),
        ElevatedButton.icon(
          icon: _isLoading
              ? SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Icon(
                  _currentPage == 2
                      ? PhosphorIcons.check_circle_fill
                      : PhosphorIcons.arrow_right,
                  size: 18.sp),
          label: Text(_currentPage == 2 ? 'Finalizar Cadastro' : 'Próximo'),
          style: ElevatedButton.styleFrom(
              backgroundColor: (_currentPage == 2
                  ? Colors.green.shade600
                  : const Color(0xFF007AFF)),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
              textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, fontSize: 14.sp)),
          onPressed: _isLoading ? null : _nextPage,
        ),
      ],
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    final titles = ['Aluno e Endereço', 'Ficha de Saúde', 'Responsáveis'];

    // Cores de fundo do indicador
    final bgIndicator = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final borderIndicator =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
      decoration: BoxDecoration(
          color: bgIndicator,
          border: Border(bottom: BorderSide(color: borderIndicator))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(titles.length, (index) {
          bool isActive = index == _currentPage;
          bool isDone = index < _currentPage;

          Color color;
          if (isDone) {
            color = Colors.green.shade600;
          } else if (isActive) {
            color = isDark ? Colors.blueAccent : Colors.blue.shade700;
          } else {
            color = isDark ? Colors.grey.shade500 : Colors.grey.shade500;
          }

          return Column(
            children: [
              Icon(
                  isDone
                      ? PhosphorIcons.check_circle_fill
                      : (isActive
                          ? PhosphorIcons.dots_nine
                          : PhosphorIcons.circle_fill),
                  color: color,
                  size: 16.sp),
              SizedBox(height: 3.h),
              Text(titles[index],
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: color)),
            ],
          );
        }),
      ),
    );
  }

  // --- STEP 1: ALUNO (COM LÓGICA FINANCEIRA ATUALIZADA) ---
  Widget _buildStep1AlunoEndereco(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _step1Key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Dados Pessoais do Aluno', isDark),
            SizedBox(height: 15.h),

            // --- Switch de Responsabilidade Financeira ---
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                  color: _isUnderAge
                      ? (isDark
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.orange.shade50)
                      : (isDark
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.blue.shade50),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                      color: _isUnderAge
                          ? (isDark
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.orange.shade200)
                          : (isDark
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.blue.shade200))),
              child: SwitchListTile(
                title: Text("O aluno é o responsável financeiro?",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text(
                    _isUnderAge
                        ? "Opção bloqueada: Aluno menor de 18 anos."
                        : "Se marcado, o aluno assinará o contrato e receberá as cobranças.",
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600)),
                value: _isStudentResponsible,
                onChanged: _isUnderAge
                    ? null
                    : (val) => setState(() => _isStudentResponsible = val),
                secondary: Icon(
                    _isStudentResponsible
                        ? PhosphorIcons.currency_dollar_bold
                        : PhosphorIcons.users_three_bold,
                    color: isDark ? Colors.white70 : null),
              ),
            ),
            SizedBox(height: 20.h),

            Wrap(
              spacing: 15.w,
              runSpacing: 15.h,
              children: [
                _buildTextField(_studentFullNameController, 'Nome Completo *',
                    icon: PhosphorIcons.user_bold,
                    isRequired: true,
                    isDark: isDark),
                _buildDateField(
                    _studentBirthDateController, 'Data de Nascimento *',
                    onTap: () => _selectDate(context,
                        controller: _studentBirthDateController),
                    isDark: isDark),

                _buildDropdownField<String>(
                    _studentGender,
                    'Gênero *',
                    const [
                      'Masculino',
                      'Feminino',
                      'Outro',
                      'Prefiro não dizer'
                    ],
                    PhosphorIcons.gender_intersex_bold,
                    (val) => setState(() => _studentGender = val),
                    isDark: isDark),
                _buildDropdownField<String>(
                    _studentRace,
                    'Cor/Raça *',
                    const [
                      'Branca',
                      'Preta',
                      'Parda',
                      'Amarela',
                      'Indígena',
                      'Prefiro não dizer'
                    ],
                    PhosphorIcons.paint_brush_bold,
                    (val) => setState(() => _studentRace = val),
                    isDark: isDark),

                _buildTextField(
                    _studentNationalityController, 'Nacionalidade *',
                    icon: PhosphorIcons.globe_bold,
                    isRequired: true,
                    isDark: isDark),

                // [MODIFICADO] Celular e Email OBRIGATÓRIOS se for responsável
                _buildTextField(_studentPhoneController,
                    'Nº de Celular ${_isStudentResponsible ? "*" : "(Opc.)"}',
                    icon: PhosphorIcons.phone_bold,
                    keyboardType: TextInputType.phone,
                    formatters: [_phoneMask],
                    isRequired: _isStudentResponsible,
                    isDark: isDark),

                _buildTextField(_studentEmailController,
                    'Email ${_isStudentResponsible ? "*" : "(Opc.)"}',
                    icon: PhosphorIcons.envelope_simple_bold,
                    keyboardType: TextInputType.emailAddress,
                    isRequired: _isStudentResponsible, validator: (value) {
                  final String trimmedValue = (value ?? '').trim();
                  if (trimmedValue.isEmpty) {
                    return _isStudentResponsible ? 'Obrigatório' : null;
                  }
                  final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                  if (!emailRegex.hasMatch(trimmedValue))
                    return 'E-mail inválido';
                  return null;
                }, isDark: isDark),

                _buildTextField(_studentRgController, 'RG (Opc.)',
                    icon: PhosphorIcons.identification_card_bold,
                    formatters: [_rgMask],
                    isDark: isDark),

                // [MODIFICADO] CPF Obrigatório se for Responsável
                _buildTextField(_studentCpfController,
                    'CPF ${_isStudentResponsible ? "*" : "(Opc.)"}',
                    icon: PhosphorIcons.identification_card_bold,
                    keyboardType: TextInputType.number,
                    formatters: [_cpfMask],
                    isRequired: _isStudentResponsible,
                    isDark: isDark),
              ],
            ),
            SizedBox(height: 25.h),

            // --- ENDEREÇO ---
            _buildSectionTitle('Endereço do Aluno', isDark),
            SizedBox(height: 15.h),
            Wrap(
              spacing: 15.w,
              runSpacing: 15.h,
              children: [
                _buildTextField(_addressStreetController, 'Rua / Logradouro *',
                    icon: PhosphorIcons.map_trifold_bold,
                    isRequired: true,
                    isDark: isDark),
                _buildTextField(_addressNeighborhoodController, 'Bairro *',
                    icon: PhosphorIcons.map_pin_line_bold,
                    isRequired: true,
                    isDark: isDark),
                _buildTextField(_addressNumberController, 'Número (Opc.)',
                    icon: PhosphorIcons.hash_bold, isDark: isDark),
                _buildTextField(_addressBlockController, 'Quadra (Opc.)',
                    icon: PhosphorIcons.grid_four_bold, isDark: isDark),
                _buildTextField(_addressLotController, 'Lote (Opc.)',
                    icon: PhosphorIcons.note_pencil_bold, isDark: isDark),
                _buildSearchableDropdownField<StateModel>(
                    _selectedState,
                    'Estado *',
                    _states,
                    PhosphorIcons.map_trifold_bold, (state) {
                  if (state != null && state != _selectedState) {
                    setState(() {
                      _selectedState = state;
                      _selectedCity = null;
                      _citySearchController.clear();
                    });
                    _fetchCities(state);
                  }
                }, _stateSearchController, (item) => item.nome, isDark: isDark),
                _buildSearchableDropdownField<CityModel>(
                    _selectedCity,
                    'Cidade *',
                    _cities,
                    PhosphorIcons.buildings_bold,
                    (city) => setState(() => _selectedCity = city),
                    _citySearchController,
                    (item) => item.nome,
                    enabled: _selectedState != null && !_isLoadingCities,
                    isLoading: _isLoadingCities,
                    isDark: isDark),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Etapa 2: Ficha de Saúde
  Widget _buildStep2Saude(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _step2Key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Ficha de Saúde', isDark),
            SizedBox(height: 10.h),
            _buildHealthQuestion(
                question: 'Possui algum problema de saúde?',
                value: _hasHealthProblem,
                onChanged: (val) => setState(() => _hasHealthProblem = val!),
                detailsController: _healthProblemDetailsController,
                isDark: isDark),
            _buildHealthQuestion(
                question: 'Toma algum medicamento?',
                value: _takesMedication,
                onChanged: (val) => setState(() => _takesMedication = val!),
                detailsController: _medicationDetailsController,
                detailsLabel: 'Quais medicamentos?',
                isDark: isDark),
            _buildHealthQuestion(
                question: 'Tem alguma deficiência?',
                value: _hasDisability,
                onChanged: (val) => setState(() => _hasDisability = val!),
                detailsController: _disabilityDetailsController,
                isDark: isDark),
            _buildHealthQuestion(
                question: 'Possui algum alergia?',
                value: _hasAllergy,
                onChanged: (val) => setState(() => _hasAllergy = val!),
                detailsController: _allergyDetailsController,
                isDark: isDark),
            _buildHealthQuestion(
                question: 'Apresenta alergia a algum medicamento?',
                value: _hasMedicationAllergy,
                onChanged: (val) =>
                    setState(() => _hasMedicationAllergy = val!),
                detailsController: _medicationAllergyDetailsController,
                detailsLabel: 'Quais medicamentos?',
                isDark: isDark),
            _buildHealthQuestion(
                question: 'Tem algum problema de visão?',
                value: _hasVisionProblem,
                onChanged: (val) => setState(() => _hasVisionProblem = val!),
                detailsController: _visionProblemDetailsController,
                isDark: isDark),
            SizedBox(height: 15.h),
            _buildTextField(_feverMedicationController,
                'Qual remédio costuma tomar para febre? *',
                icon: PhosphorIcons.thermometer_cold_bold,
                isRequired: true,
                isDark: isDark),
            SizedBox(height: 15.h),
            _buildTextField(_foodObservationsController,
                'Outras observações sobre a alimentação (Opc.)',
                icon: PhosphorIcons.fish_bold, isDark: isDark),
          ],
        ),
      ),
    );
  }

  // Etapa 3: Responsáveis
  Widget _buildStep3Responsaveis(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _step3Key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [NOVO] Título Dinâmico
            _buildSectionTitle(
                _isStudentResponsible
                    ? 'Contatos de Emergência (Opcional)'
                    : 'Responsável Financeiro *',
                isDark),
            if (_isStudentResponsible)
              Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Text(
                      "Como o aluno é o responsável financeiro, os tutores abaixo servem apenas para contato/emergência.",
                      style: GoogleFonts.inter(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 13.sp))),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tutors.length,
              itemBuilder: (context, index) => _buildTutorCard(index, isDark),
            ),
            if (_tutors.length < 2)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: TextButton.icon(
                    onPressed: _addTutor,
                    icon: const Icon(PhosphorIcons.plus_circle),
                    label: const Text("Adicionar Outro Responsável")),
              ),
            SizedBox(height: 25.h),
            _buildSectionTitle("Pessoas Autorizadas a Buscar", isDark),
            SizedBox(height: 10.h),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _authorizedPickups.length,
              itemBuilder: (context, index) =>
                  _buildAuthorizedPersonCard(index, isDark),
            ),
            if (_authorizedPickups.length < 3)
              Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: TextButton.icon(
                    onPressed: _addAuthorizedPerson,
                    icon: const Icon(PhosphorIcons.plus_circle),
                    label: const Text("Adicionar Pessoa Autorizada")),
              ),
          ],
        ),
      ),
    );
  }

  // --- Widgets de Sub-seção ---

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(title,
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 17.sp,
            color: isDark ? Colors.white : Colors.black87));
  }

  Widget _buildHealthQuestion(
      {required String question,
      required bool value,
      required Function(bool?) onChanged,
      required TextEditingController detailsController,
      String detailsLabel = 'Se sim, quais?',
      required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(question,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade200 : Colors.black87)),
          value: value,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF007AFF),
          contentPadding: EdgeInsets.zero,
        ),
        if (value)
          Padding(
            padding: EdgeInsets.only(left: 10.w, right: 10.w, bottom: 15.h),
            child: _buildTextField(detailsController, detailsLabel,
                icon: PhosphorIcons.pencil_line_bold,
                isRequired: true,
                isDark: isDark),
          )
      ],
    );
  }

  Widget _buildTutorCard(int index, bool isDark) {
    var tutor = _tutors[index];
    final cardColor = Theme.of(context).cardColor;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      color: cardColor,
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(15.w),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Responsável ${index + 1}",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                        color: isDark ? Colors.white : Colors.black87)),
                if (index > 0 ||
                    _isStudentResponsible) // Permite remover o 1º tutor se o aluno for responsável
                  IconButton(
                      icon: const Icon(PhosphorIcons.trash, color: Colors.red),
                      onPressed: () => _removeTutor(index)),
              ],
            ),
            SizedBox(height: 15.h),
            Wrap(
              spacing: 15.w,
              runSpacing: 15.h,
              children: [
                _buildTextField(tutor['fullName'], 'Nome Completo do Tutor *',
                    icon: PhosphorIcons.user_bold,
                    isRequired: !_isStudentResponsible,
                    isDark: isDark),
                _buildDateField(tutor['birthDate'], 'Data de Nascimento *',
                    onTap: () => _selectDate(context,
                        controller:
                            (tutor['birthDate'] as TextEditingController),
                        initialDate: (tutor['birthDate']
                                    as TextEditingController)
                                .text
                                .isNotEmpty
                            ? intl.DateFormat('dd/MM/yyyy').parse(
                                (tutor['birthDate'] as TextEditingController)
                                    .text)
                            : null),
                    isRequired: !_isStudentResponsible,
                    isDark: isDark),
                _buildDropdownField<String>(
                    tutor['gender'],
                    'Gênero *',
                    const [
                      'Masculino',
                      'Feminino',
                      'Outro',
                      'Prefiro não dizer'
                    ],
                    PhosphorIcons.gender_intersex_bold,
                    (val) => setState(() => _tutors[index]['gender'] = val),
                    isRequired: !_isStudentResponsible,
                    isDark: isDark),
                _buildTextField(tutor['nationality'], 'Nacionalidade *',
                    icon: PhosphorIcons.globe_bold,
                    isRequired: !_isStudentResponsible,
                    isDark: isDark),
                _buildTextField(tutor['phone'], 'Nº de Celular *',
                    icon: PhosphorIcons.phone_bold,
                    isRequired: !_isStudentResponsible,
                    keyboardType: TextInputType.phone,
                    formatters: [_phoneMask],
                    isDark: isDark),
                _buildTextField(tutor['email'], 'Email (Opc.)',
                    icon: PhosphorIcons.envelope_simple_bold,
                    keyboardType: TextInputType.emailAddress,
                    isDark: isDark),
                _buildDropdownField<String>(
                    tutor['relationship'],
                    'Parentesco *',
                    const ['Mãe', 'Pai', 'Avó/Avô', 'Tio/Tia', 'Outro'],
                    Icons.family_restroom,
                    (val) =>
                        setState(() => _tutors[index]['relationship'] = val),
                    isRequired: !_isStudentResponsible,
                    isDark: isDark),
                _buildTextField(tutor['rg'], 'RG (Opc.)',
                    icon: PhosphorIcons.identification_card_bold,
                    formatters: [_rgMask],
                    isDark: isDark),

                // CPF do Tutor é obrigatório se o aluno não for o responsável
                _buildTextField(tutor['cpf'],
                    'CPF ${_isStudentResponsible ? "(Opc.)" : "*"}',
                    icon: PhosphorIcons.identification_card_bold,
                    keyboardType: TextInputType.number,
                    formatters: [_cpfMask],
                    isRequired: !_isStudentResponsible,
                    isDark: isDark),
              ],
            ),
            SizedBox(height: 10.h),
            CheckboxListTile(
              title: Text("O endereço do tutor é o mesmo do aluno?",
                  style: GoogleFonts.inter(
                      color: isDark ? Colors.grey.shade300 : Colors.black87)),
              value: tutor['isAddressSame'],
              onChanged: (val) =>
                  setState(() => _tutors[index]['isAddressSame'] = val!),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFF007AFF),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorizedPersonCard(int index, bool isDark) {
    final cardColor = Theme.of(context).cardColor;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      color: cardColor,
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(15.w),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Pessoa Autorizada ${index + 1}",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                IconButton(
                    icon: const Icon(PhosphorIcons.trash, color: Colors.red),
                    onPressed: () => _removeAuthorizedPerson(index)),
              ],
            ),
            SizedBox(height: 15.h),
            Wrap(
              spacing: 15.w,
              runSpacing: 15.h,
              children: [
                _buildTextField(
                    _authorizedPickups[index]['fullName']!, "Nome Completo",
                    icon: PhosphorIcons.user,
                    isRequired: false,
                    isDark: isDark),
                _buildTextField(
                    _authorizedPickups[index]['relationship']!, "Parentesco",
                    icon: Icons.family_restroom,
                    isRequired: false,
                    isDark: isDark),
                _buildTextField(
                    _authorizedPickups[index]['phoneNumber']!, "Telefone",
                    icon: PhosphorIcons.phone,
                    isRequired: false,
                    keyboardType: TextInputType.phone,
                    formatters: [_phoneMask],
                    isDark: isDark),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- Helpers ---

  Widget _buildTextField(TextEditingController controller, String label,
      {required IconData icon,
      bool isRequired = false,
      TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? formatters,
      String? hint,
      bool enabled = true,
      bool obscureText = false,
      String? Function(String?)? validator,
      required bool isDark}) {
    // Cores para campos desabilitados
    final disabledFillColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final enabledFillColor =
        isDark ? Colors.grey.shade900 : const Color(0xffD0DFE9);
    final textColor = enabled
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.grey.shade500 : Colors.grey.shade700);

    return TextFormField(
      controller: controller,
      decoration: buildInputDecoration(context, label, icon).copyWith(
        hintText: hint,
        fillColor: enabled ? enabledFillColor : disabledFillColor,
      ),
      style: GoogleFonts.inter(
          color: textColor, fontWeight: FontWeight.w500, fontSize: 16.sp),
      keyboardType: keyboardType,
      inputFormatters: formatters,
      enabled: enabled,
      obscureText: obscureText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        final sValue = value ?? '';
        if (isRequired && sValue.trim().isEmpty) return 'Campo obrigatório';
        if (validator != null) return validator(sValue);
        return null;
      },
    );
  }

  Widget _buildDateField(TextEditingController controller, String label,
      {required VoidCallback onTap,
      bool isRequired = true,
      required bool isDark}) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return TextFormField(
      controller: controller,
      decoration: buildInputDecoration(
              context, label, PhosphorIcons.calendar_blank_bold)
          .copyWith(
              suffixIcon: IconButton(
                  icon: Icon(PhosphorIcons.calendar_fill, color: iconColor),
                  onPressed: onTap)),
      style: GoogleFonts.inter(
          color: textColor, fontWeight: FontWeight.w500, fontSize: 16.sp),
      keyboardType: TextInputType.datetime,
      inputFormatters: [_dateMask],
      readOnly:
          false, // Permite digitar se quiser, mas o listener do initState pega a mudança
      onTap: onTap,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (!isRequired) return null;
        if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
        try {
          intl.DateFormat('dd/MM/yyyy').parseStrict(value);
          return null;
        } catch (e) {
          return 'Data inválida (DD/MM/AAAA)';
        }
      },
    );
  }

  Widget _buildDropdownField<T>(T? currentValue, String label, List<T> options,
      IconData icon, void Function(T?)? onChanged,
      {bool isRequired = true, required bool isDark}) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final dropdownBg = Theme.of(context).cardColor;

    return DropdownButtonFormField2<T>(
      value: currentValue,
      decoration:
          buildInputDecoration(context, label + (isRequired ? ' *' : ''), icon),
      style: GoogleFonts.inter(
          color: textColor, fontWeight: FontWeight.w500, fontSize: 16.sp),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      items: options
          .map((option) => DropdownMenuItem(
              value: option,
              child: Text(option.toString(),
                  style: GoogleFonts.inter(fontSize: 14.sp, color: textColor))))
          .toList(),
      onChanged: onChanged,
      validator: isRequired
          ? (value) => (value == null) ? 'Selecione uma opção' : null
          : null,
      isExpanded: true,
      dropdownStyleData: DropdownStyleData(
          maxHeight: 210.h,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              color: dropdownBg), // Fundo do menu adaptado
          scrollbarTheme: ScrollbarThemeData(
              radius: Radius.circular(40.r),
              thickness: MaterialStateProperty.all(6),
              thumbVisibility: MaterialStateProperty.all(true),
              thumbColor: MaterialStateProperty.all(Colors.grey.shade400))),
      buttonStyleData:
          ButtonStyleData(height: 58.h, padding: EdgeInsets.only(right: 10.w)),
      iconStyleData: IconStyleData(
          icon:
              Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade700),
          iconSize: 26),
      menuItemStyleData: MenuItemStyleData(
          height: 45.h, padding: EdgeInsets.symmetric(horizontal: 15.w)),
    );
  }

  Widget _buildSearchableDropdownField<T>(
      T? currentValue,
      String label,
      List<T> options,
      IconData icon,
      void Function(T?)? onChanged,
      TextEditingController searchController,
      String Function(T) itemToString,
      {bool isRequired = true,
      bool enabled = true,
      bool isLoading = false,
      required bool isDark}) {
    String getLabelText() {
      if (isLoading) return 'Carregando...';
      return label + (isRequired ? ' *' : '');
    }

    final textColor = isDark ? Colors.white : Colors.black87;
    final fillColor = enabled
        ? (isDark ? Colors.grey.shade900 : const Color(0xffD0DFE9))
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);
    final dropdownBg = Theme.of(context).cardColor;

    return DropdownButtonFormField2<T>(
      value: currentValue,
      decoration: buildInputDecoration(context, getLabelText(), icon)
          .copyWith(fillColor: fillColor),
      style: GoogleFonts.inter(
          color: textColor, fontWeight: FontWeight.w500, fontSize: 16.sp),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      items: options
          .map((option) => DropdownMenuItem(
              value: option,
              child: Text(itemToString(option),
                  style: GoogleFonts.inter(fontSize: 14.sp, color: textColor))))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: isRequired
          ? (value) => (value == null) ? 'Campo obrigatório' : null
          : null,
      isExpanded: true,
      dropdownStyleData: DropdownStyleData(
          maxHeight: 210.h,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r), color: dropdownBg),
          scrollbarTheme: ScrollbarThemeData(
              radius: Radius.circular(40.r),
              thickness: MaterialStateProperty.all(6),
              thumbVisibility: MaterialStateProperty.all(true),
              thumbColor: MaterialStateProperty.all(Colors.grey.shade400))),
      buttonStyleData:
          ButtonStyleData(height: 58.h, padding: EdgeInsets.only(right: 10.w)),
      iconStyleData: IconStyleData(
          icon:
              Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade700),
          iconSize: 26),
      menuItemStyleData: MenuItemStyleData(
          height: 45.h, padding: EdgeInsets.symmetric(horizontal: 15.w)),
      dropdownSearchData: DropdownSearchData(
          searchController: searchController,
          searchInnerWidgetHeight: 50.h,
          searchInnerWidget: Container(
              height: 50.h,
              padding:
                  EdgeInsets.only(top: 8.h, bottom: 4.h, right: 8.w, left: 8.w),
              child: TextFormField(
                  expands: true,
                  maxLines: null,
                  controller: searchController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      hintText: 'Pesquisar...',
                      hintStyle: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.grey.shade400 : null),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r))))),
          searchMatchFn: (item, searchValue) => itemToString(item.value as T)
              .toLowerCase()
              .contains(searchValue.toLowerCase())),
      onMenuStateChange: (isOpen) {
        if (!isOpen) searchController.clear();
      },
    );
  }
}

// Helper para manter estado (KeepAlive) - Não precisa de alteração de Dark Mode
class KeepAlivePage extends StatefulWidget {
  final Widget child;
  const KeepAlivePage({Key? key, required this.child}) : super(key: key);
  @override
  _KeepAlivePageState createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
