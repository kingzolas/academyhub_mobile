import 'dart:async';
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/providers/attendance_provider.dart';
import 'package:academyhub_mobile/services/websocket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// --- PALETA DE CORES CORRIGIDA (Padrão Neutro Academy Hub) ---
const kBackgroundDark = Color(0xFF121212); // Fundo Preto Padrão
const kSurfaceDark = Color(0xFF1E1E1E); // Cinza Neutro (Sem tom roxo/azul)
const kBackgroundLight = Color(0xFFF4F6F8);
const kSurfaceLight = Colors.white;

// Cores de Status e Ação
const kSuccessColor = Color(0xFF00C853); // Verde Vibrante (Botões/Presença)
const kErrorColor = Color(0xFFFF5252); // Vermelho (Falta)
const kAccentOrange = Color(0xFFFF9100); // Laranja (Detalhes)
const kTextGrey = Color(0xFF9E9E9E); // Cinza médio para textos secundários
const kTextWhite = Color(0xFFEEEEEE); // Branco suave para textos principais

const kBorderRadius = 16.0;

class ClassAttendanceScreen extends StatefulWidget {
  final VoidCallback onBack;
  final ClassModel classData;

  const ClassAttendanceScreen({
    super.key,
    required this.classData,
    required this.onBack,
  });

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _viewMonth = DateTime.now();
  bool _isLoading = false;

  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
      _setupWebSocketListener();
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  // --- LÓGICA DE REAL-TIME ---
  void _setupWebSocketListener() {
    _socketSub = _wsService.stream.listen((message) {
      if (message['type']?.toString().toUpperCase() == 'ATTENDANCE_UPDATED') {
        final payload = message['payload'];
        if (payload != null && payload['classId'] == widget.classData.id) {
          _refreshAllData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(
                children: [
                  const Icon(PhosphorIcons.arrows_clockwise,
                      color: Colors.white),
                  SizedBox(width: 8.w),
                  const Text("Sincronizado em tempo real"),
                ],
              ),
              backgroundColor: kSuccessColor,
              behavior: SnackBarBehavior.floating,
              width: 300.w,
            ));
          }
        }
      }
    });
  }

  Future<void> _refreshAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final provider = Provider.of<AttendanceProvider>(context, listen: false);

    await Future.wait([
      provider.loadHistory(widget.classData.id),
      provider.loadDailyAttendance(widget.classData.id, _selectedDate),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      if (date.month != _viewMonth.month || date.year != _viewMonth.year) {
        _viewMonth = date;
      }
    });
    _refreshAllData();
  }

  void _changeViewMonth(int increment) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + increment);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kBackgroundDark : kBackgroundLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // 1. SIDEBAR (Histórico)
          _SidebarHistory(
            classData: widget.classData,
            selectedDate: _selectedDate,
            viewMonth: _viewMonth,
            onDateSelected: _onDateSelected,
            onMonthChanged: _changeViewMonth,
            onBack: widget.onBack,
          ),

          // 2. CONTEÚDO PRINCIPAL
          Expanded(
            child: Column(
              children: [
                // Header Dashboard
                _AttendanceHeader(
                  classData: widget.classData,
                  selectedDate: _selectedDate,
                  onRefresh: _refreshAllData,
                ),

                // Grid de Alunos
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: kSuccessColor))
                      : _StudentGrid(selectedDate: _selectedDate),
                ),
              ],
            ),
          ),
        ],
      ),
      // FAB Principal (Botão Salvar)
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kSuccessColor,
        elevation: 4,
        icon: const Icon(PhosphorIcons.floppy_disk,
            weight: 20, color: Colors.white),
        label: Text("Salvar Diário",
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () async {
          final provider =
              Provider.of<AttendanceProvider>(context, listen: false);
          bool success = await provider.submitAttendance();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  success ? "Diário salvo com sucesso!" : "Erro ao salvar."),
              backgroundColor: success ? kSuccessColor : kErrorColor,
              behavior: SnackBarBehavior.floating,
            ));
            if (success) _refreshAllData();
          }
        },
      ),
    );
  }
}

// =============================================================================
// WIDGETS AUXILIARES (Design Atualizado)
// =============================================================================

// 1. SIDEBAR DE HISTÓRICO
class _SidebarHistory extends StatelessWidget {
  final ClassModel classData;
  final DateTime selectedDate;
  final DateTime viewMonth;
  final Function(DateTime) onDateSelected;
  final Function(int) onMonthChanged;
  final VoidCallback onBack;

  const _SidebarHistory({
    required this.classData,
    required this.selectedDate,
    required this.viewMonth,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? kSurfaceDark : kSurfaceLight;
    final textColor = isDark ? kTextWhite : Colors.black87;

    final monthHistory = provider.history.where((item) {
      final d = DateTime.parse(item['date']);
      return d.month == viewMonth.month && d.year == viewMonth.year;
    }).toList();

    monthHistory.sort((a, b) =>
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    return Container(
      width: 320.w,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
            right: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(PhosphorIcons.arrow_left, color: textColor),
                    onPressed: onBack,
                  ),
                  SizedBox(width: 8.w),
                  Text("Histórico",
                      style: GoogleFonts.inter(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                ],
              ),
            ),
          ),

          // Navegação de Mês
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: isDark
                  ? kBackgroundDark
                  : Colors.grey[100], // Contraste sutil
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(PhosphorIcons.caret_left,
                      size: 18, color: textColor),
                  onPressed: () => onMonthChanged(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'pt_BR')
                      .format(viewMonth)
                      .toUpperCase(),
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                      color: textColor),
                ),
                IconButton(
                  icon: Icon(PhosphorIcons.caret_right,
                      size: 18, color: textColor),
                  onPressed: () => onMonthChanged(1),
                ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: monthHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.calendar_x,
                            size: 40, color: kTextGrey.withOpacity(0.5)),
                        SizedBox(height: 10.h),
                        Text("Sem registros neste mês",
                            style: GoogleFonts.inter(color: kTextGrey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: monthHistory.length,
                    itemBuilder: (context, index) {
                      final item = monthHistory[index];
                      final date = DateTime.parse(item['date']);
                      final isSelected =
                          DateUtils.isSameDay(date, selectedDate);

                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kSuccessColor.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: kSuccessColor.withOpacity(0.3))
                              : null,
                        ),
                        child: ListTile(
                          onTap: () => onDateSelected(date),
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? kSuccessColor
                                  : (isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey[200]),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(PhosphorIcons.calendar_check,
                                size: 16,
                                color: isSelected ? Colors.white : kTextGrey),
                          ),
                          title: Text(
                            DateFormat('dd/MM - EEEE', 'pt_BR').format(date),
                            style: GoogleFonts.inter(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14.sp,
                                color: textColor),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Padding(
            padding: EdgeInsets.all(20.w),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(PhosphorIcons.plus),
                label: const Text("Nova Chamada Hoje"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kSuccessColor,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  side: const BorderSide(color: kSuccessColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => onDateSelected(DateTime.now()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 2. HEADER DA CHAMADA
class _AttendanceHeader extends StatelessWidget {
  final ClassModel classData;
  final DateTime selectedDate;
  final VoidCallback onRefresh;

  const _AttendanceHeader({
    required this.classData,
    required this.selectedDate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final total = provider.currentSheet?.records.length ?? 0;
    final present = provider.currentSheet?.records
            .where((r) => r.status == 'PRESENT')
            .length ??
        0;
    final absent = provider.currentSheet?.records
            .where((r) => r.status == 'ABSENT')
            .length ??
        0;
    final double percent = total > 0 ? (present / total) : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? kSurfaceDark : kSurfaceLight;
    final textColor = isDark ? kTextWhite : Colors.black87;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
      decoration: BoxDecoration(color: surfaceColor, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4))
      ]),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(classData.name,
                  style: GoogleFonts.inter(fontSize: 14.sp, color: kTextGrey)),
              Text(
                DateFormat("dd 'de' MMMM, yyyy", "pt_BR").format(selectedDate),
                style: GoogleFonts.inter(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor),
              ),
            ],
          ),
          const Spacer(),
          _StatCard(
              label: "Presentes",
              value: "$present",
              color: kSuccessColor,
              icon: PhosphorIcons.check),
          SizedBox(width: 16.w),
          _StatCard(
              label: "Faltas",
              value: "$absent",
              color: kErrorColor,
              icon: PhosphorIcons.x),
          SizedBox(width: 16.w),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50.w,
                height: 50.w,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 5,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2),
                  color: kSuccessColor,
                ),
              ),
              Text("${(percent * 100).toInt()}%",
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            ],
          ),
          SizedBox(width: 24.w),
          IconButton(
            icon: Icon(PhosphorIcons.arrows_clockwise, color: kTextGrey),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      color: color)),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10.sp, color: color.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }
}

// 3. GRID DE ALUNOS
class _StudentGrid extends StatelessWidget {
  final DateTime selectedDate;
  const _StudentGrid({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? kSurfaceDark : kSurfaceLight;
    final textColor = isDark ? kTextWhite : Colors.black87;

    if (provider.currentSheet == null) return const SizedBox();
    final records = provider.currentSheet!.records;

    return GridView.builder(
      padding: EdgeInsets.all(32.w),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350.w,
        mainAxisSpacing: 16.h,
        crossAxisSpacing: 16.w,
        childAspectRatio: 2.8,
      ),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final isPresent = record.status == 'PRESENT';

        return Stack(
          children: [
            GestureDetector(
              onTap: () => provider.toggleStatus(record.studentId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(kBorderRadius),
                  border: Border.all(
                    color: isPresent
                        ? kSuccessColor.withOpacity(0.3)
                        : kErrorColor.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6.w,
                      decoration: BoxDecoration(
                        color: isPresent ? kSuccessColor : kErrorColor,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(kBorderRadius)),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: 16.w, right: 40.w, top: 8.h, bottom: 8.h),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20.sp,
                              backgroundImage: record.studentPhoto != null
                                  ? NetworkImage(record.studentPhoto!)
                                  : null,
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[200],
                              child: record.studentPhoto == null
                                  ? Text(record.studentName[0],
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey))
                                  : null,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.studentName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15.sp,
                                        color: textColor),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    isPresent ? "PRESENTE" : "FALTA",
                                    style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isPresent
                                            ? kSuccessColor
                                            : kErrorColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 4.w,
              top: 4.h,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => _StudentHistoryModal(
                        studentId: record.studentId,
                        studentName: record.studentName,
                        studentPhoto: record.studentPhoto,
                        classHistory: provider.history,
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Icon(PhosphorIcons.info,
                        size: 24.sp, color: kAccentOrange),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 4. MODAL DE HISTÓRICO
class _StudentHistoryModal extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String? studentPhoto;
  final List<dynamic> classHistory;

  const _StudentHistoryModal({
    super.key,
    required this.studentId,
    required this.studentName,
    this.studentPhoto,
    required this.classHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kSurfaceDark : Colors.white;
    final textColor = isDark ? kTextWhite : Colors.black87;

    debugPrint("\n========================================");
    debugPrint("🔍 DIAGNÓSTICO: ALUNO $studentName (ID: $studentId)");
    debugPrint("📂 Tamanho do Histórico recebido: ${classHistory.length} dias");

    int totalClasses = 0;
    int presentCount = 0;
    List<DateTime> absenceDates = [];

    for (var dayRecord in classHistory) {
      if (!dayRecord.containsKey('records')) {
        debugPrint("❌ ERRO CRÍTICO: Chave 'records' não encontrada.");
        continue;
      }
      final rawRecords = dayRecord['records'];
      if (rawRecords is! List) continue;

      final studentRecord = rawRecords.firstWhere(
        (r) => r['studentId'].toString() == studentId.toString(),
        orElse: () => null,
      );

      if (studentRecord != null) {
        totalClasses++;
        final status =
            studentRecord['status']?.toString().toUpperCase() ?? 'ABSENT';

        if (status == 'PRESENT') {
          presentCount++;
        } else {
          if (dayRecord['date'] != null) {
            absenceDates.add(DateTime.parse(dayRecord['date']));
          }
        }
      }
    }

    final double frequency =
        totalClasses == 0 ? 0.0 : (presentCount / totalClasses);
    final int percentage = (frequency * 100).toInt();

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450.w,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24.sp,
                  backgroundImage:
                      studentPhoto != null ? NetworkImage(studentPhoto!) : null,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[200],
                  child: studentPhoto == null
                      ? Text(studentName[0],
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, color: Colors.grey))
                      : null,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                          style: GoogleFonts.inter(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      Text("Relatório Individual",
                          style: GoogleFonts.inter(
                              fontSize: 12.sp, color: kTextGrey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIcons.x, color: kTextGrey),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: (percentage >= 75 ? kSuccessColor : kErrorColor)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              (percentage >= 75 ? kSuccessColor : kErrorColor)
                                  .withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$percentage%",
                            style: GoogleFonts.inter(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: percentage >= 75
                                    ? kSuccessColor
                                    : kErrorColor)),
                        Text("Frequência",
                            style: GoogleFonts.inter(
                                fontSize: 12.sp, color: kTextGrey)),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: kAccentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccentOrange.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${absenceDates.length}",
                            style: GoogleFonts.inter(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: kAccentOrange)),
                        Text("Total de Faltas",
                            style: GoogleFonts.inter(
                                fontSize: 12.sp, color: kTextGrey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Text("Histórico de Ausências",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                    color: textColor)),
            SizedBox(height: 12.h),
            Container(
              height: 150.h,
              decoration: BoxDecoration(
                  color: isDark ? kBackgroundDark : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[300]!)),
              child: absenceDates.isEmpty
                  ? Center(
                      child: Text("Nenhuma falta registrada.",
                          style: GoogleFonts.inter(
                              color: kTextGrey, fontSize: 12.sp)))
                  : ListView.builder(
                      padding: EdgeInsets.all(8.w),
                      itemCount: absenceDates.length,
                      itemBuilder: (context, index) {
                        final date = absenceDates[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                              color: kErrorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: kErrorColor.withOpacity(0.2))),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.calendar_x,
                                  size: 16, color: kErrorColor),
                              SizedBox(width: 8.w),
                              Text(
                                DateFormat("dd 'de' MMMM", "pt_BR")
                                    .format(date),
                                style: GoogleFonts.inter(
                                    color: kErrorColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }
}
