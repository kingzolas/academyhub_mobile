import 'dart:convert';
import 'package:academyhub_mobile/model/academic_record_model.dart';
import 'package:academyhub_mobile/model/grade_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/student_service.dart';
import 'package:academyhub_mobile/widgets/student_details_popup.dart'; // Reutiliza o buildInputDecoration
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class StudentRecordFormDialog extends StatefulWidget {
  final String studentId;
  final AcademicRecord? recordToEdit;
  final List<SubjectModel> allSubjects;

  const StudentRecordFormDialog({
    super.key,
    required this.studentId,
    this.recordToEdit,
    required this.allSubjects,
  });

  @override
  State<StudentRecordFormDialog> createState() =>
      _StudentRecordFormDialogState();
}

class _StudentRecordFormDialogState extends State<StudentRecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late final TextEditingController _gradeLevelController;
  late final TextEditingController _schoolYearController;
  late final TextEditingController _schoolNameController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _workloadController;
  late final TextEditingController _finalResultController;

  List<Grade> _grades = [];

  final StudentService _studentService = StudentService();
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);

    final record = widget.recordToEdit;
    _gradeLevelController = TextEditingController(text: record?.gradeLevel);
    _schoolYearController =
        TextEditingController(text: record?.schoolYear.toString() ?? '');
    _schoolNameController = TextEditingController(
        text: record?.schoolName ?? 'Escola Sossego da Mamãe');
    _cityController =
        TextEditingController(text: record?.city ?? 'Parauapebas');
    _stateController = TextEditingController(text: record?.state ?? 'PA');
    _workloadController = TextEditingController(text: record?.annualWorkload);
    _finalResultController = TextEditingController(text: record?.finalResult);

    _grades = List.from(record?.grades ?? []);
  }

  @override
  void dispose() {
    _gradeLevelController.dispose();
    _schoolYearController.dispose();
    _schoolNameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _workloadController.dispose();
    _finalResultController.dispose();
    super.dispose();
  }

  void _addGradeRow() {
    setState(() {
      _grades.add(Grade(subjectName: '', gradeValue: ''));
    });
  }

  void _removeGradeRow(int index) {
    setState(() {
      _grades.removeAt(index);
    });
  }

  void _updateGradeSubject(int index, String? newSubjectName) {
    if (newSubjectName != null) {
      setState(() {
        _grades[index] = Grade(
            subjectName: newSubjectName, gradeValue: _grades[index].gradeValue);
      });
    }
  }

  void _updateGradeValue(int index, String newValue) {
    setState(() {
      _grades[index] =
          Grade(subjectName: _grades[index].subjectName, gradeValue: newValue);
    });
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar('Por favor, corrija os erros no formulário.');
      return;
    }

    final token = _authProvider.token;
    if (token == null) {
      _showErrorSnackbar('Erro de autenticação. Tente novamente.');
      return;
    }

    setState(() => _isSaving = true);

    final List<Grade> finalGrades = _grades
        .where((g) => g.subjectName.isNotEmpty && g.gradeValue.isNotEmpty)
        .toList();

    final Map<String, dynamic> recordData = {
      'gradeLevel': _gradeLevelController.text,
      'schoolYear': int.tryParse(_schoolYearController.text) ?? 0,
      'schoolName': _schoolNameController.text,
      'city': _cityController.text,
      'state': _stateController.text,
      'annualWorkload': _workloadController.text,
      'finalResult': _finalResultController.text,
      'grades': finalGrades.map((g) => g.toJson()).toList(),
    };

    final recordPayload = AcademicRecord.fromJson({
      ...recordData,
      '_id': widget.recordToEdit?.id ?? 'temp_id_for_payload',
    });

    try {
      List<AcademicRecord> updatedList;
      if (widget.recordToEdit == null) {
        updatedList = await _studentService.addHistoryRecord(
            token, widget.studentId, recordPayload);
      } else {
        updatedList = await _studentService.updateHistoryRecord(
            token, widget.studentId, widget.recordToEdit!.id, recordPayload);
      }

      if (mounted) Navigator.of(context).pop(updatedList);
    } catch (e) {
      if (mounted) _showErrorSnackbar('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Captura de Tema
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isEditing = widget.recordToEdit != null;

    // Cores dinâmicas para o Header
    final headerColor = isEditing
        ? (isDark ? Colors.blue.shade900 : Colors.blue.shade700)
        : (isDark ? Colors.green.shade900 : Colors.green.shade700);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      backgroundColor: theme.cardColor, // Fundo adaptativo
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 20.h),
      actionsPadding: EdgeInsets.fromLTRB(15.w, 0, 15.w, 15.h),

      // Título
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: headerColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15.r),
            topRight: Radius.circular(15.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                    isEditing
                        ? PhosphorIcons.pencil_simple_line_bold
                        : PhosphorIcons.plus_circle_fill,
                    color: Colors.white,
                    size: 24.sp),
                SizedBox(width: 12.w),
                Text(isEditing ? 'Editar Registro' : 'Adicionar Registro',
                    style: GoogleFonts.sairaCondensed(
                        fontWeight: FontWeight.bold,
                        fontSize: 22.sp,
                        color: Colors.white)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              tooltip: 'Cancelar',
            ),
          ],
        ),
      ),

      // Conteúdo (Formulário)
      content: SizedBox(
        width: 700.w,
        height: 650.h,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Campos Principais ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        _gradeLevelController,
                        'Série / Ano *',
                        PhosphorIcons.graduation_cap_bold,
                        hint: 'Ex: 1º Ano Ens. Fundamental',
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: 15.w),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        _schoolYearController,
                        'Ano Letivo *',
                        PhosphorIcons.calendar_blank_bold,
                        hint: 'Ex: 2024',
                        isNumeric: true,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                _buildTextField(
                  _schoolNameController,
                  'Nome da Escola *',
                  PhosphorIcons.buildings_bold,
                  isDark: isDark,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        _cityController,
                        'Cidade *',
                        PhosphorIcons.map_pin_line_bold,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: 15.w),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        _stateController,
                        'UF *',
                        PhosphorIcons.map_trifold_bold,
                        maxLength: 2,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        _workloadController,
                        'Carga Horária Anual',
                        PhosphorIcons.clock_bold,
                        hint: 'Ex: 800 HRS',
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: 15.w),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        _finalResultController,
                        'Resultado Final *',
                        PhosphorIcons.check_bold,
                        hint: 'Ex: Aprovado',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                // --- Divisor para a Lista de Notas ---
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  child: Row(
                    children: [
                      Text(
                        'Componentes Curriculares (Notas)',
                        style: GoogleFonts.sairaCondensed(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            // Texto adapta cor
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: Icon(PhosphorIcons.plus_bold, size: 14.sp),
                        label: const Text('Adicionar'),
                        style: OutlinedButton.styleFrom(
                          // Cores adaptativas para o botão
                          foregroundColor:
                              isDark ? Colors.blue.shade200 : Colors.blue,
                          side: BorderSide(
                              color:
                                  isDark ? Colors.blue.shade200 : Colors.blue),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 8.h),
                          textStyle: GoogleFonts.inter(
                              fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _isSaving ? null : _addGradeRow,
                      )
                    ],
                  ),
                ),

                // --- Lista Dinâmica de Notas ---
                _buildGradesList(isDark),
              ],
            ),
          ),
        ),
      ),

      // Ações
      actions: [
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          icon: _isSaving
              ? SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Icon(PhosphorIcons.check_circle_fill, size: 18.sp),
          label: Text(_isSaving ? 'Salvando...' : 'Salvar Registro'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isEditing ? Colors.blue.shade700 : Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r)),
            textStyle:
                GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp),
          ),
          onPressed: _isSaving ? null : _submitForm,
        ),
      ],
    );
  }

  Widget _buildGradesList(bool isDark) {
    if (_grades.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Center(
          child: Text(
            'Nenhuma disciplina adicionada.\nClique em "Adicionar" para começar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14.sp),
          ),
        ),
      );
    }

    final subjectOptions = widget.allSubjects
        .map((s) => DropdownMenuItem(
            value: s.name,
            child: Text(s.name,
                style:
                    TextStyle(color: isDark ? Colors.white : Colors.black87))))
        .toList();

    return Column(
      children: List.generate(_grades.length, (index) {
        final grade = _grades[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Dropdown de Disciplina ---
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: grade.subjectName.isEmpty ? null : grade.subjectName,
                  dropdownColor: isDark
                      ? const Color(0xFF2C2C2C)
                      : Colors.white, // Fundo dropdown
                  items: subjectOptions,
                  onChanged: _isSaving
                      ? null
                      : (val) => _updateGradeSubject(index, val),
                  // Passando context para o helper de decoração
                  decoration: buildInputDecoration(context, 'Disciplina *',
                          PhosphorIcons.book_bookmark_bold)
                      .copyWith(
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h, horizontal: 15.w)),
                  style: GoogleFonts.inter(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 15.sp),
                  isExpanded: true,
                  validator: (val) =>
                      (val == null || val.isEmpty) ? 'Obrigatório' : null,
                ),
              ),
              SizedBox(width: 10.w),

              // --- Campo de Nota ---
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: grade.gradeValue,
                  onChanged: (val) => _updateGradeValue(index, val),
                  enabled: !_isSaving,
                  // Passando context para o helper
                  decoration: buildInputDecoration(context, 'Nota *',
                          PhosphorIcons.number_circle_one_bold)
                      .copyWith(
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h, horizontal: 15.w)),
                  style: GoogleFonts.inter(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 15.sp),
                  textAlign: TextAlign.center,
                  validator: (val) =>
                      (val == null || val.isEmpty) ? 'Obrigatório' : null,
                ),
              ),
              SizedBox(width: 10.w),

              // --- Botão Excluir Linha ---
              IconButton(
                icon: Icon(PhosphorIcons.trash_simple_bold,
                    color: Colors.red.shade400),
                onPressed: _isSaving ? null : () => _removeGradeRow(index),
                tooltip: 'Remover Disciplina',
                padding: EdgeInsets.only(top: 8.h),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    bool isNumeric = false,
    int? maxLength,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15.h),
      child: TextFormField(
        controller: controller,
        enabled: !_isSaving,
        // Passando context para o helper
        decoration: buildInputDecoration(context, label, icon, hintText: hint),
        style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
            fontSize: 16.sp),
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        inputFormatters:
            isNumeric ? [FilteringTextInputFormatter.digitsOnly] : [],
        maxLength: maxLength,
        validator: (value) {
          if (label.contains('*') && (value == null || value.trim().isEmpty)) {
            return 'Campo obrigatório';
          }
          return null;
        },
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange.shade800,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          left: 10,
          right: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
    ));
  }
}
