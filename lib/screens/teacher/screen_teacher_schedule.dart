// lib/screens/teacher/screen_teacher_schedule.dart

import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/evento_model.dart';
import 'package:academyhub_mobile/model/horario_model.dart';
import 'package:academyhub_mobile/model/term_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/services/evento_service.dart';
import 'package:academyhub_mobile/services/horario_service.dart';
import 'package:academyhub_mobile/services/term_service.dart'; // Importante para buscar o ano letivo
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScreenTeacherSchedule extends StatefulWidget {
  const ScreenTeacherSchedule({super.key});

  @override
  State<ScreenTeacherSchedule> createState() => _ScreenTeacherScheduleState();
}

class _ScreenTeacherScheduleState extends State<ScreenTeacherSchedule> {
  final HorarioService _horarioService = HorarioService();
  final EventoService _eventoService = EventoService();
  final TermService _termService = TermService();

  bool _isLoading = true;
  List<ClassModel> _allClasses = [];
  ClassModel? _selectedClass;

  // Controle de Período (Correção do Conflito de Anos)
  TermModel? _currentTerm;

  // Dados da Grade
  Map<int, List<HorarioModel>> _dailySchedule = {};
  Map<int, List<EventoModel>> _dailyEvents = {};

  // Controle de Datas
  DateTime _startOfWeek = DateTime.now();

  @override
  void initState() {
    super.initState();
    _calculateStartOfWeek();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  void _calculateStartOfWeek() {
    final now = DateTime.now();
    // Ajusta para a segunda-feira da semana atual (1=Seg ... 7=Dom)
    _startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    // Zera horas
    _startOfWeek =
        DateTime(_startOfWeek.year, _startOfWeek.month, _startOfWeek.day);
  }

  Future<void> _loadInitialData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);

    if (auth.token == null || auth.user == null) return;

    try {
      // 1. Identificar o Período Letivo Atual (CRÍTICO PARA CORRIGIR O BUG)
      final terms = await _termService.find(auth.token!, {});
      final now = DateTime.now();

      // Busca o termo que engloba a data de hoje e é do tipo 'Letivo'
      _currentTerm = terms.firstWhereOrNull((t) =>
          t.tipo == 'Letivo' &&
          (now.isAfter(t.startDate) || isSameDay(now, t.startDate)) &&
          (now.isBefore(t.endDate) || isSameDay(now, t.endDate)));

      // Se não achar (ex: férias), pega o último cadastrado para não quebrar a tela
      if (_currentTerm == null && terms.isNotEmpty) {
        // Ordena pelo mais recente
        terms.sort((a, b) => b.startDate.compareTo(a.startDate));
        _currentTerm = terms.first;
      }

      // 2. Busca todas as turmas (para o dropdown)
      await classProvider.fetchClasses(auth.token!);
      _allClasses =
          classProvider.classes.where((c) => c.status != 'Cancelada').toList();
      _allClasses.sort((a, b) => a.name.compareTo(b.name));

      // 3. Busca eventos
      await _fetchEventsAndHolidays();

      // 4. Busca a grade (Agora filtrada pelo Termo correto)
      await _fetchScheduleData();
    } catch (e) {
      debugPrint("Erro ao carregar dados da grade: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEventsAndHolidays() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final schoolEvents = await _eventoService
          .getEventos(auth.token!, filter: {'isSchoolWide': 'true'});

      final year = DateTime.now().year;
      final response = await http.get(
          Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/BR'));
      List<EventoModel> holidays = [];

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        holidays = data
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
                  endTime: null,
                ))
            .toList();
      }

      final allEvents = [...schoolEvents, ...holidays];
      final endOfWeek = _startOfWeek.add(const Duration(days: 7));

      final eventsThisWeek = allEvents.where((e) {
        final eDate = DateTime(e.date.year, e.date.month, e.date.day);
        return eDate
                .isAfter(_startOfWeek.subtract(const Duration(seconds: 1))) &&
            eDate.isBefore(endOfWeek);
      }).toList();

      _dailyEvents = groupBy(eventsThisWeek, (EventoModel e) => e.date.weekday);
    } catch (e) {
      debugPrint("Erro ao buscar eventos: $e");
    }
  }

  Future<void> _fetchScheduleData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Se não tiver termo definido, não tem como buscar grade correta
    if (_currentTerm == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      Map<String, String> filters = {
        // [CORREÇÃO] Filtra pelo ID do Termo Atual para evitar aulas do ano passado
        'termId': _currentTerm!.id
      };

      if (_selectedClass == null) {
        // Minha Agenda
        filters['teacherId'] = auth.user!.id;
      } else {
        // Visão da Turma
        filters['classId'] = _selectedClass!.id;
      }

      final schedules =
          await _horarioService.getHorarios(auth.token!, filter: filters);
      _updateLocalScheduleData(schedules);
    } catch (e) {
      debugPrint("Erro ao buscar grade: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateLocalScheduleData(List<HorarioModel> schedules) {
    _dailySchedule = groupBy(schedules, (HorarioModel h) => h.dayOfWeek);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- HELPERS DE TEMPO ---
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.blueGrey[900];
    final bgPrimary = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgPrimary,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 30.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Minha Grade Horária",
                        style: GoogleFonts.sairaCondensed(
                            fontWeight: FontWeight.bold,
                            fontSize: 32.sp,
                            color: textPrimary)),

                    // Mostra o período ativo para confirmação visual
                    Row(
                      children: [
                        Text(
                            "Semana de ${DateFormat('dd/MM').format(_startOfWeek)} a ${DateFormat('dd/MM').format(_startOfWeek.add(const Duration(days: 6)))}",
                            style: GoogleFonts.inter(
                                fontSize: 14.sp, color: Colors.grey)),
                        if (_currentTerm != null) ...[
                          SizedBox(width: 8.w),
                          Container(
                              width: 4.w,
                              height: 4.w,
                              decoration: const BoxDecoration(
                                  color: Colors.grey, shape: BoxShape.circle)),
                          SizedBox(width: 8.w),
                          Text(_currentTerm!.titulo,
                              style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent)),
                        ]
                      ],
                    ),
                  ],
                ),

                // --- FILTRO DE TURMA ---
                Row(
                  children: [
                    Text("Visualizar:",
                        style: GoogleFonts.inter(
                            color: Colors.grey, fontSize: 14.sp)),
                    SizedBox(width: 10.w),
                    Container(
                      height: 45.h,
                      padding: EdgeInsets.symmetric(horizontal: 15.w),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<ClassModel>(
                          isExpanded: false,
                          value: _selectedClass,
                          hint: Text("Minha Agenda (Todas)",
                              style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold)),
                          onChanged: (value) {
                            setState(() {
                              _selectedClass = value;
                            });
                            _fetchScheduleData();
                          },
                          items: [
                            DropdownMenuItem<ClassModel>(
                                value: null,
                                child: Text("Minha Agenda (Todas)",
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent))),
                            ..._allClasses.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name,
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary)),
                                ))
                          ],
                          buttonStyleData: ButtonStyleData(width: 250.w),
                          dropdownStyleData: DropdownStyleData(
                              maxHeight: 400.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.r),
                                color: isDark
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.white,
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 30.h),

            // --- GRADE DE SEGUNDA A DOMINGO ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _currentTerm == null
                      ? Center(
                          child: Text(
                              "Nenhum período letivo ativo encontrado para hoje.",
                              style: GoogleFonts.inter(
                                  fontSize: 16.sp, color: Colors.grey)))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildFullWeekGrid(
                                isDark, constraints.maxWidth);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWeekGrid(bool isDark, double availableWidth) {
    // 1=Seg ... 7=Dom
    final weekDaysIndices = [1, 2, 3, 4, 5, 6, 7];
    final weekDaysNames = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo'
    ];

    final columnWidth = (availableWidth - (10.w * 6)) / 7;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(weekDaysIndices.length, (index) {
        final dayIndex = weekDaysIndices[index];
        final dayName = weekDaysNames[index];

        final date = _startOfWeek.add(Duration(days: index));
        final isToday = isSameDay(date, DateTime.now());

        final horarios = _dailySchedule[dayIndex] ?? [];
        final events = _dailyEvents[dayIndex] ?? [];

        horarios.sort((a, b) =>
            _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime)));

        return Container(
          width: columnWidth,
          margin: EdgeInsets.only(right: index == 6 ? 0 : 10.w),
          child: Column(
            children: [
              // HEADER DO DIA
              Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: isToday
                      ? Colors.blueAccent
                      : (isDark
                          ? Colors.grey[800]
                          : Colors.blue.withOpacity(0.1)),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(8.r)),
                  border: Border.all(
                      color: isDark
                          ? Colors.grey[700]!
                          : Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(dayName,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: isToday
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.blue[800]))),
                    Text(DateFormat('dd/MM').format(date),
                        style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: isToday
                                ? Colors.white.withOpacity(0.8)
                                : Colors.grey)),
                  ],
                ),
              ),

              // CONTEÚDO
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: isDark ? Colors.black12 : Colors.grey[50],
                      border: Border(
                        left: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        right: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      )),
                  child: Column(
                    children: [
                      if (events.isNotEmpty)
                        ...events.map((e) => _buildEventCard(e, isDark)),
                      Expanded(
                        child: horarios.isEmpty && events.isEmpty
                            ? Center(
                                child: Text("-",
                                    style: TextStyle(
                                        color: Colors.grey.withOpacity(0.5))))
                            : ListView.builder(
                                padding: EdgeInsets.all(6.w),
                                itemCount: horarios.length,
                                itemBuilder: (context, i) {
                                  final aula = horarios[i];
                                  return _buildAulaCard(aula, isDark);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEventCard(EventoModel event, bool isDark) {
    Color bg = event.eventType == 'Feriado'
        ? Colors.red.withOpacity(0.1)
        : Colors.purple.withOpacity(0.1);
    Color text = event.eventType == 'Feriado' ? Colors.red : Colors.purple;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(4.w),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: text.withOpacity(0.3))),
      child: Column(
        children: [
          Icon(
              event.eventType == 'Feriado'
                  ? PhosphorIcons.calendar_x_fill
                  : PhosphorIcons.star_fill,
              size: 14.sp,
              color: text),
          SizedBox(height: 4.h),
          Text(event.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11.sp, fontWeight: FontWeight.bold, color: text)),
        ],
      ),
    );
  }

  Widget _buildAulaCard(HorarioModel aula, bool isDark) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isMyClass = aula.teacherId == auth.user?.id;

    final bgColor = isMyClass
        ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50])
        : (isDark ? Colors.grey[800] : Colors.white);

    final borderColor =
        isMyClass ? Colors.blue.withOpacity(0.5) : Colors.grey.withOpacity(0.3);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: borderColor, width: isMyClass ? 1.5 : 1),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${aula.startTime} - ${aula.endTime}",
                  style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey[700])),
              if (isMyClass)
                Icon(PhosphorIcons.user_circle_fill,
                    size: 12.sp, color: Colors.blue)
            ],
          ),
          SizedBox(height: 4.h),
          Text(aula.subject.name,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                  color: isDark ? Colors.white : Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Text(aula.classInfo.name,
                style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w600)),
          ),
          if (!isMyClass)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(aula.teacher.fullName,
                  style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic)),
            ),
          if (aula.room != null && aula.room!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Row(
                children: [
                  Icon(PhosphorIcons.door, size: 12.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(aula.room!,
                      style: GoogleFonts.inter(
                          fontSize: 10.sp, color: Colors.grey)),
                ],
              ),
            )
        ],
      ),
    );
  }
}
