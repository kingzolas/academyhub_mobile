import 'package:academyhub_mobile/attendance/attendance_swipe_screen.dart';
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/horario_provider.dart';
import '../../services/attendance_service.dart';
import '../../providers/academic_calendar_provider.dart';
import '../../model/term_model.dart';
import '../../model/horario_model.dart';

typedef ClassSelectedCallback = void Function(String classId, String className);

class ClassSelectionScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ClassSelectedCallback onClassSelected;

  const ClassSelectionScreen({
    super.key,
    this.onBack,
    required this.onClassSelected,
  });

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AttendanceService _attendanceService = AttendanceService();

  String _searchQuery = '';

  Map<String, bool> _attendanceStatusMap = {};
  bool _isCheckingAttendance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataAndCheckAttendance();
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helpers de Data para o Bimestre
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  TermModel? _getCurrentTerm(List<TermModel> terms) {
    if (terms.isEmpty) return null;
    final now = DateTime.now();
    for (final term in terms) {
      final inRange =
          (now.isAfter(term.startDate) || _sameDay(now, term.startDate)) &&
              (now.isBefore(term.endDate) || _sameDay(now, term.endDate));
      if (inRange) return term;
    }
    return terms.first;
  }

  Future<void> _loadDataAndCheckAttendance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final horarioProvider =
        Provider.of<HorarioProvider>(context, listen: false);
    final academicProvider =
        Provider.of<AcademicCalendarProvider>(context, listen: false);

    final token = authProvider.token;
    final user = authProvider.user;

    if (token == null) {
      debugPrint("Erro: Token não encontrado ao tentar buscar turmas.");
      return;
    }

    Map<String, String> filter = {};
    if (user?.schoolId != null) {
      filter['schoolId'] = user!.schoolId;
    }

    Future<void> fetchClassesFuture =
        classProvider.fetchClasses(token, filter: filter);
    Future<void> fetchHorariosFuture = horarioProvider.horarios.isEmpty
        ? horarioProvider.fetchHorarios(token)
        : Future.value();

    Future<void> fetchAcademicFuture = Future(() async {
      if (academicProvider.schoolYears.isEmpty) {
        await academicProvider.fetchSchoolYears();
      }
      if (academicProvider.schoolYears.isNotEmpty) {
        final currentYear = DateTime.now().year;
        final resolvedYear = academicProvider.schoolYears.firstWhere(
          (y) => y.year == currentYear,
          orElse: () => academicProvider.schoolYears.first,
        );
        if (academicProvider.selectedSchoolYear?.id != resolvedYear.id) {
          academicProvider.selectSchoolYear(resolvedYear);
        }
        if (academicProvider.terms.isEmpty) {
          await academicProvider.fetchTermsForSelectedYear();
        }
      }
    });

    await Future.wait(
        [fetchClassesFuture, fetchHorariosFuture, fetchAcademicFuture]);

    if (mounted) {
      final currentTerm = _getCurrentTerm(academicProvider.terms);
      final horariosDoBimestre = currentTerm != null
          ? horarioProvider.horarios
              .where((h) => h.termId == currentTerm.id)
              .toList()
          : horarioProvider.horarios;

      final availableClasses = _getAvailableClasses(
          context, classProvider.classes, user, horariosDoBimestre);
      await _checkAttendanceForToday(
          availableClasses, horariosDoBimestre, user?.id ?? '');
    }
  }

  Future<void> _checkAttendanceForToday(List<ClassModel> classes,
      List<HorarioModel> horariosDoBimestre, String userId) async {
    setState(() => _isCheckingAttendance = true);

    final today = DateTime.now();
    final weekday = today.weekday;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    // [AJUSTADO] Lendo os roles corretamente da classe User
    bool isGestor = false;
    if (user != null) {
      final lowerRoles = user.roles.map((r) => r.toLowerCase()).toList();
      isGestor = lowerRoles.contains('admin') ||
          lowerRoles.contains('diretor') ||
          lowerRoles.contains('coordenador') ||
          lowerRoles.contains('administrador');
    }

    for (var turma in classes) {
      final temAulaHoje = horariosDoBimestre.any((h) =>
          h.classId == turma.id &&
          h.dayOfWeek == weekday &&
          (isGestor || h.teacherId == userId));

      if (temAulaHoje) {
        try {
          final sheet =
              await _attendanceService.getAttendanceSheet(turma.id!, today);
          _attendanceStatusMap[turma.id!] =
              sheet.id != null && sheet.id!.isNotEmpty;
        } catch (_) {
          _attendanceStatusMap[turma.id!] = false;
        }
      }
    }

    if (mounted) {
      setState(() => _isCheckingAttendance = false);
    }
  }

  List<ClassModel> _getAvailableClasses(
    BuildContext context,
    List<ClassModel> allClasses,
    dynamic user,
    List<HorarioModel> horariosDoBimestre,
  ) {
    if (user == null) return [];

    // [AJUSTADO] Verificação correta usando a lista de roles
    bool isGestor = false;
    try {
      final roles = (user.roles as List<dynamic>)
          .map((e) => e.toString().toLowerCase())
          .toList();
      isGestor = roles.contains('admin') ||
          roles.contains('diretor') ||
          roles.contains('coordenador') ||
          roles.contains('administrador');
    } catch (_) {}

    if (isGestor) {
      return allClasses;
    }

    try {
      // [AJUSTADO] Garantindo pegar o id do usuário real
      final userId = user.id?.toString() ?? '';
      if (userId.isNotEmpty) {
        final turmasDoProfessor = horariosDoBimestre
            .where((h) => h.teacherId == userId)
            .map((h) => h.classId)
            .toSet();

        return allClasses
            .where((c) => turmasDoProfessor.contains(c.id))
            .toList();
      }
    } catch (_) {}

    return allClasses;
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final horarioProvider = Provider.of<HorarioProvider>(context);
    final academicProvider = Provider.of<AcademicCalendarProvider>(context);

    final user = authProvider.user;
    final String userId = user?.id ?? '';

    // [AJUSTADO] Identifica corretamente o gestor para a tela
    bool isGestor = false;
    if (user != null) {
      final lowerRoles = user.roles.map((r) => r.toLowerCase()).toList();
      isGestor = lowerRoles.contains('admin') ||
          lowerRoles.contains('diretor') ||
          lowerRoles.contains('coordenador') ||
          lowerRoles.contains('administrador');
    }

    final currentTerm = _getCurrentTerm(academicProvider.terms);
    final horariosDoBimestre = currentTerm != null
        ? horarioProvider.horarios
            .where((h) => h.termId == currentTerm.id)
            .toList()
        : horarioProvider.horarios;

    List<ClassModel> availableClasses = _getAvailableClasses(
        context, classProvider.classes, user, horariosDoBimestre);

    if (_searchQuery.isNotEmpty) {
      availableClasses = availableClasses
          .where((c) => c.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    final currentWeekday = DateTime.now().weekday;

    // Ordenação Inteligente atualizada para olhar para O PROFESSOR específico
    availableClasses.sort((a, b) {
      final temAulaA = horariosDoBimestre.any((h) =>
          h.classId == a.id &&
          h.dayOfWeek == currentWeekday &&
          (isGestor || h.teacherId == userId));
      final temAulaB = horariosDoBimestre.any((h) =>
          h.classId == b.id &&
          h.dayOfWeek == currentWeekday &&
          (isGestor || h.teacherId == userId));

      if (temAulaA && !temAulaB) return -1;
      if (!temAulaA && temAulaB) return 1;

      if (temAulaA && temAulaB) {
        final realizadaA = _attendanceStatusMap[a.id] ?? false;
        final realizadaB = _attendanceStatusMap[b.id] ?? false;
        if (!realizadaA && realizadaB) return -1;
        if (realizadaA && !realizadaB) return 1;
      }

      return a.name.compareTo(b.name);
    });

    final isLoading = classProvider.isLoading ||
        horarioProvider.isLoading ||
        _isCheckingAttendance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111214) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          "Chamada de Frequência",
          style:
              GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18.sp),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caret_left,
              color: Theme.of(context).iconTheme.color),
          onPressed: () {
            if (widget.onBack != null) widget.onBack!();
          },
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: 16.h),
                  Text("Carregando grade do bimestre...",
                      style: GoogleFonts.inter(color: Colors.grey))
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1D2024) : Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2E34)
                              : const Color(0xFFE7EBF2)),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.magnifying_glass,
                            color: Colors.grey, size: 20.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Buscar turma...",
                              border: InputBorder.none,
                              hintStyle: GoogleFonts.inter(
                                  color: Colors.grey, fontSize: 14.sp),
                            ),
                            style: GoogleFonts.inter(fontSize: 14.sp),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          InkWell(
                            onTap: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                            child: Icon(PhosphorIcons.x_circle_fill,
                                color: Colors.grey, size: 20.sp),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: availableClasses.isEmpty
                      ? Center(
                          child: Text(
                            "Nenhuma turma encontrada no bimestre.",
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                              left: 16.w,
                              right: 16.w,
                              top: 16.h,
                              bottom: 120.h),
                          itemCount: availableClasses.length,
                          itemBuilder: (context, index) {
                            return _buildClassCard(
                                context,
                                availableClasses[index],
                                horariosDoBimestre,
                                currentWeekday,
                                isDark,
                                isGestor,
                                userId);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildClassCard(
      BuildContext context,
      ClassModel turma,
      List<HorarioModel> horariosDoBimestre,
      int currentWeekday,
      bool isDark,
      bool isGestor,
      String userId) {
    final aulasHoje = horariosDoBimestre
        .where((h) =>
            h.classId == turma.id &&
            h.dayOfWeek == currentWeekday &&
            (isGestor || h.teacherId == userId))
        .toList();

    aulasHoje.sort((a, b) => a.startTime.compareTo(b.startTime));

    final temAulaHoje = aulasHoje.isNotEmpty;

    String infoAula = "Sem aulas suas hoje";
    if (temAulaHoje) {
      final materias = aulasHoje.map((h) => h.subject.name).toSet().join(", ");
      final horarioInicio = aulasHoje.first.startTime;
      infoAula = isGestor
          ? "Hoje: $materias"
          : "Sua aula: $materias às $horarioInicio";
    }

    bool chamadaRealizada = _attendanceStatusMap[turma.id] ?? false;

    Color statusColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;

    if (!temAulaHoje) {
      statusText = "Sem aula hoje";
      statusColor = Colors.grey;
      statusBgColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
      statusIcon = PhosphorIcons.calendar_blank;
    } else if (chamadaRealizada) {
      statusText = "Realizada";
      statusColor = const Color(0xFF2DBE60);
      statusBgColor = const Color(0xFF2DBE60).withOpacity(0.15);
      statusIcon = PhosphorIcons.check_circle_fill;
    } else {
      statusText = "Pendente";
      statusColor = const Color(0xFFF2994A);
      statusBgColor = const Color(0xFFF2994A).withOpacity(0.15);
      statusIcon = PhosphorIcons.warning_circle_fill;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 0,
      color: isDark ? const Color(0xFF17191C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
            color: isDark ? const Color(0xFF2A2E34) : const Color(0xFFE7EBF2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () async {
          if (chamadaRealizada && temAulaHoje) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor:
                    isDark ? const Color(0xFF1D2024) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r)),
                title: Row(
                  children: [
                    Icon(PhosphorIcons.warning_circle_fill,
                        color: const Color(0xFFF2994A), size: 24.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        "Chamada já realizada",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  "Você já salvou a frequência desta turma hoje.\n\nDeseja abrir a lista novamente para fazer alterações?",
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text("Cancelar",
                        style: GoogleFonts.inter(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DBE60),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text("Sim, continuar",
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );

            if (confirm != true) return;
          }

          widget.onClassSelected(turma.id!, turma.name);
        },
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F80ED).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.users_three_fill,
                  color: const Color(0xFF2F80ED),
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      turma.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(PhosphorIcons.student,
                            size: 14.sp, color: Colors.grey),
                        SizedBox(width: 4.w),
                        Text(
                          "${turma.studentCount ?? 0} Alunos",
                          style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      infoAula,
                      style: GoogleFonts.inter(
                        color: temAulaHoje
                            ? (isDark ? Colors.white70 : Colors.black54)
                            : Colors.grey,
                        fontSize: 12.sp,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14.sp),
                        SizedBox(width: 4.w),
                        Text(
                          statusText,
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Icon(PhosphorIcons.caret_right,
                      color: Colors.grey, size: 18.sp),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
