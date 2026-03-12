import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:academyhub_mobile/model/academic_record_model.dart';
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/model/school_model.dart';
import 'package:academyhub_mobile/model/tutor_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:academyhub_mobile/services/enrollment_service.dart';
import 'package:academyhub_mobile/services/pdf_generator_service.dart';
import 'package:academyhub_mobile/services/student_service.dart';
import 'package:academyhub_mobile/widgets/student_history_manager_dialog.dart';
import 'package:academyhub_mobile/widgets/edit_student_dialog.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

// --- HELPER DE ESTILO GLOBAL ---
InputDecoration buildInputDecoration(
    BuildContext context, String label, IconData icon,
    {String? hintText}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

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
        fontSize: 14.sp),
    hintText: hintText,
    hintStyle: GoogleFonts.inter(
        color: contentColor.withOpacity(0.7), fontSize: 14.sp),
    filled: true,
    fillColor: fillColor,
    prefixIcon: Icon(icon, color: contentColor, size: 20.sp),
    contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
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

class StudentDetailsPopup extends StatefulWidget {
  final Student student;
  const StudentDetailsPopup({super.key, required this.student});

  @override
  State<StudentDetailsPopup> createState() => _StudentDetailsPopupState();
}

class _StudentDetailsPopupState extends State<StudentDetailsPopup>
    with SingleTickerProviderStateMixin {
  late Student _currentStudent;
  late TabController _tabController;

  // Estados de loading PDF
  bool _isGeneratingEnrollmentPdf = false;
  bool _isGeneratingIncomeTaxPdf = false;
  bool _isGeneratingEnrollmentStatusPdf = false;
  bool _isGeneratingNothingPendingPdf = false;
  bool _isGeneratingTranscriptPdf = false;
  bool _wasStudentModified = false;

  // Estado para Matrícula Atual
  Enrollment? _activeEnrollment;
  bool _isLoadingEnrollment = true;
  String? _enrollmentError;

  late List<AcademicRecord> _currentHistory;

  // Serviços
  final PdfGeneratorService _pdfService = PdfGeneratorService();
  final EnrollmentService _enrollmentService = EnrollmentService();

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _fetchActiveEnrollment();
    _currentHistory = List.from(_currentStudent.academicHistory);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE EDIÇÃO ---
  Future<void> _showEditStudentDialog() async {
    final Student? updatedStudent = await showDialog<Student>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditStudentDialog(student: _currentStudent),
    );

    if (updatedStudent != null && mounted) {
      setState(() {
        _currentStudent = updatedStudent;
        _wasStudentModified = true;
      });
      _showSuccessSnackbar('Aluno atualizado com sucesso!');
    }
  }

  Future<void> _showHistoryManager() async {
    final List<AcademicRecord>? updatedHistory =
        await showDialog<List<AcademicRecord>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AcademicHistoryManagerDialog(
        studentId: _currentStudent.id,
        initialHistory: _currentHistory,
      ),
    );

    if (updatedHistory != null && mounted) {
      if (!listEquals(_currentHistory, updatedHistory)) {
        setState(() {
          _currentHistory = updatedHistory;
          _wasStudentModified = true;
        });
        _showSuccessSnackbar('Histórico acadêmico atualizado.');
      }
    }
  }

  // --- BUSCA MATRÍCULA ---
  Future<void> _fetchActiveEnrollment({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingEnrollment = true;
        _enrollmentError = null;
      });
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      if (mounted) setState(() => _isLoadingEnrollment = false);
      return;
    }

    try {
      final enrollments =
          await _enrollmentService.getEnrollments(token, filter: {
        'student': _currentStudent.id,
        'status': 'Ativa',
      });
      // Ordena para pegar a mais recente
      enrollments.sort((a, b) => b.academicYear.compareTo(a.academicYear));

      if (mounted) {
        setState(() {
          _activeEnrollment = enrollments.isNotEmpty ? enrollments.first : null;
          _isLoadingEnrollment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enrollmentError = e.toString().replaceAll('Exception: ', '');
          _isLoadingEnrollment = false;
        });
      }
    }
  }

  // --- DIALOG MATRÍCULA ---
  Future<void> _showEnrollmentDialog() async {
    final bool? enrollmentSuccess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EnrollmentDialog(student: _currentStudent),
    );
    if (enrollmentSuccess == true && mounted) {
      _fetchActiveEnrollment(showLoading: false);
      _showSuccessSnackbar('Aluno matriculado com sucesso!');
      setState(() => _wasStudentModified = true);
    }
  }

  // Helper para pegar a escola atual
  SchoolModel? _getCurrentSchool() {
    try {
      return Provider.of<SchoolProvider>(context, listen: false).school;
    } catch (e) {
      print("Erro ao recuperar escola: $e");
      return null;
    }
  }

  // --- GERAÇÃO DE PDFS E NOMENCLATURA ---
  String _removeDiacritics(String str) {
    var withDia =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  String _getFileName(String docType) {
    String cleanName = _currentStudent.fullName.trim().replaceAll(' ', '_');
    cleanName = _removeDiacritics(cleanName);
    cleanName = cleanName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

    final date = intl.DateFormat('dd-MM-yyyy').format(DateTime.now());
    return '${docType}_${cleanName}_$date';
  }

  Future<void> _generateAndShowPdf({
    required Future<Uint8List> Function() generatorFunction,
    required String defaultFileName,
    required Function(bool) setLoadingState,
  }) async {
    setLoadingState(true);
    try {
      final Uint8List pdfBytes = await generatorFunction();
      if (!mounted) return;

      String finalName = defaultFileName;
      if (!finalName.toLowerCase().endsWith('.pdf')) {
        finalName += '.pdf';
      }

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement()
          ..href = url
          ..style.display = 'none'
          ..download = finalName;
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        _showSuccessSnackbar("Download iniciado: $finalName");
      } else {
        await Printing.sharePdf(bytes: pdfBytes, filename: finalName);
      }
    } catch (e) {
      if (mounted) _showErrorSnackbar('Erro ao gerar PDF: $e');
    } finally {
      if (mounted) setLoadingState(false);
    }
  }

  // 1. HISTÓRICO ESCOLAR
  void _generateTranscript() {
    if (_currentHistory.isEmpty) {
      _showErrorSnackbar('Sem histórico para gerar.');
      return;
    }
    final school = _getCurrentSchool();
    if (school == null) {
      _showErrorSnackbar('Erro: Informações da escola não encontradas.');
      return;
    }
    _generateAndShowPdf(
      generatorFunction: () => _pdfService.generateSchoolTranscript(
        _currentStudent,
        _currentHistory,
        school,
      ),
      defaultFileName: _getFileName('Historico'),
      setLoadingState: (l) => setState(() => _isGeneratingTranscriptPdf = l),
    );
  }

  // 2. DECLARAÇÃO DE MATRÍCULA
  void _generateEnrollmentConfirmation() {
    final school = _getCurrentSchool();
    if (school == null) {
      _showErrorSnackbar('Erro: Informações da escola não encontradas.');
      return;
    }
    _generateAndShowPdf(
      generatorFunction: () =>
          _pdfService.generateEnrollmentConfirmation(_currentStudent, school),
      defaultFileName: _getFileName('Declaracao_Matricula'),
      setLoadingState: (l) => setState(() => _isGeneratingEnrollmentPdf = l),
    );
  }

  // 3. IRPF
  Future<void> _showIncomeTaxDialogAndGenerate() async {
    if (_currentStudent.tutors.isEmpty) {
      _showErrorSnackbar('Nenhum tutor associado a este aluno.');
      return;
    }
    final school = _getCurrentSchool();
    if (school == null) {
      _showErrorSnackbar('Erro: Informações da escola não encontradas.');
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IncomeTaxInputDialog(tutors: _currentStudent.tutors),
    );
    if (result != null && mounted) {
      final Tutor selectedTutor = result['tutor'];
      final double totalAmount = result['amount'];
      final String periodDescription = result['period'];

      _generateAndShowPdf(
        generatorFunction: () => _pdfService.generateIncomeTaxPdf(
            _currentStudent,
            selectedTutor,
            totalAmount,
            periodDescription,
            school),
        defaultFileName: _getFileName('Declaracao_IRPF'),
        setLoadingState: (l) => setState(() => _isGeneratingIncomeTaxPdf = l),
      );
    }
  }

  // 4. DECLARAÇÃO CURSANDO
  Future<void> _generateEnrollmentStatusPdf() async {
    final school = _getCurrentSchool();
    if (school == null) {
      _showErrorSnackbar('Erro: Informações da escola não encontradas.');
      return;
    }
    if (_activeEnrollment == null) {
      _showErrorSnackbar(
          'O aluno não possui matrícula ativa para gerar este documento.');
      return;
    }
    final String currentGrade = '${_activeEnrollment!.classInfo.grade}';
    final int currentYear = _activeEnrollment!.academicYear;
    final String nextYear = (currentYear + 1).toString();

    _generateAndShowPdf(
      generatorFunction: () => _pdfService.generateEnrollmentStatusPdf(
          _currentStudent, currentGrade, nextYear, school),
      defaultFileName: _getFileName('Declaracao_Cursando'),
      setLoadingState: (l) =>
          setState(() => _isGeneratingEnrollmentStatusPdf = l),
    );
  }

  // 5. NADA CONSTA
  Future<void> _generateNothingPendingPdf() async {
    final school = _getCurrentSchool();
    if (school == null) {
      _showErrorSnackbar('Erro: Informações da escola não encontradas.');
      return;
    }
    if (_activeEnrollment == null) {
      _showErrorSnackbar(
          'O aluno não possui matrícula ativa para gerar este documento.');
      return;
    }
    final String currentGrade = _activeEnrollment!.classInfo.grade;

    _generateAndShowPdf(
      generatorFunction: () => _pdfService.generateNothingPendingPdf(
          _currentStudent, currentGrade, school),
      defaultFileName: _getFileName('Nada_Consta'),
      setLoadingState: (l) =>
          setState(() => _isGeneratingNothingPendingPdf = l),
    );
  }

  // --- HELPERS UI ---
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), backgroundColor: Colors.orange.shade800));
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), backgroundColor: Colors.green.shade600));
  }

  // ===========================================================================
  // ========================== INTERFACE VISUAL ===============================
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8F9FA);

    return Dialog(
      // [UX] Padding ajustado para Mobile
      insetPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: theme.cardColor,
      child: Container(
        // [UX] Altura dinâmica e Largura máxima responsiva
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: 0.9.sh, maxWidth: 500.w),
        child: Column(
          children: [
            _buildHeader(theme, isDark),
            _buildTabBar(theme, isDark),
            Expanded(
              child: Container(
                color: backgroundColor,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabOverview(theme, isDark),
                    _buildTabPersonalAndHealth(theme, isDark),
                    _buildTabDocuments(theme, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
    final matBg = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    final matText = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 15.w, 10.h),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r), topRight: Radius.circular(16.r)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'student_avatar_${_currentStudent.id}',
            child: StudentAvatar(
              studentId: _currentStudent.id,
              fullName: _currentStudent.fullName,
              radius: 35.r, // [UX] Reduzido para caber melhor em mobile
              fontSize: 22.sp,
              hasEnrollment: _activeEnrollment != null,
            ),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentStudent.fullName,
                  style: GoogleFonts.saira(
                    fontWeight: FontWeight.bold,
                    fontSize: 20.sp, // [UX] Fonte ajustada para mobile
                    color: textColor,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8.w,
                  runSpacing: 4.h,
                  children: [
                    _buildStatusBadge(isDark),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                          color: matBg,
                          borderRadius: BorderRadius.circular(4.r)),
                      child: Text(
                        'MAT: ${_currentStudent.id.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.firaCode(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: matText),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(_wasStudentModified),
                icon: Icon(Icons.close_rounded, color: iconColor, size: 24.sp),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              SizedBox(height: 10.h),
              InkWell(
                onTap: _showEditStudentDialog,
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(PhosphorIcons.pencil_simple_bold,
                      size: 18.sp,
                      color:
                          isDark ? Colors.blue.shade200 : Colors.blue.shade700),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    bool isActive = !_isLoadingEnrollment && _activeEnrollment != null;

    final activeBg =
        isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50;
    final activeBorder =
        isDark ? Colors.green.withOpacity(0.4) : Colors.green.shade200;
    final activeText = isDark ? Colors.greenAccent : Colors.green.shade800;

    final inactiveBg =
        isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50;
    final inactiveBorder =
        isDark ? Colors.orange.withOpacity(0.4) : Colors.orange.shade200;
    final inactiveText = isDark ? Colors.orangeAccent : Colors.orange.shade800;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isActive ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: isActive ? activeBorder : inactiveBorder),
      ),
      child: Text(
        isActive ? "Matriculado" : "Ñ Matriculado",
        style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: isActive ? activeText : inactiveText),
      ),
    );
  }

  // --- TABS ---
  Widget _buildTabBar(ThemeData theme, bool isDark) {
    return Container(
      color: theme.cardColor,
      child: TabBar(
        controller: _tabController,
        labelColor: isDark ? Colors.blueAccent : Colors.blue.shade700,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: isDark ? Colors.blueAccent : Colors.blue.shade700,
        indicatorWeight: 3,
        labelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp),
        tabs: const [
          Tab(text: 'Visão Geral'),
          Tab(text: 'Dados'), // [UX] Nome encurtado para caber no mobile
          Tab(text: 'Docs'), // [UX] Nome encurtado
        ],
      ),
    );
  }

  // *** TAB 1: VISÃO GERAL ***
  Widget _buildTabOverview(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Matrícula Ativa', PhosphorIcons.student,
              isDark: isDark),
          SizedBox(height: 10.h),
          _buildActiveEnrollmentCard(theme, isDark),
          SizedBox(height: 25.h),
          _buildSectionTitle('Responsáveis', PhosphorIcons.users_three,
              isDark: isDark),
          SizedBox(height: 10.h),
          if (_currentStudent.tutors.isEmpty)
            _buildEmptyStateCard('Nenhum tutor associado.', isDark)
          else
            ..._currentStudent.tutors
                .map((t) => _buildTutorCard(t, theme, isDark)),
        ],
      ),
    );
  }

  // *** TAB 2: DADOS PESSOAIS & SAÚDE ***
  Widget _buildTabPersonalAndHealth(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        // [UX] Alterado de Row para Column para mobile
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEÇÃO 1: Dados Pessoais
          _buildSectionTitle(
              'Informações Básicas', PhosphorIcons.identification_card,
              isDark: isDark),
          SizedBox(height: 15.h),
          _buildGridInfo([
            {
              'label': 'Data Nascimento',
              'value': _formatDate(_currentStudent.birthDate)
            },
            {'label': 'Gênero', 'value': _displayText(_currentStudent.gender)},
            {
              'label': 'Nacionalidade',
              'value': _displayText(_currentStudent.nationality)
            },
            {'label': 'Raça/Cor', 'value': _displayText(_currentStudent.race)},
            {'label': 'CPF', 'value': _displayText(_currentStudent.cpf)},
            {'label': 'RG', 'value': _displayText(_currentStudent.rg)},
          ], isDark),
          SizedBox(height: 30.h),

          _buildSectionTitle('Endereço & Contato', PhosphorIcons.map_pin,
              isDark: isDark),
          SizedBox(height: 15.h),
          _buildGridInfo([
            {'label': 'Email', 'value': _displayText(_currentStudent.email)},
            {
              'label': 'Telefone',
              'value': _displayText(_currentStudent.phoneNumber)
            },
            {
              'label': 'Endereço',
              'value':
                  '${_displayText(_currentStudent.address.street)}, ${_displayText(_currentStudent.address.number)}'
            },
            {
              'label': 'Bairro/Cidade',
              'value':
                  '${_displayText(_currentStudent.address.neighborhood)} - ${_displayText(_currentStudent.address.city)}/${_displayText(_currentStudent.address.state)}'
            },
          ], isDark),

          SizedBox(height: 30.h),
          Divider(color: Colors.grey.withOpacity(0.2)),
          SizedBox(height: 20.h),

          // SEÇÃO 2: Saúde
          _buildSectionTitle('Saúde & Cuidados', PhosphorIcons.heartbeat,
              color: Colors.red.shade700, isDark: isDark),
          SizedBox(height: 15.h),
          _buildHealthSection(theme, isDark),
        ],
      ),
    );
  }

  // --- SEÇÃO DE SAÚDE ---
  Widget _buildHealthSection(ThemeData theme, bool isDark) {
    final h = _currentStudent.healthInfo;
    List<Widget> cards = [];

    if (h.hasAllergy) {
      cards.add(_buildHealthAlertCard(
          'Alergia Alimentar/Outras',
          h.allergyDetails,
          PhosphorIcons.warning_circle,
          Colors.orange,
          theme,
          isDark));
    }
    if (h.hasMedicationAllergy) {
      cards.add(_buildHealthAlertCard(
          'Alergia a Medicamento',
          h.medicationAllergyDetails,
          PhosphorIcons.prohibit,
          Colors.red,
          theme,
          isDark));
    }
    if (h.hasHealthProblem) {
      cards.add(_buildHealthAlertCard(
          'Condição de Saúde',
          h.healthProblemDetails,
          PhosphorIcons.first_aid,
          Colors.blue,
          theme,
          isDark));
    }
    if (h.hasDisability) {
      cards.add(_buildHealthAlertCard('Deficiência', h.disabilityDetails,
          PhosphorIcons.wheelchair, Colors.teal, theme, isDark));
    }
    if (h.takesMedication) {
      cards.add(_buildHealthAlertCard(
          'Uso Contínuo de Medicação',
          h.medicationDetails,
          PhosphorIcons.pill,
          Colors.indigo,
          theme,
          isDark));
    }
    if (h.hasVisionProblem) {
      cards.add(_buildHealthAlertCard(
          'Problema de Visão',
          h.visionProblemDetails,
          PhosphorIcons.eye,
          Colors.purple,
          theme,
          isDark));
    }
    if (h.feverMedication.isNotEmpty) {
      cards.add(_buildHealthInfoCard('Em caso de febre:', h.feverMedication,
          PhosphorIcons.thermometer, isDark));
    }
    if (h.foodObservations.isNotEmpty) {
      cards.add(_buildHealthInfoCard('Restrições Alimentares:',
          h.foodObservations, PhosphorIcons.fork_knife, isDark));
    }

    if (cards.isEmpty) {
      final greenBg =
          isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50;
      final greenBorder =
          isDark ? Colors.green.withOpacity(0.3) : Colors.green.shade100;
      final greenText = isDark ? Colors.greenAccent : Colors.green.shade800;
      final greenIcon = isDark ? Colors.greenAccent : Colors.green.shade600;

      return Container(
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(
          color: greenBg,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: greenBorder),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.check_circle, color: greenIcon, size: 20.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Nenhuma restrição de saúde.',
                style: GoogleFonts.inter(color: greenText, fontSize: 13.sp),
              ),
            )
          ],
        ),
      );
    }

    return Column(children: cards);
  }

  Widget _buildHealthAlertCard(String title, String details, IconData icon,
      Color color, ThemeData theme, bool isDark) {
    final borderColor = color;
    final textColor = color;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black26 : Colors.grey.shade200,
              blurRadius: 3,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 18.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        color: textColor)),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            details.isNotEmpty ? details : 'Detalhes não informados.',
            style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: isDark ? Colors.white70 : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInfoCard(
      String title, String content, IconData icon, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade800)),
                Text(content,
                    style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // *** TAB 3: DOCUMENTOS ***
  Widget _buildTabDocuments(ThemeData theme, bool isDark) {
    return GridView.count(
      // [UX] Alterado para 2 colunas para mobile
      crossAxisCount: 2,
      padding: EdgeInsets.all(20.w),
      crossAxisSpacing: 15.w,
      mainAxisSpacing: 15.h,
      childAspectRatio: 1.4, // Card mais quadrado para caber o texto
      children: [
        _buildActionTile(
            icon: PhosphorIcons.file_text,
            label: 'Declaração\nMatrícula',
            color: Colors.blue,
            isLoading: _isGeneratingEnrollmentPdf,
            onTap: _generateEnrollmentConfirmation,
            isDark: isDark),
        _buildActionTile(
            icon: PhosphorIcons.graduation_cap,
            label: 'Declaração\nCursando',
            color: Colors.teal,
            isLoading: _isGeneratingEnrollmentStatusPdf,
            onTap: _generateEnrollmentStatusPdf,
            isDark: isDark),
        _buildActionTile(
            icon: PhosphorIcons.check_circle,
            label: 'Nada Consta',
            color: Colors.green,
            isLoading: _isGeneratingNothingPendingPdf,
            onTap: _generateNothingPendingPdf,
            isDark: isDark),
        _buildActionTile(
            icon: PhosphorIcons.file_pdf,
            label: 'Declaração\nIRPF',
            color: Colors.red,
            isLoading: _isGeneratingIncomeTaxPdf,
            onTap: _showIncomeTaxDialogAndGenerate,
            isDark: isDark),
        _buildActionTile(
            icon: PhosphorIcons.book_bookmark,
            label: 'Histórico\nEscolar',
            color: Colors.deepPurple,
            isLoading: _isGeneratingTranscriptPdf,
            onTap: _generateTranscript,
            isDark: isDark),
        _buildActionTile(
            icon: PhosphorIcons.pencil_line,
            label: 'Gerenciar\nHistórico',
            color: Colors.indigo,
            isLoading: false,
            onTap: _showHistoryManager,
            isOutlined: true,
            isDark: isDark),
      ],
    );
  }

  // --- HELPERS UI ---

  Widget _buildSectionTitle(String title, IconData icon,
      {Color? color, required bool isDark}) {
    final themeColor =
        color ?? (isDark ? Colors.blueAccent : Colors.blue.shade800);
    final titleColor = isDark ? Colors.white : Colors.black87;

    return Row(
      children: [
        Icon(icon, size: 20.sp, color: themeColor),
        SizedBox(width: 8.w),
        Text(title,
            style: GoogleFonts.sairaCondensed(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: titleColor)),
      ],
    );
  }

  Widget _buildActiveEnrollmentCard(ThemeData theme, bool isDark) {
    if (_isLoadingEnrollment) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    if (_enrollmentError != null) {
      return _buildErrorCard(_enrollmentError!);
    }
    if (_activeEnrollment == null) {
      final orangeBg =
          isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50;
      final orangeBorder =
          isDark ? Colors.orange.withOpacity(0.3) : Colors.orange.shade200;
      final orangeIconBg =
          isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade100;
      final orangeText = isDark ? Colors.orangeAccent : Colors.orange.shade900;
      final orangeSubText =
          isDark ? Colors.orange.shade200 : Colors.orange.shade800;

      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: orangeBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: orangeBorder),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                      color: orangeIconBg, shape: BoxShape.circle),
                  child: Icon(PhosphorIcons.warning_circle_bold,
                      color: isDark ? Colors.orange : Colors.orange.shade800,
                      size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sem matrícula ativa',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: orangeText)),
                      Text('Matricule para o ano letivo atual.',
                          style: GoogleFonts.inter(
                              color: orangeSubText, fontSize: 12.sp)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showEnrollmentDialog,
                style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.orange.shade900
                        : Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 10.h)),
                child: const Text('Matricular Agora'),
              ),
            )
          ],
        ),
      );
    }

    final enrollment = _activeEnrollment!;
    final textColor = isDark ? Colors.white : Colors.blue.shade900;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final blueBoxBg =
        isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50;
    final blueBoxText = isDark ? Colors.blue.shade200 : Colors.blue.shade800;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(enrollment.classInfo.name,
                        style: GoogleFonts.saira(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            color: textColor)),
                    Text(
                        '${enrollment.classInfo.grade} • ${enrollment.classInfo.shift}',
                        style: GoogleFonts.inter(
                            color: subTextColor, fontSize: 13.sp)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                    color: blueBoxBg, borderRadius: BorderRadius.circular(8.r)),
                child: Column(
                  children: [
                    Text('Ano',
                        style: GoogleFonts.inter(
                            fontSize: 10.sp, color: blueBoxText)),
                    Text(enrollment.classInfo.schoolYear.toString(),
                        style: GoogleFonts.saira(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: textColor)),
                  ],
                ),
              )
            ],
          ),
          Divider(
              height: 25.h,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSimpleInfo('Mensalidade',
                  'R\$ ${enrollment.agreedFee.toStringAsFixed(2)}', isDark),
              _buildSimpleInfo(
                  'Data Início',
                  intl.DateFormat('dd/MM/yyyy')
                      .format(enrollment.enrollmentDate),
                  isDark),
              _buildSimpleInfo('Situação', enrollment.status, isDark),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTutorCard(
      TutorInStudent tutorLink, ThemeData theme, bool isDark) {
    bool isFinancial =
        _currentStudent.financialTutorId == tutorLink.tutorInfo.id;

    final borderColor = isFinancial
        ? (isDark ? Colors.green.withOpacity(0.5) : Colors.green.shade300)
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);

    final avatarBg = isFinancial
        ? (isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50)
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100);

    final avatarIcon = isFinancial
        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700);

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 10.h),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: borderColor,
          width: isFinancial ? 1.5 : 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          collapsedIconColor:
              isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          tilePadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          leading: CircleAvatar(
            backgroundColor: avatarBg,
            radius: 18.r,
            child: Icon(PhosphorIcons.user, color: avatarIcon, size: 18.sp),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  _displayText(tutorLink.tutorInfo.fullName),
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: isDark ? Colors.white : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isFinancial) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.green.withOpacity(0.2)
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '\$',
                    style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.greenAccent
                            : Colors.green.shade800),
                  ),
                )
              ]
            ],
          ),
          subtitle: Text(
            '${tutorLink.relationship} • ${_displayText(tutorLink.tutorInfo.phoneNumber)}',
            style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                  SizedBox(height: 4.h),
                  _buildDetailedRow(PhosphorIcons.envelope, 'Email',
                      _displayText(tutorLink.tutorInfo.email),
                      showCopy: true, isDark: isDark),
                  _buildDetailedRow(PhosphorIcons.identification_card, 'CPF',
                      _displayText(tutorLink.tutorInfo.cpf),
                      showCopy: true, isDark: isDark),
                  if (tutorLink.tutorInfo.address != null)
                    _buildDetailedRow(PhosphorIcons.map_pin, 'Endereço',
                        '${_displayText(tutorLink.tutorInfo.address!.street)}, ${_displayText(tutorLink.tutorInfo.address!.number)}',
                        isDark: isDark),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedRow(IconData icon, String label, String value,
      {bool showCopy = false, required bool isDark}) {
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final valueColor = isDark ? Colors.white70 : Colors.black87;
    final iconColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: iconColor),
          SizedBox(width: 8.w),
          Text('$label: ',
              style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: labelColor)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: valueColor),
                overflow: TextOverflow.ellipsis),
          ),
          if (showCopy && value != 'N/A')
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$label copiado!'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: Colors.grey.shade800,
                ));
              },
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child:
                    Icon(Icons.copy, size: 14.sp, color: Colors.blue.shade300),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildGridInfo(List<Map<String, String>> items, bool isDark) {
    // [UX] Layout responsivo com Wrap que preenche o espaço
    return Wrap(
      spacing: 15.w,
      runSpacing: 15.h,
      children: items.map((item) {
        return SizedBox(
          width: 0.4.sw, // Ocupa ~40% da largura (2 por linha)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['label']!,
                  style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
              SizedBox(height: 2.h),
              Text(item['value']!,
                  style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSimpleInfo(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        SizedBox(height: 2.h),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
    bool isOutlined = false,
    required bool isDark,
  }) {
    final tileColor = isOutlined
        ? (isDark ? Colors.white10 : Colors.white)
        : (isDark ? color.withOpacity(0.15) : color.withOpacity(0.08));

    final borderColor = isOutlined
        ? (isDark ? color.withOpacity(0.5) : color.withOpacity(0.5))
        : BorderSide.none.color;

    return Material(
      color: tileColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: isOutlined
            ? BorderSide(color: borderColor, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: color))
              else
                Icon(icon, color: color, size: 28.sp),
              SizedBox(height: 8.h),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade200 : color.withOpacity(0.9),
                  fontSize: 12.sp,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
          color: Colors.red.shade50, borderRadius: BorderRadius.circular(8.r)),
      child: Text(error, style: TextStyle(color: Colors.red.shade800)),
    );
  }

  Widget _buildEmptyStateCard(String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
      child: Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return intl.DateFormat('dd/MM/yyyy').format(date);
  }

  String _displayText(String? text, {String defaultValue = 'N/A'}) {
    return (text == null || text.isEmpty) ? defaultValue : text;
  }
}

// --- WIDGET HELPER PARA O AVATAR ---
class StudentAvatar extends StatelessWidget {
  final String studentId;
  final String fullName;
  final double radius;
  final double fontSize;

  const StudentAvatar({
    Key? key,
    required this.studentId,
    required this.fullName,
    required this.radius,
    required this.fontSize,
    required bool hasEnrollment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String initials = '';
    if (fullName.isNotEmpty) {
      List<String> parts = fullName.trim().split(' ');
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[parts.length - 1][0]}';
      } else {
        initials = parts[0][0];
      }
    }
    initials = initials.toUpperCase();

    final int colorIndex = initials.codeUnitAt(0) % Colors.primaries.length;
    final Color bgColor = Colors.primaries[colorIndex].shade100;
    final Color textColor = Colors.primaries[colorIndex].shade800;

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final studentService = StudentService();

    return FutureBuilder<Uint8List?>(
      future: studentService.getStudentPhoto(studentId, token),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: bgColor,
            child: Text(initials,
                style: GoogleFonts.saira(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.transparent,
            backgroundImage: MemoryImage(snapshot.data!),
          );
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: Text(initials,
              style: GoogleFonts.saira(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: textColor)),
        );
      },
    );
  }
}

// ==========================================================
// --- WIDGETS AUXILIARES (Dialogs de Matrícula e IRPF) ---
// ==========================================================
// Mantive a lógica intacta, apenas ajustando padding e tamanhos

class EnrollmentDialog extends StatefulWidget {
  final Student student;
  const EnrollmentDialog({super.key, required this.student});
  @override
  State<EnrollmentDialog> createState() => _EnrollmentDialogState();
}

class _EnrollmentDialogState extends State<EnrollmentDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoadingClasses = false;
  bool _isSubmitting = false;
  int? _selectedYear;
  String? _selectedClassId;
  ClassModel? _selectedClassDetails;
  final _agreedFeeController = TextEditingController();
  final List<int> _yearOptions =
      List.generate(4, (index) => DateTime.now().year - 1 + index);
  List<ClassModel> _availableClasses = [];
  late ClassProvider _classProvider;
  final EnrollmentService _enrollmentService = EnrollmentService();

  @override
  void initState() {
    super.initState();
    _classProvider = Provider.of<ClassProvider>(context, listen: false);
    _selectedYear = DateTime.now().year;
    _fetchClassesForYear(_selectedYear!);
  }

  @override
  void dispose() {
    _agreedFeeController.dispose();
    super.dispose();
  }

  Future<void> _fetchClassesForYear(int year) async {
    setState(() {
      _isLoadingClasses = true;
      _availableClasses = [];
      _selectedClassId = null;
      _selectedClassDetails = null;
      _agreedFeeController.text = '';
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token != null) {
      try {
        final classes =
            await _classProvider.fetchActiveClassesByYear(token, year);
        if (mounted)
          setState(() => _availableClasses = classes
            ..sort((a, b) => a.name.compareTo(b.name)));
      } catch (e) {
        if (mounted) _showError("Erro ao buscar turmas: $e");
      } finally {
        if (mounted) setState(() => _isLoadingClasses = false);
      }
    }
  }

  void _onClassSelected(String? classId) {
    if (classId == null) {
      setState(() {
        _selectedClassId = null;
        _selectedClassDetails = null;
        _agreedFeeController.text = '';
      });
      return;
    }
    final selected = _availableClasses.firstWhere((c) => c.id == classId);
    setState(() {
      _selectedClassId = classId;
      _selectedClassDetails = selected;
      _agreedFeeController.text =
          selected.monthlyFee.toStringAsFixed(2).replaceAll('.', ',');
    });
  }

  Future<void> _submitEnrollment() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      final agreedFee =
          double.tryParse(_agreedFeeController.text.replaceAll(',', '.'));
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (_selectedClassId == null || agreedFee == null || token == null) {
        _showError('Dados inválidos.');
        setState(() => _isSubmitting = false);
        return;
      }
      try {
        await _enrollmentService.createEnrollment(
            studentId: widget.student.id,
            classId: _selectedClassId!,
            agreedFee: agreedFee,
            token: token);
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), backgroundColor: Colors.orange.shade800));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
        decoration: BoxDecoration(
            color: isDark ? Colors.green.shade900 : Colors.green.shade700,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15.r),
                topRight: Radius.circular(15.r))),
        child: Row(children: [
          Icon(PhosphorIcons.student_bold, color: Colors.white, size: 24.sp),
          SizedBox(width: 10.w),
          Text('Matricular Aluno',
              style: GoogleFonts.sairaCondensed(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                  color: Colors.white))
        ]),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildDropdown<int>(
                _selectedYear,
                'Ano Letivo',
                _yearOptions
                    .map((y) =>
                        DropdownMenuItem(value: y, child: Text(y.toString())))
                    .toList(),
                PhosphorIcons.calendar_blank_bold, (val) {
              if (val != null) {
                setState(() => _selectedYear = val);
                _fetchClassesForYear(val);
              }
            }),
            SizedBox(height: 15.h),
            _buildDropdown<String>(
                _selectedClassId,
                'Turma',
                _availableClasses
                    .map((t) => DropdownMenuItem(
                        value: t.id, child: Text('${t.name} (${t.shift})')))
                    .toList(),
                PhosphorIcons.chalkboard_teacher_bold,
                _onClassSelected,
                disabled: _isLoadingClasses),
            SizedBox(height: 15.h),
            TextFormField(
              controller: _agreedFeeController,
              decoration: buildInputDecoration(
                  context, 'Mensalidade (R\$)', PhosphorIcons.money_bold),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
            )
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: _isSubmitting ? null : _submitEnrollment,
            child: const Text('Confirmar'))
      ],
    );
  }

  Widget _buildDropdown<T>(T? val, String label,
      List<DropdownMenuItem<T>> items, IconData icon, Function(T?)? onChanged,
      {bool disabled = false}) {
    return DropdownButtonFormField2<T>(
      value: val,
      decoration: buildInputDecoration(context, label, icon),
      items: items,
      onChanged: disabled ? null : onChanged,
      isExpanded: true,
      dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10.r))),
    );
  }
}

class _IncomeTaxInputDialog extends StatefulWidget {
  final List<TutorInStudent> tutors;
  const _IncomeTaxInputDialog({super.key, required this.tutors});
  @override
  State<_IncomeTaxInputDialog> createState() => _IncomeTaxInputDialogState();
}

class _IncomeTaxInputDialogState extends State<_IncomeTaxInputDialog> {
  final _formKey = GlobalKey<FormState>();
  Tutor? _selectedTutor;
  final _amountController = TextEditingController();
  final _periodController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.tutors.isNotEmpty)
      _selectedTutor = widget.tutors.first.tutorInfo;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      backgroundColor: theme.cardColor,
      title: Text('Dados IRPF',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<Tutor>(
            value: _selectedTutor,
            dropdownColor: theme.cardColor,
            items: widget.tutors
                .map((t) => DropdownMenuItem(
                    value: t.tutorInfo,
                    child: Text(t.tutorInfo.fullName,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black))))
                .toList(),
            onChanged: (v) => setState(() => _selectedTutor = v),
            decoration: buildInputDecoration(
                context, 'Responsável', PhosphorIcons.user),
          ),
          SizedBox(height: 10.h),
          TextFormField(
              controller: _amountController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: buildInputDecoration(
                  context, 'Valor Total', PhosphorIcons.money)),
          SizedBox(height: 10.h),
          TextFormField(
              controller: _periodController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: buildInputDecoration(
                  context, 'Período', PhosphorIcons.calendar)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate() && _selectedTutor != null) {
                Navigator.pop(context, {
                  'tutor': _selectedTutor,
                  'amount':
                      double.parse(_amountController.text.replaceAll(',', '.')),
                  'period': _periodController.text
                });
              }
            },
            child: const Text('Gerar'))
      ],
    );
  }
}
