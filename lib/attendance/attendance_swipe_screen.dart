import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../model/attendance_model.dart';
import '../../providers/attendance_provider.dart';
// [NOVO] Import do modal elegante de salvamento
import '../../widgets/attendance_operation_dialog.dart';

class AttendanceSwipeScreen extends StatefulWidget {
  final String classId;
  final String className;
  final VoidCallback onBack;

  const AttendanceSwipeScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.onBack,
  });

  @override
  State<AttendanceSwipeScreen> createState() => _AttendanceSwipeScreenState();
}

class _AttendanceSwipeScreenState extends State<AttendanceSwipeScreen> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false)
          .loadDailyAttendance(widget.classId, DateTime.now());
    });
  }

  void _onSwipeEnd(
      int previousIndex, int targetIndex, SwiperActivity activity) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final sheet = provider.currentSheet;

    if (sheet == null) return;
    if (previousIndex >= sheet.records.length) return;

    final student = sheet.records[previousIndex];

    switch (activity) {
      case Swipe():
        HapticFeedback.lightImpact();
        if (activity.direction == AxisDirection.right) {
          provider.updateStudentStatus(student.studentId, 'PRESENT');
        } else if (activity.direction == AxisDirection.left) {
          provider.updateStudentStatus(student.studentId, 'ABSENT');
        }
        break;
      default:
        break;
    }
  }

  void _onEnd() {
    setState(() {
      _isFinished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final sheet = attendanceProvider.currentSheet;
    final isLoading = attendanceProvider.isLoading;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[500];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caret_left, color: textColor, size: 28.sp),
          onPressed: widget.onBack,
        ),
        title: Column(
          children: [
            Text("Frequência",
                style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp)),
            Text(widget.className,
                style: GoogleFonts.inter(
                    color: const Color(0xFF00A859),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A859)))
          : sheet == null || sheet.records.isEmpty
              ? _buildEmptyState(textColor, subTextColor)
              : _isFinished
                  ? _buildSummaryView(attendanceProvider, isDark, textColor)
                  : _buildSwipeView(sheet.records, isDark, subTextColor),
    );
  }

  Widget _buildSwipeView(
      List<AttendanceRecord> records, bool isDark, Color? subTextColor) {
    return Column(
      children: [
        SizedBox(height: 10.h),
        // Dica visual
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "Arraste para os lados",
            style: GoogleFonts.inter(
                color: subTextColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(height: 20.h),

        // Área dos Cards
        SizedBox(
          height: 480.h,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 24.w), // Aumentei margem lateral
            child: AppinioSwiper(
              controller: _swiperController,
              cardCount: records.length,
              onSwipeEnd: _onSwipeEnd,
              onEnd: _onEnd,
              swipeOptions: const SwipeOptions.only(left: true, right: true),
              cardBuilder: (BuildContext context, int index) {
                return _StudentCard(student: records[index], isDark: isDark);
              },
            ),
          ),
        ),

        const Spacer(),

        // Botões de Ação
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(
                icon: PhosphorIcons.x,
                color: const Color(0xFFFF4B4B),
                label: "Faltou",
                isDark: isDark,
                onTap: () => _swiperController.swipeLeft(),
              ),
              _buildActionButton(
                icon: PhosphorIcons.check,
                color: const Color(0xFF00A859),
                label: "Presente",
                isDark: isDark,
                onTap: () => _swiperController.swipeRight(),
              ),
            ],
          ),
        ),

        // Espaço extra para o menu não cobrir
        SizedBox(height: 90.h),
      ],
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required Color color,
      required String label,
      required bool isDark,
      required VoidCallback onTap}) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            width: 70.w,
            height: 70.w,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 32.sp),
          ),
        ),
        SizedBox(height: 8.h),
        Text(label,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: color, fontSize: 14.sp))
      ],
    );
  }

  Widget _buildSummaryView(
      AttendanceProvider provider, bool isDark, Color textColor) {
    final records = provider.currentSheet!.records;
    final presentCount = records.where((r) => r.status == 'PRESENT').length;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(20.w),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Resumo",
                      style: GoogleFonts.inter(
                          color: Colors.grey, fontSize: 12.sp)),
                  Text("Confirmação",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                          color: textColor)),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A859).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("$presentCount/${records.length}",
                    style: GoogleFonts.inter(
                        color: const Color(0xFF00A859),
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            itemCount: records.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final student = records[index];
              final isPresent = student.status == 'PRESENT';

              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: borderColor),
                ),
                child: ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 4.h, horizontal: 16.w),
                  leading: CircleAvatar(
                    radius: 20.sp,
                    backgroundColor: const Color(0xFF00A859).withOpacity(0.1),
                    child: Text(
                      student.studentName.isNotEmpty
                          ? student.studentName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00A859)),
                    ),
                  ),
                  title: Text(student.studentName,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          fontSize: 14.sp)),
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      activeColor: const Color(0xFF00A859),
                      inactiveTrackColor:
                          const Color(0xFFFF4B4B).withOpacity(0.2),
                      inactiveThumbColor: const Color(0xFFFF4B4B),
                      value: isPresent,
                      onChanged: (val) {
                        provider.toggleStatus(student.studentId);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A859),
                elevation: 4,
                shadowColor: const Color(0xFF00A859).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r)),
              ),
              onPressed: () async {
                // [NOVO] Integração com o Modal Elegante de Salvamento
                final success = await showAttendanceOperationDialog(
                  context: context,
                  operation: () async {
                    final isSaved = await provider.submitAttendance();
                    if (!isSaved) {
                      throw Exception(
                          provider.error ?? "Ocorreu um erro desconhecido.");
                    }
                  },
                );

                // Se o diálogo retornar sucesso (true), fecha a tela de chamada
                if (success == true && mounted) {
                  widget.onBack();
                }
              },
              child: provider.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("Finalizar Chamada",
                      style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
            ),
          ),
        ),
        SizedBox(height: 90.h),
      ],
    );
  }

  Widget _buildEmptyState(Color textColor, Color? subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30.r),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(PhosphorIcons.users_three,
                size: 64.sp, color: subTextColor),
          ),
          SizedBox(height: 20.h),
          Text("Nenhum aluno nesta turma.",
              style: GoogleFonts.inter(
                  color: subTextColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// --- WIDGET DO CARTÃO MELHORADO ---
class _StudentCard extends StatelessWidget {
  final AttendanceRecord student;
  final bool isDark;

  const _StudentCard({required this.student, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    // Lógica para diminuir a fonte se o nome for muito grande
    final double nameFontSize = student.studentName.length > 25 ? 22.sp : 26.sp;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center, // Centraliza tudo por padrão
        children: [
          // Background Gradient (Topo)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150.h,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF00A859).withOpacity(0.05),
                    cardBg.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          // Conteúdo Central
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 150.w,
                height: 150.w,
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF00A859).withOpacity(0.2),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF00A859).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  backgroundImage: (student.studentPhoto != null &&
                          student.studentPhoto!.isNotEmpty)
                      ? NetworkImage(student.studentPhoto!)
                      : null,
                  child: student.studentPhoto == null ||
                          student.studentPhoto!.isEmpty
                      ? Text(
                          student.studentName.isNotEmpty
                              ? student.studentName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                              fontSize: 50.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00A859)),
                        )
                      : null,
                ),
              ),

              SizedBox(height: 35.h),

              // Nome do Aluno (Em container de altura fixa para evitar pulos)
              SizedBox(
                height:
                    70.h, // Altura fixa reservada para até 2 linhas de texto
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      student.studentName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: nameFontSize, // Tamanho dinâmico
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.1, // Altura da linha um pouco mais justa
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              // ID / Matrícula
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black38 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20.r), // Mais arredondado
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.identification_card,
                        size: 16.sp, color: Colors.grey),
                    SizedBox(width: 8.w),
                    Text(
                      "ID: ${student.studentId.length > 6 ? student.studentId.substring(student.studentId.length - 6).toUpperCase() : student.studentId}",
                      style: GoogleFonts.sourceCodePro(
                          fontSize: 13.sp,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
