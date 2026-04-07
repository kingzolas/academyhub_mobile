import 'package:academyhub_mobile/model/class_activity_model.dart';
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/class_activity_service.dart';
import 'package:academyhub_mobile/widgets/attendance_operation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CreateEditClassActivityScreen extends StatefulWidget {
  final ClassModel classData;
  final ClassActivity? activity;
  final List<SubjectModel> availableSubjects;
  final SubjectModel? suggestedSubject;

  const CreateEditClassActivityScreen({
    super.key,
    required this.classData,
    this.activity,
    this.availableSubjects = const [],
    this.suggestedSubject,
  });

  @override
  State<CreateEditClassActivityScreen> createState() =>
      _CreateEditClassActivityScreenState();
}

class _CreateEditClassActivityScreenState
    extends State<CreateEditClassActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceReferenceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxScoreController = TextEditingController();
  final ClassActivityService _service = ClassActivityService();

  late ClassActivityType _activityType;
  late ClassActivitySourceType _sourceType;
  late DateTime _assignedAt;
  late DateTime _dueDate;
  DateTime? _correctionDate;
  late bool _isGraded;
  late bool _visibilityToGuardians;
  bool _showAdvanced = false;

  String? _selectedSubjectId;

  bool get _isEditing => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;

    _activityType = activity?.activityType ?? ClassActivityType.homework;
    _sourceType = activity?.sourceType ?? ClassActivitySourceType.book;
    _assignedAt = _normalizeDate(activity?.assignedAt ?? DateTime.now());
    _dueDate = _normalizeDate(
      activity?.dueDate ?? DateTime.now().add(const Duration(days: 1)),
    );
    _correctionDate =
        activity?.correctionDate == null ? null : _normalizeDate(activity!.correctionDate!);
    _isGraded = activity?.isGraded ?? false;
    _visibilityToGuardians = activity?.visibilityToGuardians ?? false;
    _selectedSubjectId = activity?.subject?.id ?? widget.suggestedSubject?.id;

    _titleController.text = activity?.title ?? '';
    _sourceReferenceController.text = activity?.sourceReference ?? '';
    _descriptionController.text = activity?.description ?? '';
    _maxScoreController.text = activity?.maxScore == null
        ? '10'
        : activity!.maxScore!.toStringAsFixed(
            activity.maxScore!.truncateToDouble() == activity.maxScore ? 0 : 1,
          );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceReferenceController.dispose();
    _descriptionController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day, 12);
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
    DateTime? firstDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null) {
      onSelected(_normalizeDate(picked));
    }
  }

  ClassActivityUpsertInput _buildInput() {
    final maxScoreText = _maxScoreController.text.trim().replaceAll(',', '.');
    final maxScore = maxScoreText.isEmpty ? null : double.tryParse(maxScoreText);

    return ClassActivityUpsertInput(
      title: _titleController.text,
      description: _descriptionController.text,
      activityType: _activityType,
      sourceType: _sourceType,
      sourceReference: _sourceReferenceController.text,
      isGraded: _isGraded,
      maxScore: _isGraded ? maxScore : null,
      assignedAt: _assignedAt,
      dueDate: _dueDate,
      correctionDate: _correctionDate,
      subjectId: _selectedSubjectId,
      visibilityToGuardians: _visibilityToGuardians,
      status: widget.activity?.status,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dueDate.isBefore(_assignedAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data de entrega nao pode ser anterior a disponibilizacao.'),
        ),
      );
      return;
    }

    if (_correctionDate != null && _correctionDate!.isBefore(_dueDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data de correcao precisa ser igual ou posterior ao prazo.'),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final classId = widget.classData.id;

    if (token == null || token.trim().isEmpty || classId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel identificar sua sessao.')),
      );
      return;
    }

    final input = _buildInput();
    ClassActivity? savedActivity;

    final success = await showAttendanceOperationDialog(
      context: context,
      loadingTitle: _isEditing ? 'Atualizando atividade' : 'Criando atividade',
      loadingMessage: _isEditing
          ? 'Salvando os ajustes da atividade da turma...'
          : 'Registrando a nova atividade da turma...',
      successTitle: _isEditing ? 'Atividade atualizada' : 'Atividade criada',
      successMessage: _isEditing
          ? 'A atividade foi atualizada com sucesso.'
          : 'A atividade ja esta pronta para a turma.',
      operation: () async {
        savedActivity = _isEditing
            ? await _service.update(
                token: token,
                activityId: widget.activity!.id,
                input: input,
              )
            : await _service.create(
                token: token,
                classId: classId,
                input: input,
              );
      },
    );

    if (!mounted) return;

    if (success == true && savedActivity != null) {
      Navigator.of(context).pop(savedActivity);
      return;
    }

    if (success == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel salvar a atividade.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090C10) : const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1A2230),
        title: Text(
          _isEditing ? 'Editar atividade' : 'Nova atividade',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          child: SizedBox(
            height: 52.h,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(
                _isEditing ? PhosphorIcons.floppy_disk : PhosphorIcons.plus_circle,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A859),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
              ),
              label: Text(
                _isEditing ? 'Salvar alteracoes' : 'Criar atividade',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.sp,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 110.h),
          children: [
            _TopSummaryCard(
              classData: widget.classData,
              dueDate: _dueDate,
              isDark: isDark,
            ),
            SizedBox(height: 18.h),
            _SectionCard(
              title: 'Essencial',
              subtitle: 'O minimo para lancar rapido no celular.',
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(title: 'Tipo da atividade'),
                  _ChoiceWrap<ClassActivityType>(
                    options: ClassActivityType.values,
                    selected: _activityType,
                    labelBuilder: (item) => item.label,
                    onSelected: (item) => setState(() => _activityType = item),
                  ),
                  SizedBox(height: 16.h),
                  _SectionLabel(title: 'Origem'),
                  _ChoiceWrap<ClassActivitySourceType>(
                    options: ClassActivitySourceType.values,
                    selected: _sourceType,
                    labelBuilder: (item) => item.label,
                    onSelected: (item) => setState(() => _sourceType = item),
                  ),
                  SizedBox(height: 18.h),
                  _InputField(
                    controller: _sourceReferenceController,
                    label: 'Referencia curta *',
                    hint: 'Ex.: Portugues pag. 58',
                    icon: PhosphorIcons.notepad,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Informe a referencia da atividade.';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Se o titulo ficar vazio, o app usa esta referencia como base.',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  _DateTile(
                    icon: PhosphorIcons.calendar_check,
                    title: 'Data de entrega',
                    value: DateFormat('dd/MM/yyyy').format(_dueDate),
                    onTap: () => _pickDate(
                      initialDate: _dueDate,
                      onSelected: (value) => setState(() => _dueDate = value),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  _ToggleTile(
                    title: 'Vale nota?',
                    subtitle: 'Mostra campo de pontuacao e nota por aluno.',
                    value: _isGraded,
                    onChanged: (value) => setState(() => _isGraded = value),
                  ),
                  if (_isGraded) ...[
                    SizedBox(height: 16.h),
                    _InputField(
                      controller: _maxScoreController,
                      label: 'Pontuacao maxima',
                      hint: '10',
                      icon: PhosphorIcons.hash,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (!_isGraded) return null;
                        final parsed =
                            double.tryParse((value ?? '').replaceAll(',', '.'));
                        if (parsed == null || parsed <= 0) {
                          return 'Informe uma pontuacao valida.';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _SectionCard(
              title: 'Mais opcoes',
              subtitle:
                  'Abra apenas quando quiser detalhar mais, planejar ou ajustar a correcao.',
              isDark: isDark,
              child: Column(
                children: [
                  _ExpandableHeader(
                    isExpanded: _showAdvanced,
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  ),
                  if (_showAdvanced) ...[
                    SizedBox(height: 18.h),
                    _InputField(
                      controller: _titleController,
                      label: 'Titulo opcional',
                      hint: 'Ex.: Leitura do capitulo 3',
                      icon: PhosphorIcons.text_t,
                    ),
                    SizedBox(height: 16.h),
                    _InputField(
                      controller: _descriptionController,
                      label: 'Descricao',
                      hint: 'Orientacoes extras para a turma',
                      icon: PhosphorIcons.chat_text,
                      maxLines: 4,
                    ),
                    if (widget.availableSubjects.isNotEmpty) ...[
                      SizedBox(height: 16.h),
                      DropdownButtonFormField<String?>(
                        value: _selectedSubjectId,
                        decoration: _buildDecoration(
                          label: 'Disciplina',
                          icon: PhosphorIcons.book_bookmark,
                          isDark: isDark,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sem disciplina definida'),
                          ),
                          ...widget.availableSubjects.map(
                            (subject) => DropdownMenuItem<String?>(
                              value: subject.id,
                              child: Text(subject.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSubjectId = value);
                        },
                      ),
                    ],
                    SizedBox(height: 16.h),
                    _DateTile(
                      icon: PhosphorIcons.timer,
                      title: 'Disponibilizar em',
                      value: DateFormat('dd/MM/yyyy').format(_assignedAt),
                      onTap: () => _pickDate(
                        initialDate: _assignedAt,
                        onSelected: (value) => setState(() => _assignedAt = value),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _DateTile(
                      icon: PhosphorIcons.check_square_offset,
                      title: 'Data de correcao',
                      value: _correctionDate == null
                          ? 'Opcional'
                          : DateFormat('dd/MM/yyyy').format(_correctionDate!),
                      onTap: () => _pickDate(
                        initialDate: _correctionDate ?? _dueDate,
                        firstDate: _dueDate,
                        onSelected: (value) =>
                            setState(() => _correctionDate = value),
                      ),
                      onClear: _correctionDate == null
                          ? null
                          : () => setState(() => _correctionDate = null),
                    ),
                    SizedBox(height: 12.h),
                    _ToggleTile(
                      title: 'Visivel para responsaveis',
                      subtitle:
                          'Mantem a atividade preparada para uso futuro fora do professor.',
                      value: _visibilityToGuardians,
                      onChanged: (value) => setState(
                        () => _visibilityToGuardians = value,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: isDark ? Colors.grey[300] : const Color(0xFF475569),
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF14181F) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18.r),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18.r),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18.r),
        borderSide: const BorderSide(color: Color(0xFF00A859), width: 1.3),
      ),
    );
  }
}

class _TopSummaryCard extends StatelessWidget {
  final ClassModel classData;
  final DateTime dueDate;
  final bool isDark;

  const _TopSummaryCard({
    required this.classData,
    required this.dueDate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF151B24), Color(0xFF0F172A)]
              : const [Color(0xFF0F172A), Color(0xFF1769FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            classData.name,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Lancamento rapido para a turma com prazo em ${DateFormat('dd/MM').format(dueDate)}.',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14181F) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? const Color(0xFF262D37) : const Color(0xFFE7EBF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A2230),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              height: 1.45,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 18.h),
          child,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey[300] : const Color(0xFF334155),
        ),
      ),
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onSelected;

  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: options.map((item) {
        final isSelected = item == selected;
        return InkWell(
          onTap: () => onSelected(item),
          borderRadius: BorderRadius.circular(999.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00A859)
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A2028)
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              labelBuilder(item),
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[300]
                        : const Color(0xFF475569),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String? value)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        fontSize: 14.sp,
        color: isDark ? Colors.white : const Color(0xFF1A2230),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
          color: isDark ? Colors.grey[300] : const Color(0xFF475569),
        ),
        hintStyle: GoogleFonts.inter(
          color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF14181F) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: const BorderSide(color: Color(0xFF00A859), width: 1.3),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14181F) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: const Color(0xFF00A859).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: const Color(0xFF00A859), size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A2230),
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(PhosphorIcons.x_circle_fill),
                color: Colors.redAccent,
              )
            else
              Icon(
                PhosphorIcons.caret_right,
                color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14181F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A2230),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    height: 1.4,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF00A859),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ExpandableHeader extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _ExpandableHeader({
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14181F) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.sliders_horizontal,
              color: const Color(0xFF1769FF),
              size: 18.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                isExpanded ? 'Ocultar opcoes extras' : 'Mostrar opcoes extras',
                style: GoogleFonts.inter(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A2230),
                ),
              ),
            ),
            Icon(
              isExpanded ? PhosphorIcons.caret_up : PhosphorIcons.caret_down,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
