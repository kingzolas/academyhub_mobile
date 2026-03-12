import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/attendance_model.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceRecord student;

  const AttendanceCard({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Foto do Aluno
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200, width: 4),
              image: DecorationImage(
                fit: BoxFit.cover,
                image: (student.studentPhoto != null &&
                        student.studentPhoto!.isNotEmpty)
                    ? NetworkImage(student.studentPhoto!)
                    : const AssetImage('lib/assets/avatar_placeholder.png')
                        as ImageProvider,
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // Nome do Aluno
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              student.studentName,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(height: 8.h),

          // ID ou Matrícula (Opcional, para confirmação)
          Text(
            "Matrícula: ${student.studentId.substring(0, 6)}...",
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
