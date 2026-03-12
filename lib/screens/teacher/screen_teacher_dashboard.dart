// lib/screens/dashboard/teacher_dashboard_view.dart

import 'package:academyhub_mobile/model/horario_model.dart';
import 'package:academyhub_mobile/model/term_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/horario_service.dart';
import 'package:academyhub_mobile/services/term_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

class TeacherDashboardView extends StatefulWidget {
  const TeacherDashboardView({super.key});

  @override
  State<TeacherDashboardView> createState() => _TeacherDashboardViewState();
}

class _TeacherDashboardViewState extends State<TeacherDashboardView> {
  final HorarioService _horarioService = HorarioService();
  final TermService _termService = TermService();

  bool _isLoading = true;
  String _loadingMessage = "Carregando agenda...";

  // Dados
  TermModel? _currentTerm;
  List<HorarioModel> _allTeacherClasses = [];
  List<HorarioModel> _displayClasses = [];
  String _timelineTitle = "Sua Agenda Hoje";

  // Estado do Card Destaque
  HorarioModel? _currentClass;
  HorarioModel? _nextClass;
  bool _isClassLive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboardData();
    });
  }

  Future<void> _fetchDashboardData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final user = auth.user;

    if (token == null || user == null) return;

    try {
      final terms = await _termService.find(token, {});
      final now = DateTime.now();

      final term = terms.firstWhereOrNull((t) =>
          t.tipo == 'Letivo' &&
          (now.isAfter(t.startDate) || isSameDay(now, t.startDate)) &&
          (now.isBefore(t.endDate) || isSameDay(now, t.endDate)));

      if (term == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingMessage = "Nenhum período letivo ativo.";
          });
        }
        return;
      }
      _currentTerm = term;

      final horarios = await _horarioService.getHorarios(token,
          filter: {'teacherId': user.id, 'termId': term.id});

      _allTeacherClasses = horarios;
      _processScheduleLogic();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Erro dashboard professor: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = "Erro ao carregar dados.";
        });
      }
    }
  }

  void _processScheduleLogic() {
    final now = DateTime.now();
    final todayWeekday = now.weekday;

    List<HorarioModel> todays =
        _allTeacherClasses.where((h) => h.dayOfWeek == todayWeekday).toList();

    todays.sort((a, b) =>
        _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime)));

    if (todays.isNotEmpty) {
      _displayClasses = todays;
      _timelineTitle = "Sua Agenda Hoje";
      _determineCurrentStatus(todays);
    } else {
      _findNextDayWithClasses(todayWeekday);
    }
  }

  void _findNextDayWithClasses(int startDay) {
    for (int i = 1; i <= 7; i++) {
      int nextDay = (startDay + i) > 7 ? (startDay + i) - 7 : (startDay + i);
      List<HorarioModel> nextClasses =
          _allTeacherClasses.where((h) => h.dayOfWeek == nextDay).toList();

      if (nextClasses.isNotEmpty) {
        nextClasses.sort((a, b) =>
            _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime)));
        _displayClasses = nextClasses;
        _timelineTitle = "Próximas Aulas (${_getWeekdayName(nextDay)})";
        _currentClass = null;
        _nextClass = nextClasses.first;
        _isClassLive = false;
        return;
      }
    }
    _displayClasses = [];
    _timelineTitle = "Sem aulas agendadas";
  }

  void _determineCurrentStatus(List<HorarioModel> todaysClasses) {
    final nowTime = TimeOfDay.now();
    final nowMinutes = nowTime.hour * 60 + nowTime.minute;

    HorarioModel? live;
    HorarioModel? next;

    for (var aula in todaysClasses) {
      final startMin = _timeToMinutes(aula.startTime);
      final endMin = _timeToMinutes(aula.endTime);

      if (nowMinutes >= startMin && nowMinutes < endMin) {
        live = aula;
      } else if (nowMinutes < startMin) {
        next ??= aula;
      }
    }

    _currentClass = live;
    _nextClass = next;
    _isClassLive = (live != null);
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getWeekdayName(int day) {
    const days = {
      1: 'Segunda',
      2: 'Terça',
      3: 'Quarta',
      4: 'Quinta',
      5: 'Sexta',
      6: 'Sábado',
      7: 'Domingo'
    };
    return days[day] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary = isDark ? Colors.white : Colors.blueGrey[900]!;
    final textSecondary = isDark ? Colors.grey[400]! : Colors.blueGrey[400]!;
    // Adicionei um padding inferior extra para não ficar escondido atrás do BottomMenu/FAB
    final paddingBottom = 100.h;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: 10.h),
                  Text(_loadingMessage, style: TextStyle(color: textSecondary))
                ],
              ),
            )
          : ListView(
              // Alterado de SingleChildScrollView para ListView para melhor controle
              padding: EdgeInsets.only(
                  left: 20.w, right: 20.w, top: 40.h, bottom: paddingBottom),
              children: [
                // --- 1. HEADER (Adaptado para Mobile) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Olá, Professor!",
                              style: GoogleFonts.sairaCondensed(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28.sp, // Reduzido de 32 para 28
                                  color: textPrimary)),
                          Text(
                              _currentTerm != null
                                  ? "Período: ${_currentTerm!.titulo}"
                                  : "Academy Hub",
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 13.sp, color: textSecondary)),
                        ],
                      ),
                    ),
                    // Data compacta
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      child: Icon(PhosphorIcons.calendar_blank,
                          size: 20.sp, color: textSecondary),
                    )
                  ],
                ),

                SizedBox(height: 25.h),

                // --- 2. HERO CARD (Agora ocupa 100% da largura) ---
                _buildMainStatusCard(theme, isDark),

                SizedBox(height: 25.h),

                // --- 3. TIMELINE (Mantive horizontal, perfeito para mobile) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_timelineTitle,
                        style: GoogleFonts.inter(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    // Indicador de rolagem se necessário
                    if (_displayClasses.isNotEmpty)
                      Icon(PhosphorIcons.caret_right,
                          size: 16.sp, color: textSecondary)
                  ],
                ),
                SizedBox(height: 15.h),

                _displayClasses.isEmpty
                    ? Container(
                        height: 80.h,
                        alignment: Alignment.centerLeft,
                        child: Text(
                            "Nenhuma aula encontrada para os próximos dias.",
                            style: TextStyle(color: textSecondary)),
                      )
                    : SizedBox(
                        height: 130.h, // Ajuste fino de altura
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _displayClasses.length,
                          separatorBuilder: (_, __) => SizedBox(width: 12.w),
                          itemBuilder: (context, index) {
                            return _buildTimelineCard(
                                _displayClasses[index], theme, isDark);
                          },
                        ),
                      ),

                SizedBox(height: 25.h),

                // --- 4. PENDÊNCIAS (Agora em linha vertical) ---
                // No mobile, o professor vê isso rolando para baixo
                _buildPendingTasksCard(theme, isDark),

                SizedBox(height: 25.h),

                // --- 5. ACESSO RÁPIDO (Grid de 2 Colunas) ---
                Text("Acesso Rápido",
                    style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: textPrimary)),
                SizedBox(height: 15.h),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, // MUDANÇA CRÍTICA: 4 -> 2 colunas
                  crossAxisSpacing: 15.w,
                  mainAxisSpacing: 15.h,
                  childAspectRatio: 1.4, // Cartões mais quadrados/retangulares
                  children: [
                    _buildQuickAccessCard("Minhas\nTurmas",
                        PhosphorIcons.chalkboard_teacher, Colors.blue, theme),
                    _buildQuickAccessCard("Diário de\nNotas",
                        PhosphorIcons.notebook, Colors.orange, theme),
                    _buildQuickAccessCard("Meus\nAlunos", PhosphorIcons.student,
                        Colors.green, theme),
                    _buildQuickAccessCard("Calendário\nEscolar",
                        PhosphorIcons.calendar, Colors.purple, theme),
                  ],
                ),
              ],
            ),
    );
  }

  // --- WIDGETS ---

  Widget _buildMainStatusCard(ThemeData theme, bool isDark) {
    if (_isClassLive && _currentClass != null) {
      return _buildHeroCard(
        classInfo: _currentClass!,
        statusLabel: "EM ANDAMENTO",
        statusColor: Colors.greenAccent,
        gradientColors: isDark
            ? [const Color(0xFF0052D4), const Color(0xFF4364F7)]
            : [
                const Color(0xFF2563EB),
                const Color(0xFF60A5FA)
              ], // Azul Royal Eyecode
        buttonText: "Frequência", // Texto curto
        icon: PhosphorIcons.broadcast,
      );
    }

    if (_nextClass != null) {
      return _buildHeroCard(
        classInfo: _nextClass!,
        statusLabel: "PRÓXIMA AULA",
        statusColor: Colors.amberAccent,
        gradientColors: isDark
            ? [const Color(0xFF3E5151), const Color(0xFFDECBA4)]
            : [const Color(0xFFF59E0B), const Color(0xFFFCD34D)],
        buttonText: "Detalhes",
        icon: PhosphorIcons.clock_counter_clockwise_bold,
        isNext: true,
      );
    }

    // Estado de descanso compactado
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 25.h, horizontal: 20.w),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: theme.cardColor,
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Row(
        // Row para economizar altura
        children: [
          Container(
              padding: EdgeInsets.all(12.sp),
              decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor, shape: BoxShape.circle),
              child: Icon(PhosphorIcons.coffee_fill,
                  size: 24.sp, color: Colors.grey)),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tudo pronto por hoje!",
                    style: GoogleFonts.sairaCondensed(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                Text("Sem aulas pendentes.",
                    style:
                        GoogleFonts.inter(color: Colors.grey, fontSize: 12.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required HorarioModel classInfo,
    required String statusLabel,
    required Color statusColor,
    required List<Color> gradientColors,
    required String buttonText,
    required IconData icon,
    bool isNext = false,
  }) {
    // Card Principal deve ser IMPONENTE no mobile
    return Container(
      width: double.infinity, // Ocupa largura total
      padding: EdgeInsets.all(20.sp),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topo do Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.clock_fill,
                        color: Colors.white, size: 12.sp),
                    SizedBox(width: 5.w),
                    Text("${classInfo.startTime} - ${classInfo.endTime}",
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp)),
                  ],
                ),
              ),
              Icon(icon, color: Colors.white.withOpacity(0.8), size: 24.sp),
            ],
          ),

          SizedBox(height: 15.h),

          // Infos Principais
          Text(classInfo.subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sairaCondensed(
                  color: Colors.white,
                  fontSize: 26.sp, // Ajustado
                  fontWeight: FontWeight.bold,
                  height: 1.1)),

          Text(classInfo.classInfo.name,
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.9), fontSize: 14.sp)),

          SizedBox(height: 8.h),

          Row(
            children: [
              Icon(PhosphorIcons.map_pin, color: Colors.white70, size: 14.sp),
              SizedBox(width: 5.w),
              Text(classInfo.room ?? "Sala não definida",
                  style:
                      GoogleFonts.inter(color: Colors.white, fontSize: 13.sp)),
            ],
          ),

          SizedBox(height: 20.h),

          // Botão Full Width (Ergonomia)
          SizedBox(
            width: double.infinity,
            height: 48.h, // Altura confortável para o dedo
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: gradientColors.first,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text(buttonText.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 13.sp)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPendingTasksCard(ThemeData theme, bool isDark) {
    // Reduzi a complexidade visual para não brigar com o Hero Card
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.bell_ringing_fill,
                  color: Colors.orange, size: 18.sp),
              SizedBox(width: 8.w),
              Text("Atenção Necessária",
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          SizedBox(height: 12.h),
          // Lista estática simulada - em produção usaria ListView.builder com shrinkWrap
          _buildTaskItem("Frequência pendente: 1º Ano A", true, theme),
          SizedBox(height: 8.h),
          _buildTaskItem("Lançar notas: Prova de Geo.", false, theme),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String text, bool isUrgent, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800]!.withOpacity(0.3) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border(
            left: BorderSide(
                color: isUrgent ? Colors.red : Colors.blue, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(text,
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: isDark ? Colors.grey[300] : Colors.grey[800]))),
          if (isUrgent)
            Icon(PhosphorIcons.warning_circle_fill,
                color: Colors.red, size: 16.sp)
        ],
      ),
    );
  }

  Widget _buildTimelineCard(HorarioModel aula, ThemeData theme, bool isDark) {
    // Lógica visual mantida, apenas ajuste de padding e tamanho
    final nowMin = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
    final startMin = _timeToMinutes(aula.startTime);
    final endMin = _timeToMinutes(aula.endTime);

    bool isLive = false;
    bool isDone = false;
    if (_timelineTitle.contains("Hoje")) {
      if (nowMin >= startMin && nowMin < endMin) isLive = true;
      if (nowMin >= endMin) isDone = true;
    }

    Color accentColor =
        isLive ? Colors.blue : (isDone ? Colors.grey : Colors.orange);

    return Container(
      width: 140.w, // Largura fixa menor para mobile
      padding: EdgeInsets.all(12.sp),
      decoration: BoxDecoration(
        color: isLive ? Colors.blue.withOpacity(0.1) : theme.cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
            color: isLive ? Colors.blue : theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(aula.startTime,
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: accentColor)),
              if (isDone)
                Icon(PhosphorIcons.check, size: 14.sp, color: Colors.green)
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(aula.subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
              Text(aula.classInfo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(
      String title, IconData icon, Color color, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    // Design Vertical para o Grid
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(15.r),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10.sp),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(height: 10.h),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: isDark ? Colors.white : Colors.blueGrey[800])),
          ],
        ),
      ),
    );
  }
}
