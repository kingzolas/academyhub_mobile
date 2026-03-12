import 'dart:convert'; // Para json.encode
import 'package:academyhub_mobile/model/address_model.dart';
import 'package:academyhub_mobile/model/staff_profile_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/model/user_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/subject_provider.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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
// --- Fim do Helper ---

class StaffFormDialog extends StatefulWidget {
  final User? existingUser; // Para edição
  final Future<bool> Function(Map<String, dynamic>)
      onSubmit; // Envia um Map<String, dynamic> combinado

  const StaffFormDialog({
    super.key,
    this.existingUser,
    required this.onSubmit,
  });

  @override
  State<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<StaffFormDialog> {
  // --- Estado de UI ---
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  String? _subjectFetchError;
  bool _isLoadingSubjects = true; // Loading para as disciplinas

  List<SubjectModel> _availableSubjects = [];

  // --- Chaves dos Formulários ---
  final _formKeyStep1 = GlobalKey<FormState>(); // Info Pessoal
  final _formKeyStep2 = GlobalKey<FormState>(); // Contato
  final _formKeyStep3 = GlobalKey<FormState>(); // Contratual
  final _formKeyStep4 = GlobalKey<FormState>(); // Habilitação
  final _formKeyStep5 = GlobalKey<FormState>(); // Acesso

  // --- Máscaras ---
  final _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _dateMask = MaskTextInputFormatter(
      mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
  final _phoneMask = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  // --- Seção 1: Informações Pessoais ---
  late TextEditingController _fullNameController;
  late TextEditingController _cpfController;
  late TextEditingController _birthDateController;
  String? _selectedGender;

  // --- Seção 2: Informações de Contato ---
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _phoneFixedController;
  late TextEditingController _streetController;
  late TextEditingController _numberController;
  late TextEditingController _neighborhoodController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;

  // --- Seção 3: Informações Contratuais ---
  late TextEditingController _admissionDateController;
  String? _selectedEmploymentType;
  late TextEditingController _mainRoleController;
  String? _selectedRemunerationModel;
  late TextEditingController _salaryAmountController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _weeklyWorkloadController;
  String? _selectedStatus; // Ativo/Inativo

  // --- Seção 4: Habilitação Acadêmica ---
  late TextEditingController _academicFormationController;
  List<String> _selectedLevels = [];
  List<String> _selectedSubjectIds = [];

  // --- Seção 5: Acesso ao Sistema ---
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _passwordConfirmController;
  List<String> _selectedRoles = [];

  // Listas de opções
  final List<String> _genderOptions = [
    'Masculino',
    'Feminino',
    'Outro',
    'Prefiro não dizer'
  ];
  final List<String> _employmentTypeOptions = [
    'Efetivo (CLT)',
    'Prestador de Serviço (PJ)',
    'Temporário',
    'Estagiário'
  ];
  final List<String> _remunerationOptions = [
    'Salário Fixo Mensal',
    'Pagamento por Hora/Aula'
  ];
  final List<String> _statusOptions = ['Ativo', 'Inativo'];
  final List<String> _levelOptions = [
    'Educação Infantil',
    'Ensino Fundamental I',
    'Ensino Fundamental II',
    'Ensino Médio'
  ];
  final List<String> _roleOptions = [
    'Professor',
    'Coordenador',
    'Admin',
    'Staff'
  ];

  @override
  void initState() {
    super.initState();
    final user = widget.existingUser;
    final profile = (user != null && user.staffProfiles.isNotEmpty)
        ? user.staffProfiles.first
        : null;

    // Seção 1
    _fullNameController = TextEditingController(text: user?.fullName);
    _cpfController = TextEditingController(text: user?.cpf);
    _birthDateController = TextEditingController(
        text: user?.birthDate != null
            ? intl.DateFormat('dd/MM/yyyy').format(user!.birthDate!)
            : '');
    _selectedGender = user?.gender;

    // Seção 2
    _emailController = TextEditingController(text: user?.email);
    _phoneController = TextEditingController(text: user?.phoneNumber);
    _phoneFixedController = TextEditingController(text: user?.phoneFixed);
    _streetController = TextEditingController(text: user?.address?.street);
    _numberController = TextEditingController(text: user?.address?.number);
    _neighborhoodController =
        TextEditingController(text: user?.address?.neighborhood);
    _cityController = TextEditingController(text: user?.address?.city);
    _stateController = TextEditingController(text: user?.address?.state);

    // Seção 3
    _admissionDateController = TextEditingController(
        text: profile?.admissionDate != null
            ? intl.DateFormat('dd/MM/yyyy').format(profile!.admissionDate)
            : '');
    _selectedEmploymentType = profile?.employmentType;
    _mainRoleController = TextEditingController(text: profile?.mainRole);
    _selectedRemunerationModel = profile?.remunerationModel;
    _salaryAmountController = TextEditingController(
        text: profile?.salaryAmount?.toStringAsFixed(2).replaceAll('.', ','));
    _hourlyRateController = TextEditingController(
        text: profile?.hourlyRate?.toStringAsFixed(2).replaceAll('.', ','));
    _weeklyWorkloadController =
        TextEditingController(text: profile?.weeklyWorkload?.toString());
    _selectedStatus = user?.status ?? 'Ativo';

    // Seção 4
    _academicFormationController =
        TextEditingController(text: profile?.academicFormation);
    _selectedLevels = profile?.enabledLevels ?? [];
    _selectedSubjectIds =
        profile?.enabledSubjects.map((s) => s.id).toList() ?? [];

    // Seção 5
    _usernameController = TextEditingController(text: user?.username);
    _passwordController = TextEditingController();
    _passwordConfirmController = TextEditingController();
    _selectedRoles = user?.roles ?? [];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSubjects();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _cpfController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _phoneFixedController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _admissionDateController.dispose();
    _mainRoleController.dispose();
    _salaryAmountController.dispose();
    _hourlyRateController.dispose();
    _weeklyWorkloadController.dispose();
    _academicFormationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubjects() async {
    setState(() {
      _isLoadingSubjects = true;
      _subjectFetchError = null;
    });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null)
        throw Exception('Token de autenticação não encontrado.');
      final provider = Provider.of<SubjectProvider>(context, listen: false);
      await provider.fetchSubjects(token);
      if (mounted) {
        setState(() {
          _availableSubjects = provider.subjects;
          _isLoadingSubjects = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _subjectFetchError = e.toString().replaceAll('Exception: ', '');
          _isLoadingSubjects = false;
        });
      }
    }
  }

  bool _validateStep(int step) {
    final keys = [
      _formKeyStep1,
      _formKeyStep2,
      _formKeyStep3,
      _formKeyStep4,
      _formKeyStep5
    ];
    return keys[step].currentState?.validate() ?? false;
  }

  void _nextPage() {
    if (_validateStep(_currentPage)) {
      if (_currentPage < 4) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _submitForm();
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_validateStep(4)) return;
    setState(() => _isLoading = true);

    DateTime? birthDate =
        intl.DateFormat('dd/MM/yyyy').tryParse(_birthDateController.text);
    DateTime? admissionDate =
        intl.DateFormat('dd/MM/yyyy').tryParse(_admissionDateController.text);

    final Map<String, dynamic> staffData = {
      "fullName": _fullNameController.text.trim(),
      "cpf": _cpfMask.getUnmaskedText(),
      "birthDate": birthDate?.toIso8601String(),
      "gender": _selectedGender,
      "email": _emailController.text.trim(),
      "phoneNumber": _phoneMask.getUnmaskedText(),
      "phoneFixed": _phoneFixedController.text.trim(),
      "address": {
        "street": _streetController.text.trim(),
        "number": _numberController.text.trim(),
        "neighborhood": _neighborhoodController.text.trim(),
        "city": _cityController.text.trim(),
        "state": _stateController.text.trim(),
      },
      "admissionDate": admissionDate?.toIso8601String(),
      "employmentType": _selectedEmploymentType,
      "mainRole": _mainRoleController.text.trim(),
      "remunerationModel": _selectedRemunerationModel,
      "salaryAmount":
          double.tryParse(_salaryAmountController.text.replaceAll(',', '.')),
      "hourlyRate":
          double.tryParse(_hourlyRateController.text.replaceAll(',', '.')),
      "weeklyWorkload": int.tryParse(_weeklyWorkloadController.text),
      "status": _selectedStatus,
      "academicFormation": _academicFormationController.text.trim(),
      "enabledLevels": _selectedLevels,
      "enabledSubjects": _selectedSubjectIds,
      "username": _usernameController.text.trim(),
      "roles": _selectedRoles,
      if (widget.existingUser == null || _passwordController.text.isNotEmpty)
        "password": _passwordController.text,
    };

    staffData.removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty));
    (staffData['address'] as Map).removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty));

    final success = await widget.onSubmit(staffData);

    if (mounted && !success) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Captura de Tema
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final headerColor = isDark
        ? Colors.black
        : Colors.black; // Header sempre preto para consistência

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      backgroundColor: cardColor,
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 15.h),

      // Título
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: headerColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.users_four_fill,
                    color: Colors.white, size: 26.sp),
                SizedBox(width: 12.w),
                Text(
                  widget.existingUser == null
                      ? 'Novo Funcionário'
                      : 'Editar Funcionário',
                  style: GoogleFonts.sairaCondensed(
                      fontWeight: FontWeight.bold,
                      fontSize: 22.sp,
                      color: Colors.white),
                ),
              ],
            ),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(),
                tooltip: 'Fechar'),
          ],
        ),
      ),

      // Conteúdo
      content: SizedBox(
        width: 700.w,
        height: 600.h,
        child: Column(
          children: [
            _buildStepIndicator(isDark),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildStep1Pessoal(isDark),
                  _buildStep2Contato(isDark),
                  _buildStep3Contratual(isDark),
                  _buildStep4Habilitacao(isDark),
                  _buildStep5Acesso(isDark),
                ],
              ),
            ),
          ],
        ),
      ),

      // Ações
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
                  _currentPage == 4
                      ? PhosphorIcons.check_circle_fill
                      : PhosphorIcons.arrow_right,
                  size: 18.sp),
          label: Text(_currentPage == 4
              ? (widget.existingUser == null ? 'Criar Funcionário' : 'Salvar')
              : 'Próximo'),
          style: ElevatedButton.styleFrom(
              backgroundColor: (_currentPage == 4
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
    final titles = ['Pessoal', 'Contato', 'Contrato', 'Habilitação', 'Acesso'];
    final bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
      decoration: BoxDecoration(
          color: bgColor,
          border: Border(bottom: BorderSide(color: borderColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(titles.length, (index) {
          bool isActive = index == _currentPage;
          bool isDone = index < _currentPage;
          Color color = isDone
              ? Colors.green.shade600
              : (isActive
                  ? (isDark ? Colors.blueAccent : Colors.blue.shade700)
                  : Colors.grey.shade500);

          return Column(
            children: [
              Icon(
                isDone
                    ? PhosphorIcons.check_circle_fill
                    : (isActive
                        ? PhosphorIcons.dots_nine
                        : PhosphorIcons.circle_fill),
                color: color,
                size: 16.sp,
              ),
              SizedBox(height: 3.h),
              Text(
                titles[index],
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // --- Etapas do Formulário ---

  Widget _buildStep1Pessoal(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyStep1,
        child: Column(children: [
          _buildTextField(_fullNameController, 'Nome Completo *',
              icon: PhosphorIcons.user_bold, isRequired: true, isDark: isDark),
          SizedBox(height: 15.h),
          Row(children: [
            Expanded(
                child: _buildTextField(_cpfController, 'CPF *',
                    icon: PhosphorIcons.identification_card_bold,
                    isRequired: true,
                    keyboardType: TextInputType.number,
                    formatters: [_cpfMask],
                    isDark: isDark)),
            SizedBox(width: 15.w),
            Expanded(
                child: _buildTextField(
                    _birthDateController, 'Data de Nascimento *',
                    icon: PhosphorIcons.calendar_blank_bold,
                    isRequired: true,
                    keyboardType: TextInputType.datetime,
                    formatters: [_dateMask],
                    hint: 'DD/MM/AAAA',
                    isDark: isDark)),
          ]),
          SizedBox(height: 15.h),
          _buildDropdownField(
              _selectedGender,
              'Gênero *',
              _genderOptions,
              PhosphorIcons.gender_intersex_bold,
              (val) => setState(() => _selectedGender = val),
              isDark: isDark),
        ]),
      ),
    );
  }

  Widget _buildStep2Contato(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyStep2,
        child: Column(children: [
          _buildTextField(_emailController, 'E-mail Principal *',
              icon: PhosphorIcons.envelope_simple_bold,
              isRequired: true,
              keyboardType: TextInputType.emailAddress,
              isDark: isDark),
          SizedBox(height: 15.h),
          Row(children: [
            Expanded(
                child: _buildTextField(_phoneController, 'Telefone Celular *',
                    icon: PhosphorIcons.phone_bold,
                    isRequired: true,
                    keyboardType: TextInputType.phone,
                    formatters: [_phoneMask],
                    isDark: isDark)),
            SizedBox(width: 15.w),
            Expanded(
                child: _buildTextField(
                    _phoneFixedController, 'Telefone Fixo (Opc.)',
                    icon: PhosphorIcons.phone_disconnect_bold,
                    keyboardType: TextInputType.phone,
                    formatters: [_phoneMask],
                    isDark: isDark)),
          ]),
          SizedBox(height: 15.h),
          Divider(height: 20.h, color: isDark ? Colors.grey.shade700 : null),
          Row(children: [
            Expanded(
                flex: 5,
                child: _buildTextField(_streetController, 'Rua / Logradouro *',
                    icon: PhosphorIcons.map_trifold_bold,
                    isRequired: true,
                    isDark: isDark)),
            SizedBox(width: 15.w),
            Expanded(
                flex: 1,
                child: _buildTextField(_numberController, 'Nº *',
                    icon: PhosphorIcons.hash_bold,
                    isRequired: true,
                    isDark: isDark)),
          ]),
          SizedBox(height: 15.h),
          Row(children: [
            Expanded(
                child: _buildTextField(_neighborhoodController, 'Bairro *',
                    icon: PhosphorIcons.map_pin_line_bold,
                    isRequired: true,
                    isDark: isDark)),
            SizedBox(width: 15.w),
            Expanded(
                child: _buildTextField(_cityController, 'Cidade *',
                    icon: PhosphorIcons.buildings_bold,
                    isRequired: true,
                    isDark: isDark)),
            SizedBox(width: 15.w),
            Expanded(
                child: _buildTextField(_stateController, 'Estado (UF) *',
                    icon: PhosphorIcons.map_pin_line_fill,
                    isRequired: true,
                    formatters: [LengthLimitingTextInputFormatter(2)],
                    isDark: isDark)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildStep3Contratual(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyStep3,
        child: Column(children: [
          Row(children: [
            Expanded(
                child: _buildTextField(
                    _admissionDateController, 'Data de Admissão *',
                    icon: PhosphorIcons.calendar_check_bold,
                    isRequired: true,
                    keyboardType: TextInputType.datetime,
                    formatters: [_dateMask],
                    hint: 'DD/MM/AAAA',
                    isDark: isDark)),
            SizedBox(width: 15.w),
            Expanded(
                child: _buildDropdownField(
                    _selectedEmploymentType,
                    'Vínculo *',
                    _employmentTypeOptions,
                    PhosphorIcons.briefcase_bold,
                    (val) => setState(() => _selectedEmploymentType = val),
                    isDark: isDark)),
          ]),
          SizedBox(height: 15.h),
          _buildTextField(_mainRoleController, 'Cargo/Função Principal *',
              icon: PhosphorIcons.user_gear_bold,
              isRequired: true,
              hint: 'Ex: Professor(a) de Matemática',
              isDark: isDark),
          SizedBox(height: 15.h),
          Row(children: [
            Expanded(
                child: _buildDropdownField(
                    _selectedRemunerationModel,
                    'Modelo Remuneração *',
                    _remunerationOptions,
                    PhosphorIcons.currency_dollar_bold,
                    (val) => setState(() => _selectedRemunerationModel = val),
                    isDark: isDark)),
            SizedBox(width: 15.w),
            Expanded(
                child: _buildDropdownField(
                    _selectedStatus,
                    'Status *',
                    _statusOptions,
                    PhosphorIcons.toggle_left_bold,
                    (val) => setState(() => _selectedStatus = val),
                    isDark: isDark)),
          ]),
          SizedBox(height: 15.h),
          if (_selectedRemunerationModel == 'Salário Fixo Mensal')
            _buildTextField(_salaryAmountController, 'Valor do Salário (R\$) *',
                icon: PhosphorIcons.wallet_bold,
                isRequired: true,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                formatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+([.,]\d{0,2})?'))
                ],
                isDark: isDark),
          if (_selectedRemunerationModel == 'Pagamento por Hora/Aula')
            _buildTextField(_hourlyRateController, 'Valor da Hora/Aula (R\$) *',
                icon: PhosphorIcons.timer_bold,
                isRequired: true,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                formatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+([.,]\d{0,2})?'))
                ],
                isDark: isDark),
          SizedBox(height: 15.h),
          _buildTextField(
              _weeklyWorkloadController, 'Carga Horária Semanal (Opc.)',
              icon: PhosphorIcons.hourglass_bold,
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              isDark: isDark),
        ]),
      ),
    );
  }

  Widget _buildStep4Habilitacao(bool isDark) {
    if (_isLoadingSubjects)
      return const Center(child: CircularProgressIndicator());
    if (_subjectFetchError != null)
      return Center(
          child: Text("Erro ao buscar disciplinas: $_subjectFetchError",
              style: TextStyle(color: Colors.red)));

    final Map<String, List<SubjectModel>> subjectsByLevel = {};
    for (var subject in _availableSubjects) {
      (subjectsByLevel[subject.level] ??= []).add(subject);
    }
    final sortedLevels = subjectsByLevel.keys.toList()
      ..sort((a, b) =>
          _levelOptions.indexOf(a).compareTo(_levelOptions.indexOf(b)));
    if (subjectsByLevel.containsKey('Geral')) {
      sortedLevels.remove('Geral');
      sortedLevels.add('Geral');
    }

    final textColor = isDark ? Colors.white : Colors.black87;
    final sectionTitleColor =
        isDark ? Colors.grey.shade400 : Colors.blueGrey.shade700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyStep4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildTextField(_academicFormationController, 'Formação Principal',
              icon: PhosphorIcons.graduation_cap_bold,
              hint: 'Ex: Graduado em Letras (Português)',
              isDark: isDark),
          SizedBox(height: 20.h),
          Text('Níveis de Ensino Habilitados:',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                  color: textColor)),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 8.h,
            children: _levelOptions.map((level) {
              final isSelected = _selectedLevels.contains(level);
              return FilterChip(
                label: Text(level,
                    style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : textColor)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected)
                      _selectedLevels.add(level);
                    else
                      _selectedLevels.remove(level);
                  });
                },
                backgroundColor:
                    isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                selectedColor:
                    isDark ? Colors.blueAccent : Colors.blueAccent.shade700,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    side: BorderSide(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300)),
              );
            }).toList(),
          ),
          SizedBox(height: 20.h),
          Text('Disciplinas Habilitadas:',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                  color: textColor)),
          SizedBox(height: 8.h),
          if (_availableSubjects.isEmpty)
            const Text(
                'Nenhuma disciplina cadastrada no sistema. Cadastre-as primeiro na tela "Disciplinas".'),
          ...sortedLevels.map((level) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Text(level,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: sectionTitleColor)),
                ),
                Divider(
                    height: 5.h, color: isDark ? Colors.grey.shade700 : null),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 8.h,
                  children: subjectsByLevel[level]!.map((subject) {
                    final isSelected = _selectedSubjectIds.contains(subject.id);
                    return FilterChip(
                      label: Text(subject.name,
                          style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : textColor)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected)
                            _selectedSubjectIds.add(subject.id);
                          else
                            _selectedSubjectIds.remove(subject.id);
                        });
                      },
                      backgroundColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      selectedColor: isDark
                          ? Colors.blueAccent
                          : Colors.blueAccent.shade700,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300)),
                    );
                  }).toList(),
                ),
              ],
            );
          }).toList(),
        ]),
      ),
    );
  }

  Widget _buildStep5Acesso(bool isDark) {
    bool isEditing = widget.existingUser != null;
    final textColor = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyStep5,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildTextField(_usernameController, 'Nome de Usuário *',
              icon: PhosphorIcons.at_bold, isRequired: true, isDark: isDark),
          SizedBox(height: 15.h),
          _buildTextField(_emailController, 'E-mail de Acesso *',
              icon: PhosphorIcons.envelope_bold,
              isRequired: true,
              keyboardType: TextInputType.emailAddress,
              enabled: !isEditing,
              isDark: isDark),
          if (!isEditing) ...[
            SizedBox(height: 15.h),
            _buildTextField(_passwordController, 'Senha *',
                icon: PhosphorIcons.lock_key_bold,
                isRequired: !isEditing,
                obscureText: true,
                isDark: isDark),
            SizedBox(height: 15.h),
            TextFormField(
              controller: _passwordConfirmController,
              decoration: buildInputDecoration(
                  context, 'Confirmar Senha *', PhosphorIcons.lock_key_bold),
              style: GoogleFonts.inter(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 16.sp),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Campo obrigatório';
                if (value != _passwordController.text)
                  return 'As senhas não conferem';
                return null;
              },
            ),
          ] else ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Text(
                  "A senha só pode ser alterada através da tela 'Esqueci Minha Senha'.",
                  style: GoogleFonts.inter(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600)),
            )
          ],
          SizedBox(height: 20.h),
          Text('Perfis de Permissão *:',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                  color: textColor)),
          SizedBox(height: 8.h),
          if (_roleOptions.isEmpty)
            Text('Nenhum perfil de permissão disponível.'),
          Wrap(
            spacing: 10.w,
            runSpacing: 8.h,
            children: _roleOptions.map((role) {
              final isSelected = _selectedRoles.contains(role);
              return FilterChip(
                label: Text(role,
                    style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : textColor)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected)
                      _selectedRoles.add(role);
                    else
                      _selectedRoles.remove(role);
                  });
                },
                backgroundColor:
                    isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                selectedColor:
                    isDark ? Colors.blueAccent : Colors.blueAccent.shade700,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    side: BorderSide(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300)),
              );
            }).toList(),
          ),
          if (_selectedRoles.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text('Selecione pelo menos um perfil.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12.sp)),
            )
        ]),
      ),
    );
  }

  // --- Widgets Helpers Internos ---

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? hint,
    bool enabled = true,
    bool obscureText = false,
    required bool isDark,
  }) {
    // Cores para campo desabilitado
    final disabledFill = isDark ? Colors.grey.shade900 : Colors.grey.shade300;
    final enabledFill = isDark ? Colors.grey.shade800 : const Color(0xffD0DFE9);
    final textColor = enabled
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.grey.shade500 : Colors.grey.shade700);

    return TextFormField(
      controller: controller,
      decoration: buildInputDecoration(context, label, icon).copyWith(
        hintText: hint,
        fillColor: enabled ? enabledFill : disabledFill,
      ),
      style: GoogleFonts.inter(
          color: textColor, fontWeight: FontWeight.w500, fontSize: 16.sp),
      keyboardType: keyboardType,
      inputFormatters: formatters,
      enabled: enabled,
      obscureText: obscureText,
      validator: isRequired
          ? (value) => (value == null || value.trim().isEmpty)
              ? 'Campo obrigatório'
              : null
          : null,
    );
  }

  Widget _buildDropdownField<T>(
    T? currentValue,
    String label,
    List<T> options,
    IconData icon,
    void Function(T?)? onChanged, {
    bool isRequired = true,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final dropdownBg = Theme.of(context).cardColor;

    return DropdownButtonFormField2<T>(
      value: currentValue,
      decoration:
          buildInputDecoration(context, label + (isRequired ? ' *' : ''), icon),
      style: GoogleFonts.inter(
          color: textColor, fontWeight: FontWeight.w500, fontSize: 16.sp),
      items: options
          .map((option) => DropdownMenuItem(
              value: option,
              child: Text(option.toString(),
                  style: GoogleFonts.inter(fontSize: 14.sp, color: textColor))))
          .toList(),
      onChanged: onChanged,
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
    );
  }
}
