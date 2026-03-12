import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Services
import '../../services/assessment_attempt_service.dart';
import '../../services/websocket.dart'; // Import your WebSocketService

// Screens
import 'student_exam_execution_screen.dart';
// import 'student_exam_result_screen.dart'; // Optional for direct result navigation

class StudentActivitiesScreen extends StatefulWidget {
  const StudentActivitiesScreen({super.key});

  @override
  State<StudentActivitiesScreen> createState() =>
      _StudentActivitiesScreenState();
}

class _StudentActivitiesScreenState extends State<StudentActivitiesScreen>
    with SingleTickerProviderStateMixin {
  final AssessmentAttemptService _service = AssessmentAttemptService();

  // Singleton instance of WebSocketService (already connected in Dashboard)
  final WebSocketService _socketService = WebSocketService();
  StreamSubscription? _socketSubscription;

  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingList = [];
  List<Map<String, dynamic>> _completedList = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAssessments();
    _listenToRealTimeUpdates();
  }

  // --- REAL-TIME UPDATES ---
  void _listenToRealTimeUpdates() {
    // We rely on the existing connection from Dashboard
    _socketSubscription = _socketService.stream.listen((message) {
      if (message['type'] == null) return;

      if (message['type'] == 'NEW_ASSESSMENT' ||
          message['type'] == 'DELETED_ASSESSMENT' ||
          message['type'] == 'UPDATED_ASSESSMENT') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message['type'] == 'NEW_ASSESSMENT'
                  ? "Nova atividade disponível!"
                  : "Lista de atividades atualizada."),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.blueAccent,
              duration: const Duration(seconds: 3),
            ),
          );
          // Silent refresh
          _fetchAssessments();
        }
      }
    });
  }

  Future<void> _fetchAssessments() async {
    try {
      if (!mounted) return;
      // Only show spinner if lists are empty to avoid flickering
      if (_pendingList.isEmpty && _completedList.isEmpty) {
        setState(() => _isLoading = true);
      }

      final allAssessments = await _service.getStudentAssessments();

      if (!mounted) return;
      setState(() {
        // ✅ CORREÇÃO AQUI: Adicione 'PUBLISHED' na verificação
        _pendingList = allAssessments
            .where((a) =>
                a['status'] == 'PUBLISHED' || // <--- Adicionado
                a['status'] == 'PENDING' ||
                a['status'] == 'IN_PROGRESS')
            .toList()
            .cast<Map<String, dynamic>>();

        _completedList = allAssessments
            .where(
                (a) => a['status'] == 'COMPLETED' || a['status'] == 'ABANDONED')
            .toList()
            .cast<Map<String, dynamic>>();

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onAssessmentTap(Map<String, dynamic> item) {
    if (item['status'] == 'COMPLETED') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Prova finalizada. Nota: ${item['score'] ?? '-'}"),
          backgroundColor: Colors.green,
        ),
      );
      // Optional: Navigate to result screen directly if needed
    } else {
      // Native Navigation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentExamExecutionScreen(
            assessmentId: item['_id'],
          ),
        ),
      ).then((_) {
        // Refresh list upon return
        _fetchAssessments();
      });
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF09090A) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor =
        isDark ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);
    final subTextColor =
        isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final accentColor = const Color(0xFF8257E5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Minhas Atividades",
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 18.sp,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: subTextColor,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "A Fazer"),
            Tab(text: "Concluídas"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.warning_circle,
                          size: 48, color: Colors.redAccent),
                      SizedBox(height: 16.h),
                      Text("Não foi possível carregar.",
                          style: GoogleFonts.inter(color: subTextColor)),
                      TextButton(
                          onPressed: _fetchAssessments,
                          child: const Text("Tentar Novamente"))
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_pendingList,
                        isHistory: false,
                        textColor: textColor,
                        subColor: subTextColor,
                        cardColor: cardColor),
                    _buildList(_completedList,
                        isHistory: true,
                        textColor: textColor,
                        subColor: subTextColor,
                        cardColor: cardColor),
                  ],
                ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items,
      {required bool isHistory,
      required Color textColor,
      required Color subColor,
      required Color cardColor}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: isHistory
                    ? Colors.green.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHistory ? PhosphorIcons.check_circle : PhosphorIcons.coffee,
                size: 48.sp,
                color: isHistory ? Colors.green : Colors.blueAccent,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              isHistory ? "Histórico vazio." : "Tudo em dia! Sem atividades.",
              style: GoogleFonts.inter(
                  color: subColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(20.w),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildAssessmentCard(item, textColor, subColor, cardColor);
      },
    );
  }

  Widget _buildAssessmentCard(Map<String, dynamic> item, Color textColor,
      Color subColor, Color cardColor) {
    final bool isCompleted = item['status'] == 'COMPLETED';
    final bool isInProgress = item['status'] == 'IN_PROGRESS';

    String dateStr = "Sem data";
    if (item['deadline'] != null) {
      dateStr =
          DateFormat('dd MMM, HH:mm').format(DateTime.parse(item['deadline']));
    }

    Color statusColor;
    String statusText;

    if (isInProgress) {
      statusColor = Colors.orange;
      statusText = "Em Andamento";
    } else if (isCompleted) {
      statusColor = Colors.green;
      statusText = "Concluída";
    } else {
      // Isso aqui já cobre o PUBLISHED, mas garante que o texto faça sentido
      statusColor = const Color(0xFF8257E5);
      statusText = "Nova"; // ou "Pendente"
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onAssessmentTap(item),
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8257E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        (item['subject'] ?? "GERAL").toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8257E5)),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        SizedBox(width: 6.w),
                        Text(statusText,
                            style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: statusColor,
                                fontWeight: FontWeight.w600)),
                      ],
                    )
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  item['title'] ?? "Sem título",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 12.h),
                Divider(color: subColor.withOpacity(0.1)),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(PhosphorIcons.clock, size: 16.sp, color: subColor),
                    SizedBox(width: 6.w),
                    Text(
                      "Entrega: $dateStr",
                      style:
                          GoogleFonts.inter(fontSize: 12.sp, color: subColor),
                    ),
                    Spacer(),
                    if (isCompleted && item['score'] != null)
                      Text(
                        "Nota: ${item['score']}",
                        style: GoogleFonts.lexend(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    if (!isCompleted)
                      Icon(PhosphorIcons.caret_right,
                          size: 16.sp, color: subColor)
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
