import 'package:academyhub_mobile/model/assessment_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class StudentExamResultScreen extends StatelessWidget {
  final Assessment assessment;
  final AssessmentAttempt attempt;

  const StudentExamResultScreen({
    super.key,
    required this.assessment,
    required this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgDark = const Color(0xFF121214);
    final Color cardDark = const Color(0xFF202024);
    final Color primary = const Color(0xFF8257E5);
    final Color textWhite = const Color(0xFFE1E1E6);
    final Color textGrey = const Color(0xFFA8A8B3);
    final Color success = const Color(0xFF04D361);
    final Color danger = const Color(0xFFCC2937);

    final int totalQuestions = assessment.questions.length;
    final int correctCount = attempt.correctCount ?? 0;
    final double scorePercentage = (correctCount / totalQuestions) * 100;

    final duration = Duration(milliseconds: attempt.telemetry.totalTimeMs);
    final String timeFormatted =
        "${duration.inMinutes}m ${(duration.inSeconds % 60).toString().padLeft(2, '0')}s";

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header (Placar)
            Container(
              padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 40.h),
              decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(32.r)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 30,
                        offset: const Offset(0, 10))
                  ]),
              child: Column(
                children: [
                  Icon(PhosphorIcons.medal_fill,
                      size: 72.sp, color: Colors.amber),
                  SizedBox(height: 20.h),
                  Text("Atividade Concluída!",
                      style: GoogleFonts.inter(
                          color: textWhite,
                          fontSize: 26.sp,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8.h),
                  Text("Confira seu desempenho abaixo.",
                      style: TextStyle(color: textGrey, fontSize: 16.sp)),
                  SizedBox(height: 32.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem("Nota Final",
                          "${scorePercentage.toInt()}%", primary, textWhite),
                      Container(width: 1, height: 40.h, color: Colors.white10),
                      _buildStatItem(
                          "Acertos",
                          "$correctCount / $totalQuestions",
                          success,
                          textWhite),
                      Container(width: 1, height: 40.h, color: Colors.white10),
                      _buildStatItem(
                          "Tempo", timeFormatted, Colors.blueAccent, textWhite),
                    ],
                  ),
                ],
              ),
            ),

            // Lista de Questões (Revisão)
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(24.w),
                itemCount: totalQuestions,
                itemBuilder: (context, index) {
                  final question = assessment.questions[index];
                  final userAnswer = attempt.answers.firstWhere(
                      (a) => a.questionIndex == index,
                      orElse: () => AnswerDetail(
                          questionIndex: index,
                          selectedOptionIndex: -1,
                          timeSpentMs: 0));

                  final bool isCorrect = userAnswer.isCorrect ?? false;
                  final int selectedIdx = userAnswer.selectedOptionIndex;

                  return Container(
                    margin: EdgeInsets.only(bottom: 20.h),
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                            color: isCorrect
                                ? success.withOpacity(0.3)
                                : danger.withOpacity(0.3),
                            width: 1)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14.sp,
                              backgroundColor: isCorrect
                                  ? success.withOpacity(0.2)
                                  : danger.withOpacity(0.2),
                              child: Icon(
                                isCorrect
                                    ? PhosphorIcons.check
                                    : PhosphorIcons.x,
                                size: 16.sp,
                                color: isCorrect ? success : danger,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              "Questão ${index + 1}",
                              style: GoogleFonts.inter(
                                  color: textWhite,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Text(question.questionText,
                            style: TextStyle(
                                color: textGrey, fontSize: 16.sp, height: 1.4)),
                        SizedBox(height: 20.h),
                        if (selectedIdx != -1)
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                                color: isCorrect
                                    ? success.withOpacity(0.05)
                                    : danger.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12.r)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Sua resposta:",
                                    style: TextStyle(
                                        color: textGrey, fontSize: 14.sp)),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    question.options[selectedIdx],
                                    style: TextStyle(
                                        color: isCorrect ? success : danger,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isCorrect && question.explanation != null) ...[
                          SizedBox(height: 16.h),
                          Text("Explicação:",
                              style: TextStyle(
                                  color: primary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 6.h),
                          Text(question.explanation!.correct,
                              style: TextStyle(
                                  color: textWhite,
                                  fontSize: 14.sp,
                                  height: 1.4)),
                        ]
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
            color: cardDark,
            border: Border(top: BorderSide(color: Colors.white10))),
        child: SizedBox(
          height: 56.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
                elevation: 0),
            onPressed: () => context.go('/'), // Volta para o início
            child: Text("VOLTAR AO INÍCIO",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, Color textWhite) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 28.sp, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 14.sp, color: textWhite.withOpacity(0.6))),
      ],
    );
  }
}
