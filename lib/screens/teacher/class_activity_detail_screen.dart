import 'package:academyhub_mobile/model/class_activity_model.dart';
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/providers/academic_calendar_provider.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_activity_detail_provider.dart';
import 'package:academyhub_mobile/providers/horario_provider.dart';
import 'package:academyhub_mobile/screens/teacher/create_edit_class_activity_screen.dart';
import 'package:academyhub_mobile/util/teacher_class_context_helper.dart';
import 'package:academyhub_mobile/widgets/attendance_operation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ClassActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final ClassModel fallbackClassData;

  const ClassActivityDetailScreen({
    super.key,
    required this.activityId,
    required this.fallbackClassData,
  });

  @override
  State<ClassActivityDetailScreen> createState() =>
      _ClassActivityDetailScreenState();
}

class _ClassActivityDetailScreenState extends State<ClassActivityDetailScreen> {
  final ClassActivityDetailProvider _provider = ClassActivityDetailProvider();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, TextEditingController> _noteControllers = {};
  final Map<String, TextEditingController> _scoreControllers = {};

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    _searchController.dispose();
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) {
    return _provider.load(
      context.read<AuthProvider>(),
      activityId: widget.activityId,
      refresh: refresh,
    );
  }

  Future<bool> _handleBack() async {
    if (!_provider.hasPendingChanges) return true;

    final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Alterações não salvas'),
            content: const Text(
              'Você tem ajustes pendentes nas entregas. Deseja sair mesmo assim?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continuar aqui'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sair'),
              ),
            ],
          ),
        ) ??
        false;

    return shouldLeave;
  }

  Future<void> _openEditActivity(ClassActivity activity) async {
    final authProvider = context.read<AuthProvider>();
    final horarioProvider = context.read<HorarioProvider>();
    final academicProvider = context.read<AcademicCalendarProvider>();
    final availableSubjects = TeacherClassContextHelper.subjectsForClass(
      classId: widget.fallbackClassData.id,
      horarios: horarioProvider.horarios,
      user: authProvider.user,
      terms: academicProvider.terms,
    );

    SubjectModel? suggestedSubject;
    if (activity.subject != null) {
      for (final subject in availableSubjects) {
        if (subject.id == activity.subject!.id) {
          suggestedSubject = subject;
          break;
        }
      }
    }

    final result = await Navigator.of(context).push<ClassActivity>(
      MaterialPageRoute(
        builder: (_) => CreateEditClassActivityScreen(
          classData: widget.fallbackClassData,
          activity: activity,
          availableSubjects: availableSubjects,
          suggestedSubject: suggestedSubject,
        ),
      ),
    );

    if (result != null && mounted) {
      await _loadData(refresh: true);
    }
  }

  Future<void> _cancelActivity() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancelar atividade'),
            content: const Text(
              'A atividade será cancelada logicamente e continuará no histórico. Deseja continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Voltar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cancelar atividade'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final success = await showAttendanceOperationDialog(
      context: context,
      loadingTitle: 'Cancelando atividade',
      loadingMessage: 'Atualizando o status da atividade da turma...',
      successTitle: 'Atividade cancelada',
      successMessage: 'A atividade foi movida para o histórico.',
      operation: () async {
        await _provider.cancelActivity(context.read<AuthProvider>());
      },
    );

    if (success == true && mounted) {
      await _loadData(refresh: true);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _saveBulkChanges() async {
    final success = await showAttendanceOperationDialog(
      context: context,
      loadingTitle: 'Salvando alterações',
      loadingMessage: 'Enviando as entregas em lote para a turma...',
      successTitle: 'Alterações salvas',
      successMessage: 'As entregas dos alunos foram atualizadas com sucesso.',
      operation: () async {
        await _provider.saveChanges(context.read<AuthProvider>());
      },
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entregas atualizadas com sucesso.')),
      );
    }
  }

  void _syncControllerCache(List<ClassActivitySubmission> students) {
    final validIds = students.map((item) => item.id).toSet();

    final noteKeysToRemove =
        _noteControllers.keys.where((key) => !validIds.contains(key)).toList();
    for (final key in noteKeysToRemove) {
      _noteControllers.remove(key)?.dispose();
    }

    final scoreKeysToRemove =
        _scoreControllers.keys.where((key) => !validIds.contains(key)).toList();
    for (final key in scoreKeysToRemove) {
      _scoreControllers.remove(key)?.dispose();
    }

    for (final submission in students) {
      final noteController = _noteControllers.putIfAbsent(
        submission.id,
        () => TextEditingController(text: submission.teacherNote),
      );
      if (noteController.text != submission.teacherNote) {
        noteController.text = submission.teacherNote;
      }

      final scoreText =
          submission.score == null ? '' : submission.score!.toStringAsFixed(1);
      final scoreController = _scoreControllers.putIfAbsent(
        submission.id,
        () => TextEditingController(text: scoreText),
      );
      if (scoreController.text != scoreText) {
        scoreController.text = scoreText;
      }
    }
  }

  List<ClassActivitySubmission> _filteredStudents(
      List<ClassActivitySubmission> items) {
    if (_searchQuery.isEmpty) return items;

    return items.where((submission) {
      final haystack =
          '${submission.student.fullName} ${submission.student.enrollmentNumber}'
              .toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider<ClassActivityDetailProvider>.value(
      value: _provider,
      child: Consumer<ClassActivityDetailProvider>(
        builder: (context, provider, _) {
          final activity = provider.activity;
          final students = _filteredStudents(provider.students);
          _syncControllerCache(provider.students);

          return WillPopScope(
            onWillPop: _handleBack,
            child: Scaffold(
              backgroundColor:
                  isDark ? const Color(0xFF090C10) : const Color(0xFFF4F7FB),
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor:
                    isDark ? Colors.white : const Color(0xFF1A2230),
                titleSpacing: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Correção da atividade',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      activity?.classInfo.name ?? widget.fallbackClassData.name,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color:
                            isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => _loadData(refresh: true),
                    icon: const Icon(PhosphorIcons.arrow_clockwise),
                  ),
                  if (activity != null)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditActivity(activity);
                        } else if (value == 'cancel') {
                          _cancelActivity();
                        } else if (value == 'all_delivered') {
                          provider.applyBulkStatus(
                            ClassActivityDeliveryStatus.delivered,
                          );
                        } else if (value == 'all_pending') {
                          provider.applyBulkStatus(
                            ClassActivityDeliveryStatus.pending,
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Editar atividade'),
                        ),
                        if (activity.status != ClassActivityStatus.cancelled)
                          const PopupMenuItem<String>(
                            value: 'all_delivered',
                            child: Text('Marcar todos como entregues'),
                          ),
                        if (activity.status != ClassActivityStatus.cancelled)
                          const PopupMenuItem<String>(
                            value: 'all_pending',
                            child: Text('Definir todos como pendentes'),
                          ),
                        if (activity.status != ClassActivityStatus.cancelled)
                          const PopupMenuItem<String>(
                            value: 'cancel',
                            child: Text('Cancelar atividade'),
                          ),
                      ],
                    ),
                ],
              ),
              bottomNavigationBar: provider.hasPendingChanges
                  ? _SaveBar(
                      pendingCount: provider.pendingChangeCount,
                      isSaving: provider.isSaving,
                      onSave: _saveBulkChanges,
                    )
                  : null,
              body: _buildBody(
                isDark: isDark,
                provider: provider,
                activity: activity,
                students: students,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody({
    required bool isDark,
    required ClassActivityDetailProvider provider,
    required ClassActivity? activity,
    required List<ClassActivitySubmission> students,
  }) {
    if (provider.isLoading && activity == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && activity == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.warning_circle_fill,
                size: 36.sp,
                color: Colors.orange,
              ),
              SizedBox(height: 16.h),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                ),
              ),
              SizedBox(height: 14.h),
              ElevatedButton(
                onPressed: () => _loadData(refresh: true),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      child: ListView(
        padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 100.h),
        children: [
          if (activity != null)
            _ActivityHeaderCard(activity: activity, isDark: isDark),
          SizedBox(height: 16.h),
          _BulkActionCard(
            isDark: isDark,
            hasPendingChanges: provider.hasPendingChanges,
            isCancelled: activity?.status == ClassActivityStatus.cancelled,
            onMarkDelivered: () => provider.applyBulkStatus(
              ClassActivityDeliveryStatus.delivered,
            ),
            onMarkPending: () => provider.applyBulkStatus(
              ClassActivityDeliveryStatus.pending,
            ),
          ),
          SizedBox(height: 16.h),
          _StudentSearchField(
            controller: _searchController,
            isDark: isDark,
          ),
          SizedBox(height: 16.h),
          if (students.isEmpty)
            _EmptyStudentsState(isDark: isDark)
          else
            ...students.map(
              (submission) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _SubmissionCard(
                  submission: submission,
                  activity: activity,
                  isDark: isDark,
                  noteController: _noteControllers[submission.id]!,
                  scoreController: _scoreControllers[submission.id]!,
                  isExpanded:
                      provider.expandedSubmissionIds.contains(submission.id),
                  onToggleExpanded: () =>
                      provider.toggleExpanded(submission.id),
                  onStatusSelected: (status) =>
                      provider.applyDeliveryStatus(submission.id, status),
                  onCorrectedChanged: (value) =>
                      provider.applyCorrected(submission.id, value),
                  onScoreChanged: (value) {
                    final normalized = value.trim().replaceAll(',', '.');
                    provider.applyScore(
                      submission.id,
                      normalized.isEmpty ? null : double.tryParse(normalized),
                    );
                  },
                  onNoteChanged: (value) =>
                      provider.applyTeacherNote(submission.id, value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final int pendingCount;
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveBar({
    required this.pendingCount,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF11161D)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$pendingCount aluno(s) com ajuste pendente',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            ElevatedButton.icon(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A859),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              icon: const Icon(PhosphorIcons.floppy_disk),
              label: Text(
                'Salvar em lote',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityHeaderCard extends StatelessWidget {
  final ClassActivity activity;
  final bool isDark;

  const _ActivityHeaderCard({
    required this.activity,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final due = activity.dueDate == null
        ? 'Sem prazo'
        : DateFormat('dd/MM/yyyy').format(activity.dueDate!);
    final correction = activity.correctionDate == null
        ? 'Sem data'
        : DateFormat('dd/MM/yyyy').format(activity.correctionDate!);

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
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _HeaderTag(label: activity.workflowState.label),
              _HeaderTag(label: activity.activityType.label),
              if (activity.isGraded)
                _HeaderTag(
                  label:
                      'Vale ${activity.maxScore?.toStringAsFixed(1) ?? '10'}',
                ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            activity.title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24.sp,
            ),
          ),
          if (activity.sourceReference.trim().isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              activity.sourceReference,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.86),
                fontSize: 13.5.sp,
                height: 1.4,
              ),
            ),
          ],
          if (activity.description.trim().isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              activity.description,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.74),
                fontSize: 12.5.sp,
                height: 1.45,
              ),
            ),
          ],
          SizedBox(height: 18.h),
          Row(
            children: [
              _HeaderMetric(label: 'Prazo', value: due),
              _HeaderMetric(label: 'Correção', value: correction),
              _HeaderMetric(
                label: 'Pendentes',
                value: '${activity.summary.pendingCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderTag extends StatelessWidget {
  final String label;

  const _HeaderTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11.sp,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkActionCard extends StatelessWidget {
  final bool isDark;
  final bool hasPendingChanges;
  final bool isCancelled;
  final VoidCallback onMarkDelivered;
  final VoidCallback onMarkPending;

  const _BulkActionCard({
    required this.isDark,
    required this.hasPendingChanges,
    required this.isCancelled,
    required this.onMarkDelivered,
    required this.onMarkPending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14181F) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF262D37) : const Color(0xFFE7EBF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.lightning_fill,
                color: const Color(0xFFF2994A),
                size: 18.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  hasPendingChanges
                      ? 'Você tem ajustes não salvos'
                      : 'Ações rápidas da turma',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A2230),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            isCancelled
                ? 'Atividade cancelada: a correção foi bloqueada.'
                : 'Use o lote para marcar a maioria dos alunos e ajuste só as exceções.',
            style: GoogleFonts.inter(
              fontSize: 12.5.sp,
              height: 1.4,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
          if (!isCancelled) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMarkDelivered,
                    icon: const Icon(PhosphorIcons.check_circle_fill),
                    label: const Text('Todos entregaram'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMarkPending,
                    icon: const Icon(PhosphorIcons.arrow_counter_clockwise),
                    label: const Text('Voltar pendentes'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentSearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _StudentSearchField({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(
        fontSize: 14.sp,
        color: isDark ? Colors.white : const Color(0xFF1A2230),
      ),
      decoration: InputDecoration(
        hintText: 'Buscar aluno por nome ou matrícula...',
        hintStyle: GoogleFonts.inter(
          color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(
          PhosphorIcons.magnifying_glass,
          color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF14181F) : Colors.white,
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
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final ClassActivitySubmission submission;
  final ClassActivity? activity;
  final bool isDark;
  final TextEditingController noteController;
  final TextEditingController scoreController;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<ClassActivityDeliveryStatus> onStatusSelected;
  final ValueChanged<bool> onCorrectedChanged;
  final ValueChanged<String> onScoreChanged;
  final ValueChanged<String> onNoteChanged;

  const _SubmissionCard({
    required this.submission,
    required this.activity,
    required this.isDark,
    required this.noteController,
    required this.scoreController,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onStatusSelected,
    required this.onCorrectedChanged,
    required this.onScoreChanged,
    required this.onNoteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = activity?.status != ClassActivityStatus.cancelled;
    final showDetails = isExpanded ||
        submission.teacherNote.trim().isNotEmpty ||
        submission.score != null;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14181F) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF262D37) : const Color(0xFFE7EBF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarBubble(name: submission.student.fullName),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.student.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A2230),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.identification_card,
                          size: 14.sp,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF64748B),
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            submission.student.enrollmentNumber.isEmpty
                                ? 'Sem matrícula'
                                : submission.student.enrollmentNumber,
                            style: GoogleFonts.inter(
                              fontSize: 12.5.sp,
                              color: isDark
                                  ? Colors.grey[400]
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (submission.score != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A859).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        submission.score!.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF00A859),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: onToggleExpanded,
                    icon: Icon(
                      isExpanded
                          ? PhosphorIcons.caret_up_bold
                          : PhosphorIcons.caret_down_bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: ClassActivityDeliveryStatus.values.map((status) {
              final isSelected = submission.deliveryStatus == status;
              return _StatusChoiceChip(
                label: status.shortLabel,
                selected: isSelected,
                color: _statusColor(status),
                enabled: canEdit,
                onTap: () => onStatusSelected(status),
              );
            }).toList(),
          ),
          if (!submission.isCurrentClassMember) ...[
            SizedBox(height: 12.h),
            _InfoBadge(
              icon: PhosphorIcons.user_switch,
              label: 'Aluno fora da turma atual',
              color: const Color(0xFFF2994A),
            ),
          ],
          if (showDetails) ...[
            SizedBox(height: 14.h),
            Divider(
                color:
                    isDark ? const Color(0xFF262D37) : const Color(0xFFE7EBF2)),
            SizedBox(height: 12.h),
            if (submission.deliveryStatus.allowsCorrection) ...[
              _MiniToggle(
                title: 'Corrigido',
                value: submission.isCorrected,
                enabled: canEdit,
                onChanged: onCorrectedChanged,
              ),
              if ((activity?.isGraded ?? false) && submission.isCorrected) ...[
                SizedBox(height: 12.h),
                TextField(
                  controller: scoreController,
                  enabled: canEdit,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: isDark ? Colors.white : const Color(0xFF1A2230),
                  ),
                  decoration: _inlineDecoration(
                    context,
                    label: 'Nota',
                    icon: PhosphorIcons.hash,
                  ),
                  onSubmitted: onScoreChanged,
                  onTapOutside: (_) => onScoreChanged(scoreController.text),
                ),
              ],
              SizedBox(height: 12.h),
            ],
            TextField(
              controller: noteController,
              enabled: canEdit,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: isDark ? Colors.white : const Color(0xFF1A2230),
              ),
              decoration: _inlineDecoration(
                context,
                label: 'Observação do professor',
                icon: PhosphorIcons.note_pencil,
              ),
              onChanged: onNoteChanged,
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(ClassActivityDeliveryStatus status) {
    switch (status) {
      case ClassActivityDeliveryStatus.pending:
        return const Color(0xFF64748B);
      case ClassActivityDeliveryStatus.delivered:
        return const Color(0xFF00A859);
      case ClassActivityDeliveryStatus.partial:
        return const Color(0xFFF2994A);
      case ClassActivityDeliveryStatus.notDelivered:
        return const Color(0xFFEF4444);
      case ClassActivityDeliveryStatus.excused:
        return const Color(0xFF1769FF);
    }
  }

  InputDecoration _inlineDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: dark ? Colors.grey[300] : const Color(0xFF475569),
      ),
      prefixIcon: Icon(
        icon,
        color: dark ? Colors.grey[400] : const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: dark ? const Color(0xFF11161D) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF2A313B) : const Color(0xFFE7EBF2),
        ),
      ),
    );
  }
}

class _StatusChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _StatusChoiceChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.35),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: enabled ? color : color.withOpacity(0.45),
          ),
        ),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _MiniToggle({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: const Color(0xFF00A859),
        ),
      ],
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final String name;

  const _AvatarBubble({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts =
        name.trim().split(' ').where((item) => item.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((item) => item[0].toUpperCase()).join();

    return Container(
      width: 46.w,
      height: 46.w,
      decoration: BoxDecoration(
        color: const Color(0xFF1769FF).withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1769FF),
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStudentsState extends StatelessWidget {
  final bool isDark;

  const _EmptyStudentsState({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14181F) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? const Color(0xFF262D37) : const Color(0xFFE7EBF2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            PhosphorIcons.users_three,
            size: 32.sp,
            color: const Color(0xFF1769FF),
          ),
          SizedBox(height: 16.h),
          Text(
            'Nenhum aluno encontrado',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A2230),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Ajuste a busca ou recarregue a atividade para revisar a lista.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
