// lib/screens/teacher/screen_teacher_gradebook.dart

import 'package:academyhub_mobile/model/class_grade_model.dart';
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/evaluation_model.dart';
import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:academyhub_mobile/model/evento_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/schedule_provider.dart';
import 'package:academyhub_mobile/providers/subject_provider.dart';
import 'package:academyhub_mobile/screens/teacher/gradebook_service.dart';

import 'package:academyhub_mobile/services/enrollment_service.dart';
import 'package:academyhub_mobile/services/horario_service.dart';
import 'package:academyhub_mobile/screens/class_attendance_screen.dart';
import 'package:academyhub_mobile/widgets/teacher_class_card.dart';
// IMPORTANTE: Import do novo módulo de alunos que criamos
import 'package:academyhub_mobile/screens/teacher/tabs/tab_teacher_students.dart';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ============================================================================
// TELA PRINCIPAL (ORQUESTRADOR DE NAVEGAÇÃO)
// ============================================================================
class ScreenTeacherGradebook extends StatefulWidget {
  const ScreenTeacherGradebook({super.key});

  @override
  State<ScreenTeacherGradebook> createState() => _ScreenTeacherGradebookState();
}

class _ScreenTeacherGradebookState extends State<ScreenTeacherGradebook> {
  ClassModel? _selectedClass;
  Widget? _activeSubScreen; // Para navegação interna (Frequência)

  void _navigateToAttendance(ClassModel classData) {
    setState(() {
      _activeSubScreen = ClassAttendanceScreen(
        classData: classData,
        onBack: () {
          setState(() {
            _activeSubScreen = null;
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Se tiver uma sub-tela ativa (Frequência), mostra ela
    if (_activeSubScreen != null) {
      return _activeSubScreen!;
    }

    // Navegação entre Dashboard (Seleção) e Gradebook (Notas)
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _selectedClass == null
          ? _TeacherDashboardView(
              onClassSelected: (classModel) {
                setState(() => _selectedClass = classModel);
              },
              onOpenAttendance: (classModel) {
                _navigateToAttendance(classModel);
              },
            )
          : ClassGradebookView(
              classModel: _selectedClass!,
              onBack: () {
                setState(() => _selectedClass = null);
              },
            ),
    );
  }
}

// ============================================================================
// DASHBOARD DO PROFESSOR (Refatorado com Módulos)
// ============================================================================
class _TeacherDashboardView extends StatefulWidget {
  final Function(ClassModel) onClassSelected;
  final Function(ClassModel) onOpenAttendance;

  const _TeacherDashboardView({
    required this.onClassSelected,
    required this.onOpenAttendance,
  });

  @override
  State<_TeacherDashboardView> createState() => _TeacherDashboardViewState();
}

class _TeacherDashboardViewState extends State<_TeacherDashboardView>
    with SingleTickerProviderStateMixin {
  // Controller de busca APENAS para turmas (Alunos tem o seu próprio no módulo)
  final _classSearchController = TextEditingController();
  final HorarioService _horarioService = HorarioService();

  late TabController _tabController;

  bool _isLoading = true;
  bool _showOnlyMyClasses = true;
  Set<String> _myClassIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchInitialData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _classSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final user = auth.user;

    if (auth.token == null || user == null) return;

    if (user.roles.map((e) => e.toLowerCase()).contains('admin')) {
      setState(() => _showOnlyMyClasses = false);
    }

    // 1. Busca TODAS as turmas
    await classProvider.fetchClasses(auth.token!);

    // 2. Busca vínculos do professor
    try {
      final mySchedules = await _horarioService
          .getHorarios(auth.token!, filter: {'teacherId': user.id});
      final myIdsSafe = mySchedules.map((h) => h.classInfo.id).toSet();

      if (mounted) {
        setState(() {
          _myClassIds = myIdsSafe;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.blueGrey[900];
    final primaryText = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & TABS ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Gestão Escolar",
                      style: GoogleFonts.sairaCondensed(
                          fontWeight: FontWeight.bold,
                          fontSize: 32.sp,
                          color: textPrimary)),
                  Text("Gerencie turmas, alunos e ocorrências.",
                      style: GoogleFonts.inter(
                          fontSize: 14.sp, color: Colors.grey)),
                ],
              ),

              // TAB BAR (Correção de proporção)
              Container(
                height: 40.h,
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicator: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(6.r),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1), blurRadius: 2)
                      ]),
                  labelColor: primaryText,
                  unselectedLabelColor: Colors.grey[600],
                  labelPadding: EdgeInsets.symmetric(horizontal: 20.w),
                  labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 13.sp),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      child: Row(children: [
                        const Icon(PhosphorIcons.chalkboard_teacher, size: 16),
                        SizedBox(width: 8.w),
                        const Text("Minhas Turmas")
                      ]),
                    ),
                    Tab(
                      child: Row(children: [
                        const Icon(PhosphorIcons.users, size: 16),
                        SizedBox(width: 8.w),
                        const Text("Meus Alunos")
                      ]),
                    ),
                  ],
                ),
              )
            ],
          ),

          SizedBox(height: 25.h),

          // --- CONTEÚDO ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics:
                  const NeverScrollableScrollPhysics(), // Evita swipe acidental
              children: [
                _buildClassesTab(isDark), // Aba Local
                const TabTeacherStudents(), // Aba Modularizada (Meus Alunos)
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Lógica da Aba de Turmas (Grid + Busca)
  Widget _buildClassesTab(bool isDark) {
    return Column(
      children: [
        // Busca de Turmas (Black Block)
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 300.w,
            height: 45.h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8.r),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            child: Row(
              children: [
                Icon(PhosphorIcons.magnifying_glass,
                    color: Colors.white, size: 18.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: _classSearchController,
                    onChanged: (v) => setState(() {}),
                    style:
                        GoogleFonts.inter(color: Colors.white, fontSize: 13.sp),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: "Buscar turma...",
                      hintStyle: GoogleFonts.inter(
                          color: Colors.grey[400], fontSize: 13.sp),
                    ),
                  ),
                ),
                if (_classSearchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _classSearchController.clear()),
                    child:
                        Icon(Icons.close, color: Colors.grey[400], size: 16.sp),
                  )
              ],
            ),
          ),
        ),

        SizedBox(height: 20.h),

        // Grid
        Expanded(
          child: Consumer<ClassProvider>(
            builder: (context, provider, _) {
              final allClasses = provider.classes;

              List<ClassModel> filtered = allClasses.where((c) {
                final matchesSearch = c.name
                    .toLowerCase()
                    .contains(_classSearchController.text.toLowerCase());
                final matchesMyClasses =
                    _showOnlyMyClasses ? _myClassIds.contains(c.id) : true;
                return matchesSearch && matchesMyClasses;
              }).toList();

              if (_isLoading)
                return const Center(child: CircularProgressIndicator());

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.chalkboard,
                          size: 48.sp, color: Colors.grey[300]),
                      SizedBox(height: 10.h),
                      Text("Nenhuma turma encontrada",
                          style:
                              TextStyle(color: Colors.grey, fontSize: 16.sp)),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: EdgeInsets.only(bottom: 20.h),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 380.w,
                  mainAxisSpacing: 20.h,
                  crossAxisSpacing: 20.w,
                  childAspectRatio: 1.6,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, index) => TeacherClassCard(
                  classData: filtered[index],
                  isDark: isDark,
                  onTap: () => widget.onClassSelected(filtered[index]),
                  onOpenAttendance: () =>
                      widget.onOpenAttendance(filtered[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CORE: VISUALIZAÇÃO DE NOTAS (DIÁRIO)
// ============================================================================
class ClassGradebookView extends StatefulWidget {
  final ClassModel classModel;
  final VoidCallback onBack;

  const ClassGradebookView(
      {super.key, required this.classModel, required this.onBack});

  @override
  State<ClassGradebookView> createState() => _ClassGradebookViewState();
}

class _ClassGradebookViewState extends State<ClassGradebookView>
    with SingleTickerProviderStateMixin {
  final GradebookService _gradebookService = GradebookService();
  final EnrollmentService _enrollmentService = EnrollmentService();

  late TabController _tabController;
  final TextEditingController _dropdownSearchController =
      TextEditingController();

  bool _isLoading = true;
  List<Enrollment> _enrollments = [];
  List<EvaluationModel> _evaluations = [];
  List<SubjectModel> _subjects = [];

  SubjectModel? _selectedSubject;
  Map<String, Map<String, ClassGradeModel>> _serverGradesMatrix = {};
  final Map<String, ClassGradeModel> _unsavedChanges = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dropdownSearchController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_unsavedChanges.isNotEmpty) {
      return await _showUnsavedChangesDialog() ?? false;
    }
    widget.onBack();
    return false;
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Alterações não salvas"),
        content: const Text(
            "Você tem notas pendentes. Se sair, perderá as alterações."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context, true);
                widget.onBack();
              },
              child: const Text("Sair sem Salvar")),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, false);
                await _savePendingChanges();
              },
              child: const Text("Salvar e Sair"))
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    final currentUser = authProvider.user;

    if (token == null) return;

    try {
      final subjectProvider =
          Provider.of<SubjectProvider>(context, listen: false);
      await subjectProvider.fetchSubjects(token);
      final allSubjects = subjectProvider.subjects;

      final scheduleProvider =
          Provider.of<ScheduleProvider>(context, listen: false);
      await scheduleProvider.fetchHorariosOnly(classId: widget.classModel.id);

      final classSubjectIds =
          scheduleProvider.horarios.map((h) => h.subjectId).toSet();
      List<SubjectModel> relevantSubjects = [];

      if (classSubjectIds.isNotEmpty) {
        relevantSubjects =
            allSubjects.where((s) => classSubjectIds.contains(s.id)).toList();
      } else {
        relevantSubjects = allSubjects;
      }

      SubjectModel? autoSelectedSubject;
      if (currentUser != null) {
        final mySchedule = scheduleProvider.horarios
            .firstWhereOrNull((h) => h.teacherId == currentUser.id);
        if (mySchedule != null) {
          autoSelectedSubject = relevantSubjects
              .firstWhereOrNull((s) => s.id == mySchedule.subjectId);
        }
      }

      final enrollments = await _enrollmentService.getEnrollments(token,
          filter: {'class': widget.classModel.id, 'status': 'Ativa'});
      enrollments
          .sort((a, b) => a.student.fullName.compareTo(b.student.fullName));

      final evaluations =
          await _gradebookService.getEvaluations(token, widget.classModel.id);
      final grades =
          await _gradebookService.getGradesByClass(token, widget.classModel.id);

      final matrix = <String, Map<String, ClassGradeModel>>{};
      for (var e in enrollments) matrix[e.student.id] = {};
      for (var g in grades) {
        if (matrix.containsKey(g.studentId) && g.evaluationId != null) {
          matrix[g.studentId]![g.evaluationId!] = g;
        }
      }

      if (mounted) {
        setState(() {
          _subjects = relevantSubjects;
          _enrollments = enrollments;
          _evaluations = evaluations;
          _serverGradesMatrix = matrix;
          _unsavedChanges.clear();
          _selectedSubject = autoSelectedSubject ??
              (relevantSubjects.isNotEmpty ? relevantSubjects.first : null);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<EvaluationModel> get _filteredEvaluations {
    if (_selectedSubject == null) return [];
    return _evaluations.where((eval) {
      bool subjectMatch = eval.subjectId == _selectedSubject!.id;
      if (!subjectMatch) return false;
      switch (_tabController.index) {
        case 1:
          return eval.type == 'EXAM';
        case 2:
          return eval.type == 'WORK';
        case 3:
          return ['ACTIVITY', 'PARTICIPATION'].contains(eval.type);
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _savePendingChanges() async {
    if (_unsavedChanges.isEmpty) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()));

    try {
      final changesByEvaluation = <String, List<ClassGradeModel>>{};
      _unsavedChanges.forEach((key, gradeModel) {
        if (!changesByEvaluation.containsKey(gradeModel.evaluationId)) {
          changesByEvaluation[gradeModel.evaluationId!] = [];
        }
        changesByEvaluation[gradeModel.evaluationId]!.add(gradeModel);
      });

      for (var entry in changesByEvaluation.entries) {
        final evalObj = _evaluations.firstWhere((e) => e.id == entry.key);
        await _gradebookService.saveBulkGrades(
            token: token,
            classId: widget.classModel.id,
            evaluation: evalObj,
            grades: entry.value);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Alterações salvas!"),
            backgroundColor: Colors.green));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayEvaluations = _filteredEvaluations;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        floatingActionButton: _unsavedChanges.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _savePendingChanges,
                backgroundColor: Colors.green,
                icon:
                    const Icon(PhosphorIcons.floppy_disk, color: Colors.white),
                label: Text("Salvar Alterações (${_unsavedChanges.length})",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              )
            : null,
        body: Column(
          children: [
            // HEADER DO GRADEBOOK
            Container(
              padding: EdgeInsets.fromLTRB(30.w, 20.h, 30.w, 0),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                          onPressed: () => _onWillPop(),
                          icon: Icon(PhosphorIcons.arrow_left,
                              color: isDark ? Colors.white : Colors.black)),
                      SizedBox(width: 10.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.classModel.name,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20.sp,
                                  color: isDark ? Colors.white : Colors.black)),
                          Text("Gestão de Notas",
                              style: GoogleFonts.inter(
                                  fontSize: 12.sp, color: Colors.grey)),
                        ],
                      ),
                      SizedBox(width: 40.w),

                      // DROPDOWN
                      Expanded(
                        child: Container(
                          height: 50.h,
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(8.r)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton2<SubjectModel>(
                              isExpanded: true,
                              hint: Text('Selecione a Disciplina',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).hintColor)),
                              items: _subjects
                                  .map((item) => DropdownMenuItem<SubjectModel>(
                                      value: item,
                                      child: Text(item.name,
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              value: _selectedSubject,
                              onChanged: (value) {
                                if (_unsavedChanges.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Salve as alterações antes de trocar!"),
                                          backgroundColor: Colors.orange));
                                } else {
                                  setState(() => _selectedSubject = value);
                                }
                              },
                              dropdownStyleData: DropdownStyleData(
                                  maxHeight: 400.h,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: isDark
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.white)),
                              dropdownSearchData: DropdownSearchData(
                                searchController: _dropdownSearchController,
                                searchInnerWidgetHeight: 50,
                                searchInnerWidget: Container(
                                  height: 50,
                                  padding: const EdgeInsets.all(8),
                                  child: TextFormField(
                                    controller: _dropdownSearchController,
                                    decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                        hintText: 'Pesquisar matéria...',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8))),
                                  ),
                                ),
                                searchMatchFn: (item, searchValue) => item
                                    .value!.name
                                    .toLowerCase()
                                    .contains(searchValue.toLowerCase()),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 20.w),
                      ElevatedButton.icon(
                        onPressed: _selectedSubject == null
                            ? null
                            : () {
                                showDialog(
                                    context: context,
                                    builder: (_) => CreateAssessmentDialog(
                                        classId: widget.classModel.id,
                                        className: widget.classModel.name,
                                        preSelectedSubject: _selectedSubject,
                                        onSuccess: _loadData));
                              },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20.w, vertical: 18.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r))),
                        icon: const Icon(PhosphorIcons.plus, size: 18),
                        label: const Text("Agendar Avaliação"),
                      )
                    ],
                  ),
                  SizedBox(height: 20.h),
                  TabBar(
                    controller: _tabController,
                    labelColor: isDark ? Colors.white : Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: isDark ? Colors.white : Colors.black,
                    tabs: const [
                      Tab(text: "TODAS"),
                      Tab(text: "PROVAS"),
                      Tab(text: "TRABALHOS"),
                      Tab(text: "OUTROS")
                    ],
                  )
                ],
              ),
            ),

            // GRID DE NOTAS
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedSubject == null
                      ? Center(
                          child: Text("Selecione uma disciplina para começar.",
                              style: GoogleFonts.inter(
                                  fontSize: 16.sp, color: Colors.grey)))
                      : displayEvaluations.isEmpty
                          ? Center(
                              child: Text(
                                  "Nenhuma avaliação encontrada nesta categoria.",
                                  style: GoogleFonts.inter(
                                      fontSize: 16.sp, color: Colors.grey)))
                          : _buildSpreadsheet(isDark, displayEvaluations),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpreadsheet(
      bool isDark, List<EvaluationModel> evaluationsToShow) {
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final headerBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8F9FA);

    return Column(
      children: [
        Container(
          height: 60.h,
          decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: borderColor, width: 2))),
          child: Row(
            children: [
              Container(
                  width: 250.w,
                  padding: EdgeInsets.only(left: 20.w),
                  alignment: Alignment.centerLeft,
                  child: Text("ALUNOS",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                          color: Colors.grey))),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: evaluationsToShow.length,
                  itemBuilder: (context, index) {
                    final eval = evaluationsToShow[index];
                    return Container(
                      width: 140.w,
                      decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: borderColor))),
                      padding: EdgeInsets.symmetric(horizontal: 5.w),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(eval.title,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold, fontSize: 13.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                              "${DateFormat('dd/MM').format(eval.date)} • Max: ${eval.maxScore}",
                              style: GoogleFonts.inter(
                                  fontSize: 11.sp, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _enrollments.length,
            itemBuilder: (context, rowIndex) {
              final enrollment = _enrollments[rowIndex];
              final studentId = enrollment.student.id;
              final rowBg = rowIndex % 2 == 0
                  ? (isDark ? Colors.grey[850] : Colors.white)
                  : (isDark ? const Color(0xFF1E1E1E) : Colors.grey[50]);

              return Container(
                height: 55.h,
                color: rowBg,
                child: Row(
                  children: [
                    Container(
                      width: 250.w,
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        children: [
                          CircleAvatar(
                              radius: 12.r,
                              backgroundColor: Colors.blueAccent,
                              child: Text(enrollment.student.fullName[0],
                                  style: TextStyle(
                                      fontSize: 10.sp, color: Colors.white))),
                          SizedBox(width: 10.w),
                          Expanded(
                              child: Text(enrollment.student.fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        itemCount: evaluationsToShow.length,
                        itemBuilder: (context, colIndex) {
                          final eval = evaluationsToShow[colIndex];
                          double? val;
                          bool isDirty = false;
                          String key = "${studentId}_${eval.id}";

                          if (_unsavedChanges.containsKey(key)) {
                            val = _unsavedChanges[key]!.value;
                            isDirty = true;
                          } else if (_serverGradesMatrix[studentId] != null &&
                              _serverGradesMatrix[studentId]!
                                  .containsKey(eval.id)) {
                            val =
                                _serverGradesMatrix[studentId]![eval.id]!.value;
                          }

                          return Container(
                            width: 140.w,
                            decoration: BoxDecoration(
                                border: Border(
                                    left: BorderSide(
                                        color: borderColor.withOpacity(0.3)))),
                            alignment: Alignment.center,
                            child: Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                SizedBox(
                                  width: 80.w,
                                  height: 35.h,
                                  child: TextFormField(
                                    initialValue:
                                        val != null ? val.toString() : "",
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: (val != null && val < 6.0)
                                            ? Colors.red
                                            : (isDark
                                                ? Colors.white
                                                : Colors.black)),
                                    decoration: InputDecoration(
                                      contentPadding:
                                          EdgeInsets.only(bottom: 10.h),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4.r),
                                          borderSide: BorderSide.none),
                                      filled: true,
                                      fillColor: isDirty
                                          ? Colors.amber.withOpacity(0.2)
                                          : (isDark
                                              ? Colors.black26
                                              : Colors.white),
                                      hintText: "-",
                                    ),
                                    onChanged: (newValue) {
                                      final parsed = double.tryParse(
                                          newValue.replaceAll(',', '.'));
                                      if (parsed == null && newValue.isNotEmpty)
                                        return;
                                      final finalVal = parsed ?? 0.0;
                                      setState(() {
                                        _unsavedChanges[key] = ClassGradeModel(
                                            studentId: studentId,
                                            enrollmentId: enrollment.id,
                                            evaluationId: eval.id!,
                                            value: finalVal);
                                      });
                                    },
                                  ),
                                ),
                                if (isDirty)
                                  Positioned(
                                      right: 4,
                                      top: 4,
                                      child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                              color: Colors.amber,
                                              shape: BoxShape.circle)))
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MODAL DE NOVA AVALIAÇÃO
// ============================================================================
class CreateAssessmentDialog extends StatefulWidget {
  final String classId;
  final String className;
  final SubjectModel? preSelectedSubject;
  final VoidCallback onSuccess;

  const CreateAssessmentDialog(
      {super.key,
      required this.classId,
      required this.className,
      this.preSelectedSubject,
      required this.onSuccess});

  @override
  State<CreateAssessmentDialog> createState() => _CreateAssessmentDialogState();
}

class _CreateAssessmentDialogState extends State<CreateAssessmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _maxScoreController = TextEditingController(text: "10");

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  String _selectedType = 'EXAM';
  SubjectModel? _selectedSubject;

  bool _isSaving = false;
  Map<DateTime, List<EventoModel>> _eventMap = {};
  List<EventoModel> _apiHolidays = [];

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedSubject != null) {
      _selectedSubject = widget.preSelectedSubject;
      _updateTitleAuto();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    try {
      if (widget.preSelectedSubject == null) {
        await Provider.of<SubjectProvider>(context, listen: false)
            .fetchSubjects(token);
      }
      final scheduleProvider =
          Provider.of<ScheduleProvider>(context, listen: false);
      await scheduleProvider.fetchEventosOnly(classId: widget.classId);
      await _fetchHolidaysApi();

      final allEvents = [...scheduleProvider.eventos, ..._apiHolidays];
      if (mounted)
        setState(() => _eventMap = groupBy(
            allEvents,
            (EventoModel e) =>
                DateTime(e.date.year, e.date.month, e.date.day)));
    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
    }
  }

  Future<void> _fetchHolidaysApi() async {
    try {
      final year = DateTime.now().year;
      final response = await http.get(
          Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/BR'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _apiHolidays = data
              .map((h) => EventoModel(
                  id: 'api_${h['date']}',
                  title: h['name'],
                  eventType: 'Feriado',
                  date: DateTime.parse(h['date']),
                  isSchoolWide: true,
                  description: "Feriado Nacional",
                  classInfo: null,
                  subject: null,
                  teacher: null,
                  startTime: null,
                  endTime: null))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Erro API Feriados: $e");
    }
  }

  List<EventoModel> _getEventsForDay(DateTime day) {
    return _eventMap[DateTime(day.year, day.month, day.day)] ?? [];
  }

  String _formatTime(TimeOfDay time) {
    final dt = DateTime(2022, 1, 1, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
        context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked != null) {
      setState(() {
        if (isStart)
          _startTime = picked;
        else
          _endTime = picked;
      });
    }
  }

  void _updateTitleAuto() {
    if (_selectedSubject != null && _titleController.text.isEmpty) {
      _titleController.text = "Avaliação de ${_selectedSubject!.name}";
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null) return;

    setState(() => _isSaving = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final newEval = EvaluationModel(
        classId: widget.classId,
        title: _titleController.text,
        type: _selectedType,
        date: _selectedDate,
        maxScore: double.parse(_maxScoreController.text.replaceAll(',', '.')),
        subjectId: _selectedSubject!.id,
        startTime: _selectedType == 'EXAM' ? _formatTime(_startTime) : null,
        endTime: _selectedType == 'EXAM' ? _formatTime(_endTime) : null,
      );

      await GradebookService().saveBulkGrades(
          token: token!,
          classId: widget.classId,
          evaluation: newEval,
          grades: []);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Agendado!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjects = Provider.of<SubjectProvider>(context).subjects;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        width: 1100.w,
        height: 750.h,
        padding: EdgeInsets.all(25.w),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Agendar Avaliação",
                  style: GoogleFonts.sairaCondensed(
                      fontWeight: FontWeight.bold, fontSize: 28.sp)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context))
            ]),
            const Divider(height: 30),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Disciplina",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)),
                            DropdownButtonFormField2<SubjectModel>(
                              value: _selectedSubject,
                              items: subjects
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s.name)))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _selectedSubject = v;
                                _updateTitleAuto();
                              }),
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8))),
                            ),
                            SizedBox(height: 20.h),
                            Text("Título",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)),
                            TextFormField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)))),
                            SizedBox(height: 20.h),
                            SizedBox(
                              width: double.infinity,
                              height: 50.h,
                              child: ElevatedButton(
                                  onPressed: _isSaving ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white),
                                  child: _isSaving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text("CONFIRMAR")),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 30.w),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        TableCalendar<EventoModel>(
                          locale: 'pt_BR',
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDate, day),
                          onDaySelected: (s, f) => setState(() {
                            _selectedDate = s;
                            _focusedDay = f;
                          }),
                          eventLoader: _getEventsForDay,
                          headerStyle: const HeaderStyle(
                              formatButtonVisible: false, titleCentered: true),
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView(
                              children: _getEventsForDay(_selectedDate)
                                  .map((e) => ListTile(
                                      title: Text(e.title),
                                      subtitle: Text(e.eventType)))
                                  .toList()),
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
