import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../model/assessment_models.dart';

class StudentExamResultScreen extends StatefulWidget {
  final Assessment assessment;
  final AssessmentAttempt attempt;

  const StudentExamResultScreen({
    super.key,
    required this.assessment,
    required this.attempt,
  });

  @override
  State<StudentExamResultScreen> createState() =>
      _StudentExamResultScreenState();
}

class _StudentExamResultScreenState extends State<StudentExamResultScreen>
    with SingleTickerProviderStateMixin {
  // --- PALETA VIBRANTE (Gamer/Streamer Vibe) ---
  final Color _bgDeep = const Color(0xFF09090A);
  final Color _cardSurface = const Color(0xFF18181B);
  final Color _primary = const Color(0xFF8257E5);
  final Color _success = const Color(0xFF04D361);
  final Color _danger = const Color(0xFFFF4C61);
  final Color _warning = const Color(0xFFFFB86C);
  final Color _textWhite = const Color(0xFFF4F4F5);
  final Color _textGrey = const Color(0xFFA1A1AA);

  late AnimationController _controller;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalQuestions = widget.assessment.questions.length;
    final int correctCount = widget.attempt.correctCount ?? 0;
    final double scorePercentage = (correctCount / totalQuestions) * 100;

    String titleText;
    String subText;
    Color scoreColor;
    IconData scoreIcon;

    if (scorePercentage >= 90) {
      titleText = "LENDÁRIO!";
      subText = "Você destruiu essa prova!";
      scoreColor = _success;
      scoreIcon = PhosphorIcons.trophy_fill;
    } else if (scorePercentage >= 70) {
      titleText = "MANDOU BEM!";
      subText = "Resultado sólido.";
      scoreColor = _success;
      scoreIcon = PhosphorIcons.thumbs_up_fill;
    } else if (scorePercentage >= 50) {
      titleText = "NA MÉDIA";
      subText = "Passou, mas dá pra melhorar.";
      scoreColor = _warning;
      scoreIcon = PhosphorIcons.minus_circle_fill;
    } else {
      titleText = "GAME OVER?";
      subText = "Não desanime. Revise e tente de novo.";
      scoreColor = _danger;
      scoreIcon = PhosphorIcons.warning_circle_fill;
    }

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bgDeep,
        splashColor: _primary.withOpacity(0.2),
        highlightColor: _primary.withOpacity(0.1),
      ),
      child: Scaffold(
        backgroundColor: _bgDeep,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. HEADER (NOTA)
            SliverAppBar(
              backgroundColor: _bgDeep,
              expandedHeight: 300.h,
              floating: false,
              pinned: true,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle),
                  child: Icon(PhosphorIcons.x, color: _textWhite, size: 20.sp),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_primary.withOpacity(0.2), _bgDeep],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 40.h),
                        ScaleTransition(
                          scale: _scoreAnimation,
                          child: Container(
                            width: 130.w,
                            height: 130.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _cardSurface,
                              border: Border.all(
                                  color: scoreColor.withOpacity(0.5), width: 4),
                              boxShadow: [
                                BoxShadow(
                                    color: scoreColor.withOpacity(0.3),
                                    blurRadius: 40,
                                    spreadRadius: 0),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "${scorePercentage.toInt()}%",
                                    style: GoogleFonts.lexend(
                                        fontSize: 36.sp,
                                        fontWeight: FontWeight.w800,
                                        color: scoreColor),
                                  ),
                                  Text("XP TOTAL",
                                      style: GoogleFonts.inter(
                                          fontSize: 10.sp,
                                          color: _textGrey,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(scoreIcon, color: scoreColor, size: 24.sp),
                            SizedBox(width: 8.w),
                            Text(titleText,
                                style: GoogleFonts.lexend(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.bold,
                                    color: _textWhite,
                                    letterSpacing: 1)),
                          ],
                        ),
                        Text(subText,
                            style: GoogleFonts.inter(
                                fontSize: 14.sp, color: _textGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. STATS GRID
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: _cardSurface,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatBadge(PhosphorIcons.target, "$correctCount",
                          "Acertos", _success),
                      Container(
                          width: 2.w, height: 30.h, color: Colors.white10),
                      _buildStatBadge(PhosphorIcons.warning,
                          "${totalQuestions - correctCount}", "Erros", _danger),
                      Container(
                          width: 2.w, height: 30.h, color: Colors.white10),
                      _buildStatBadge(
                          PhosphorIcons.timer,
                          "${(widget.attempt.telemetry.totalTimeMs / 60000).ceil()}m",
                          "Tempo",
                          _primary),
                    ],
                  ),
                ),
              ),
            ),

            // 3. TÍTULO DA LISTA
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 16.h),
              sliver: SliverToBoxAdapter(
                child: Text("REVIEW DA MISSÃO",
                    style: GoogleFonts.lexend(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: _textGrey,
                        letterSpacing: 1.5)),
              ),
            ),

            // 4. LISTA DE QUESTÕES (AQUI ESTÁ A LÓGICA RESTAURADA)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final question = widget.assessment.questions[index];

                    // Encontra a resposta do usuário para esta questão
                    final userAnswer = widget.attempt.answers.firstWhere(
                      (a) => a.questionIndex == index,
                      orElse: () => AnswerDetail(
                          questionIndex: index,
                          selectedOptionIndex: -1, // Não respondeu
                          timeSpentMs: 0,
                          switchedAppCount: 0),
                    );

                    final isCorrect = userAnswer.isCorrect ?? false;

                    return _buildGamerAccordion(
                        index, question, userAnswer, isCorrect);
                  },
                  childCount: totalQuestions,
                ),
              ),
            ),

            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),

        // FAB VOLTAR
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          width: double.infinity,
          height: 64.h,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r)),
              elevation: 10,
              shadowColor: _primary.withOpacity(0.5),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8257E5), Color(0xFF996DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  "VOLTAR AO LOBBY",
                  style: GoogleFonts.lexend(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildStatBadge(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18.sp, color: color),
        ),
        SizedBox(height: 8.h),
        Text(value,
            style: GoogleFonts.lexend(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: _textWhite)),
        Text(label,
            style: GoogleFonts.inter(fontSize: 12.sp, color: _textGrey)),
      ],
    );
  }

  Widget _buildGamerAccordion(
      int index, Question question, AnswerDetail answer, bool isCorrect) {
    final statusColor = isCorrect ? _success : _danger;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: _cardSurface,
            collapsedBackgroundColor: _cardSurface,
            tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),

            // Ícone de Status
            leading: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: statusColor.withOpacity(0.3))),
              child: Icon(
                isCorrect ? PhosphorIcons.check_fill : PhosphorIcons.x_fill,
                color: statusColor,
                size: 20.sp,
              ),
            ),

            title: Text(
              "Questão ${index + 1}",
              style: GoogleFonts.lexend(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: _textWhite),
            ),

            subtitle: Row(
              children: [
                if (!isCorrect) ...[
                  Icon(PhosphorIcons.arrow_bend_down_right,
                      color: _danger, size: 14.sp),
                  SizedBox(width: 4.w),
                ],
                Text(
                  isCorrect ? "Correto" : "Incorreto",
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: statusColor,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),

            trailing:
                Icon(PhosphorIcons.caret_down, color: _textGrey, size: 18.sp),

            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: Colors.white10),
                    SizedBox(height: 12.h),

                    // Enunciado
                    Text(question.questionText,
                        style: GoogleFonts.inter(
                            fontSize: 15.sp, height: 1.5, color: _textWhite)),
                    SizedBox(height: 24.h),

                    // 1. O QUE O USUÁRIO MARCOU (SE ERROU)
                    if (!isCorrect && answer.selectedOptionIndex != -1)
                      _buildFeedbackCard(
                        title: "VOCÊ MARCOU",
                        content: question.options[answer.selectedOptionIndex],
                        color: _danger,
                        icon: PhosphorIcons.x_circle,
                      ),

                    if (!isCorrect && answer.selectedOptionIndex != -1)
                      SizedBox(height: 12.h),

                    // 2. GABARITO (SEMPRE MOSTRA)
                    _buildFeedbackCard(
                      title: "GABARITO",
                      content: question.explanation?.correct ??
                          // Se não tiver explicação específica, mostra a opção correta
                          question.options[question.correctIndex!],
                      color: _success,
                      icon: PhosphorIcons.check_circle,
                    ),

                    // 3. EXPLICAÇÃO EXTRA (SE HOUVER)
                    // Verifica se explanation.correct tem texto adicional além da resposta
                    if (question.explanation != null &&
                        question.explanation!.correct != null &&
                        question.explanation!.correct!.length > 20) ...[
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: _primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(PhosphorIcons.lightbulb_fill,
                                color: _primary, size: 20.sp),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                // Aqui você pode usar explanation.correct ou um campo específico 'reason'
                                question.explanation!.correct!,
                                style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    color: _textWhite.withOpacity(0.9),
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(
      {required String title,
      required String content,
      required Color color,
      required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14.sp, color: color),
              SizedBox(width: 6.w),
              Text(title,
                  style: GoogleFonts.lexend(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.5)),
            ],
          ),
          SizedBox(height: 6.h),
          Text(content,
              style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: _textWhite,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
