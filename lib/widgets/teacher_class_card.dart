import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/services/enrollment_service.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TeacherClassCard extends StatefulWidget {
  final ClassModel classData;
  final VoidCallback onTap;
  final VoidCallback onOpenAttendance;
  final bool isDark;

  const TeacherClassCard({
    super.key,
    required this.classData,
    required this.onTap,
    required this.onOpenAttendance,
    required this.isDark,
  });

  @override
  State<TeacherClassCard> createState() => _TeacherClassCardState();
}

class _TeacherClassCardState extends State<TeacherClassCard> {
  int _studentCount = 0;
  bool _loadingCount = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentCount();
  }

  Future<void> _fetchStudentCount() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    try {
      final enrollments = await EnrollmentService().getEnrollments(token,
          filter: {'class': widget.classData.id, 'status': 'Ativa'});
      if (mounted) {
        setState(() {
          _studentCount = enrollments.length;
          _loadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cores extraídas fielmente dos prints
    final cardBg = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = widget.isDark ? Colors.white : Colors.black;
    final textSecondary =
        widget.isDark ? Colors.grey[400] : const Color(0xFF666666);

    // Cor do ícone de status (Verde do print)
    final statusColor = const Color(0xFF4CAF50);
    final statusBg = const Color(0xFFE8F5E9);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r), // Arredondamento suave
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: widget.isDark ? Colors.grey[800]! : const Color(0xFFF0F0F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(20.w), // Padding interno generoso
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- HEADER DO CARD ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícone de Status (Check Verde)
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.green.withOpacity(0.2)
                            : statusBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.check, // Icone de check como no print
                        color: statusColor,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 15.w),
                    // Textos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.classData.name, // Ex: "1º B"
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, // Bold forte
                              fontSize: 18.sp,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            "${widget.classData.grade} • ${widget.classData.shift}",
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menu de 3 pontos (Decorativo por enquanto)
                    Icon(Icons.more_vert, color: Colors.grey[400], size: 20.sp),
                  ],
                ),

                const Spacer(),

                // --- TAG DE ALUNOS ---
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.grey[800]
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.users,
                          size: 14.sp, color: textSecondary),
                      SizedBox(width: 6.w),
                      _loadingCount
                          ? SizedBox(
                              width: 10.w,
                              height: 10.w,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2))
                          : Text(
                              "$_studentCount Alunos",
                              style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w600),
                            ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                // --- AÇÕES (Identidade Visual Academy Hub) ---
                Row(
                  children: [
                    // Botão Frequência (Secundário: Branco/Verde)
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 42.h,
                        child: OutlinedButton(
                          onPressed: widget.onOpenAttendance,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.check_square,
                                  size: 18.sp, color: Colors.green),
                              SizedBox(width: 8.w),
                              Text("Frequência",
                                  style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          textPrimary // Texto escuro no botão claro
                                      )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    // Botão Atividades/Notas (Primário: Preto/Amarelo)
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 42.h,
                        child: ElevatedButton(
                          onPressed: widget.onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.black, // Fundo PRETO (Academy Hub Style)
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.file_text,
                                  size: 18.sp,
                                  color: Colors.amber), // Ícone Amarelo
                              SizedBox(width: 8.w),
                              Text(
                                  "Atividades", // Label do print (mas abre notas)
                                  style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
