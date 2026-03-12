import 'dart:async';
// ✅ REMOVIDO: import 'dart:io';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
// ✅ NOVO PACOTE
import 'package:screen_protector/screen_protector.dart';

import '../../model/assessment_models.dart';
import '../../services/assessment_attempt_service.dart';
import 'student_exam_result_screen.dart';

class StudentExamExecutionScreen extends StatefulWidget {
  final String assessmentId;

  const StudentExamExecutionScreen({super.key, required this.assessmentId});

  @override
  State<StudentExamExecutionScreen> createState() =>
      _StudentExamExecutionScreenState();
}

class _StudentExamExecutionScreenState extends State<StudentExamExecutionScreen>
    with WidgetsBindingObserver {
  final AssessmentAttemptService _attemptService = AssessmentAttemptService();
  final FocusNode _keyboardFocusNode = FocusNode();

  Assessment? _assessment;
  String? _attemptId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  bool _isAlreadyCompleted = false;
  bool _hasStartedExamUI = false;

  int _currentQuestionIndex = 0;
  Map<int, int> _selectedAnswers = {};

  // --- TELEMETRIA ---
  DateTime? _examStartTime;
  DateTime? _questionStartTime;
  final Map<int, int> _timeSpentPerQuestion = {};

  int _focusLostCount = 0;
  int _focusLostTimeMs = 0;
  DateTime? _focusLostTimestamp;
  int _screenshotCount = 0;
  int _resizeCount = 0;

  // Design System (Modo Foco - Sempre Dark)
  final Color _bgDeep = const Color(0xFF09090A);
  final Color _cardSurface = const Color(0xFF18181B);
  final Color _primary = const Color(0xFF8257E5);
  final Color _accent = const Color(0xFF04D361);
  final Color _danger = const Color(0xFFFF4C61);
  final Color _textWhite = const Color(0xFFF4F4F5);
  final Color _textGrey = const Color(0xFFA1A1AA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExamData();
    _enableSecureMode(); // Ativa proteção
    _listenToScreenshots(); // Ouve tentativas de print (iOS/Android)
  }

  @override
  void dispose() {
    _disableSecureMode(); // Desativa proteção ao sair
    _keyboardFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ===========================================================================
  // 🔒 SEGURANÇA (ANTI-PRINT / GRAVAÇÃO) - ATUALIZADO PARA SCREEN_PROTECTOR
  // ===========================================================================

  void _listenToScreenshots() {
    if (kIsWeb) return;

    ScreenProtector.addListener(
      // 1º Argumento: Callback de Screenshot
      () {
        setState(() => _screenshotCount++);
        _showSecurityAlert("📸 Captura de tela detectada!");
        debugPrint("📸 Screenshot detectado pelo ScreenProtector");
      },

      // 2º Argumento: Callback de Gravação de Tela (O que faltava)
      (bool isCapturing) {
        if (isCapturing) {
          debugPrint("🎥 Iniciou gravação de tela");
          _showSecurityAlert("🎥 Gravação de tela detectada!");
        } else {
          debugPrint("🎥 Parou gravação de tela");
        }
      },
    );
  }

  Future<void> _enableSecureMode() async {
    if (kIsWeb) return;

    try {
      // 1. Bloqueia Screenshots e Gravação de Tela (Android)
      // No iOS, isso deixa a tela preta em gravações.
      await ScreenProtector.preventScreenshotOn();

      // 2. Protege contra vazamento no multitarefa (App Switcher fica borrado/branco)
      await ScreenProtector.protectDataLeakageOn();

      debugPrint("🔒 [Anti-Cheat] Modo Seguro Ativado (ScreenProtector)");
    } catch (e) {
      debugPrint("Erro ao ativar modo seguro: $e");
    }
  }

  Future<void> _disableSecureMode() async {
    if (kIsWeb) return;

    try {
      // Remove listener
      ScreenProtector.removeListener();

      // Desativa proteções
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
      debugPrint("🔓 [Anti-Cheat] Modo Seguro Desativado");
    } catch (e) {
      debugPrint("Erro ao desativar modo seguro: $e");
    }
  }

  // ===========================================================================
  // 🕵️ TELEMETRIA
  // ===========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasStartedExamUI) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _focusLostCount++;
      _focusLostTimestamp = DateTime.now();
      debugPrint("⚠️ [Anti-Cheat] Foco perdido! Contagem: $_focusLostCount");
    } else if (state == AppLifecycleState.resumed) {
      if (_focusLostTimestamp != null) {
        final timeAway =
            DateTime.now().difference(_focusLostTimestamp!).inMilliseconds;
        _focusLostTimeMs += timeAway;
        _focusLostTimestamp = null;

        _showSecurityAlert("⚠️ Atenção: Saída registrada! Mantenha o foco.");
      }
      FocusScope.of(context).requestFocus(_keyboardFocusNode);
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (!_hasStartedExamUI) return;

    if (event is RawKeyUpEvent) {
      // PrintScreen funciona bem na Web/Desktop
      if (event.logicalKey == LogicalKeyboardKey.printScreen) {
        setState(() => _screenshotCount++);
        _showSecurityAlert("📸 Captura de tela detectada!");
      }
    }
  }

  void _showSecurityAlert(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _danger,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(20.w),
      duration: const Duration(seconds: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      content: Row(children: [
        Icon(PhosphorIcons.warning_octagon_fill,
            color: Colors.white, size: 24.sp),
        SizedBox(width: 12.w),
        Expanded(
            child: Text(msg,
                style: GoogleFonts.lexend(fontWeight: FontWeight.bold))),
      ]),
    ));
  }

  // ===========================================================================
  // LÓGICA DO EXAME
  // ===========================================================================

  Future<void> _loadExamData() async {
    try {
      final result = await _attemptService.startAttempt(widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _attemptId = result['attemptId'];
        _assessment = result['assessment'];
        _isLoading = false;
      });
    } catch (e) {
      if (e.toString().contains("Você já realizou")) {
        setState(() {
          _isAlreadyCompleted = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleStartUi() {
    setState(() {
      _hasStartedExamUI = true;
      _examStartTime = DateTime.now();
      _questionStartTime = DateTime.now();
    });
    FocusScope.of(context).requestFocus(_keyboardFocusNode);
  }

  void _trackTime(int idx) {
    if (_questionStartTime != null) {
      final duration =
          DateTime.now().difference(_questionStartTime!).inMilliseconds;
      _timeSpentPerQuestion[idx] = (_timeSpentPerQuestion[idx] ?? 0) + duration;
    }
    _questionStartTime = DateTime.now();
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _assessment!.questions.length - 1) {
      _trackTime(_currentQuestionIndex);
      setState(() => _currentQuestionIndex++);
    } else {
      _submitExam();
    }
  }

  void _prevQuestion() {
    if (_currentQuestionIndex > 0) {
      _trackTime(_currentQuestionIndex);
      setState(() => _currentQuestionIndex--);
    }
  }

  Future<void> _submitExam() async {
    _trackTime(_currentQuestionIndex);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgDeep,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
            side: BorderSide(color: Colors.white10)),
        title: Text("ENVIAR MISSÃO?",
            style: GoogleFonts.lexend(
                color: _textWhite, fontWeight: FontWeight.bold)),
        content: Text(
            "Você respondeu ${_selectedAnswers.length} de ${_assessment!.questions.length} desafios.\nTem certeza que deseja enviar?",
            style: GoogleFonts.inter(color: _textGrey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("REVISAR", style: TextStyle(color: _textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: Text("CONFIRMAR",
                style: GoogleFonts.lexend(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isSubmitting = true);

    final answersPayload = _assessment!.questions
        .asMap()
        .entries
        .where((e) => _selectedAnswers.containsKey(e.key))
        .map((e) => AnswerDetail(
            questionIndex: e.key,
            selectedOptionIndex: _selectedAnswers[e.key]!,
            timeSpentMs: _timeSpentPerQuestion[e.key] ?? 0,
            switchedAppCount: 0))
        .toList();

    final telemetryData = Telemetry(
        totalTimeMs: DateTime.now().difference(_examStartTime!).inMilliseconds,
        focusLostCount: _focusLostCount,
        focusLostTimeMs: _focusLostTimeMs,
        screenshotCount: _screenshotCount,
        resizeCount: _resizeCount,
        deviceInfo: kIsWeb ? "Web Browser" : "Mobile App");

    final attemptData =
        AssessmentAttempt(answers: answersPayload, telemetry: telemetryData);

    try {
      final finalResult =
          await _attemptService.submitAttempt(_attemptId!, attemptData);
      if (!mounted) return;

      // Desativa proteção antes de sair
      _disableSecureMode();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StudentExamResultScreen(
            assessment: _assessment!,
            attempt: finalResult,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: _danger));
      setState(() => _isSubmitting = false);
    }
  }

  // ===========================================================================
  // UI BUILDERS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
          backgroundColor: _bgDeep,
          body: Center(child: CircularProgressIndicator(color: _primary)));
    }
    if (_isAlreadyCompleted) {
      return _buildStatusScreen(
          "MISSÃO CUMPRIDA",
          "Você já finalizou esta atividade.",
          PhosphorIcons.check_circle_fill,
          _accent);
    }
    if (_error != null) {
      return _buildStatusScreen(
          "ERRO", _error!, PhosphorIcons.warning_octagon_fill, _danger);
    }

    final double progress = _hasStartedExamUI
        ? (_currentQuestionIndex + 1) / _assessment!.questions.length
        : 0.0;

    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: _bgDeep,
        body: Stack(
          children: [
            Positioned(
              top: -150,
              left: 0,
              right: 0,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.0,
                    colors: [_primary.withOpacity(0.15), Colors.transparent],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  if (_hasStartedExamUI) _buildHud(progress),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _hasStartedExamUI
                          ? _buildGamerQuestionUI()
                          : _buildMissionBriefing(),
                    ),
                  ),
                  if (_hasStartedExamUI) _buildFooterControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(double progress) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _cardSurface,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(children: [
                Icon(PhosphorIcons.target, size: 16.sp, color: _primary),
                SizedBox(width: 8.w),
                Text(
                    "QUESTÃO ${_currentQuestionIndex + 1}/${_assessment!.questions.length}",
                    style: GoogleFonts.lexend(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: _textWhite)),
              ]),
            ),
          ]),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.h),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _cardSurface,
              valueColor: AlwaysStoppedAnimation(_primary),
              minHeight: 6.h,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionBriefing() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _bgDeep,
                border: Border.all(color: _primary.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 40)
                ],
              ),
              child: Icon(PhosphorIcons.sword, size: 48.sp, color: _primary),
            ),
            SizedBox(height: 40.h),
            Text("PREPARADO?",
                style: GoogleFonts.lexend(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w900,
                    color: _textWhite)),
            SizedBox(height: 16.h),
            Text(_assessment!.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: _primary)),
            SizedBox(height: 16.h),
            Text("Mantenha o foco. O sistema monitora saídas do aplicativo.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14.sp, color: _textGrey)),
            SizedBox(height: 60.h),
            GestureDetector(
              onTap: _handleStartUi,
              child: Container(
                width: double.infinity,
                height: 56.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF8257E5), Color(0xFF996DFF)]),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(color: _primary.withOpacity(0.4), blurRadius: 20)
                  ],
                ),
                alignment: Alignment.center,
                child: Text("INICIAR ATIVIDADE",
                    style: GoogleFonts.lexend(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamerQuestionUI() {
    final question = _assessment!.questions[_currentQuestionIndex];
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10.h),
          Text(question.questionText,
              style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  height: 1.6,
                  color: _textWhite,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 32.h),
          ...List.generate(question.options.length, (index) {
            final isSelected = _selectedAnswers[_currentQuestionIndex] == index;
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: GestureDetector(
                onTap: () => setState(
                    () => _selectedAnswers[_currentQuestionIndex] = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? _primary.withOpacity(0.15) : _cardSurface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                        color: isSelected
                            ? _primary
                            : Colors.white.withOpacity(0.05),
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32.w,
                      height: 32.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: isSelected ? _primary : Colors.black26,
                          borderRadius: BorderRadius.circular(8.r)),
                      child: isSelected
                          ? Icon(PhosphorIcons.check,
                              color: Colors.white, size: 18.sp)
                          : Text(String.fromCharCode(65 + index),
                              style: GoogleFonts.lexend(
                                  color: _textGrey,
                                  fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                        child: Text(question.options[index],
                            style: GoogleFonts.inter(
                                fontSize: 15.sp,
                                color: isSelected ? _textWhite : _textGrey))),
                  ]),
                ),
              ),
            );
          }),
          SizedBox(height: 80.h),
        ],
      ),
    );
  }

  Widget _buildFooterControls() {
    final isLast = _currentQuestionIndex == _assessment!.questions.length - 1;
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
          color: _bgDeep,
          border:
              Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (_currentQuestionIndex > 0)
          TextButton(
              onPressed: _prevQuestion,
              style: TextButton.styleFrom(foregroundColor: _textGrey),
              child: Row(children: [
                Icon(PhosphorIcons.arrow_left, size: 18.sp),
                SizedBox(width: 8.w),
                Text("ANTERIOR",
                    style: GoogleFonts.lexend(fontWeight: FontWeight.bold))
              ]))
        else
          Spacer(),
        GestureDetector(
          onTap: _isSubmitting ? null : _nextQuestion,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: isLast
                  ? LinearGradient(colors: [_accent, Color(0xFF00B34D)])
                  : LinearGradient(
                      colors: [Color(0xFF8257E5), Color(0xFF996DFF)]),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(isLast ? "FINALIZAR" : "PRÓXIMA",
                    style: GoogleFonts.lexend(
                        color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _buildStatusScreen(
      String title, String msg, IconData icon, Color color) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 64.sp, color: color),
          SizedBox(height: 24.h),
          Text(title,
              style: GoogleFonts.lexend(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: _textWhite)),
          SizedBox(height: 16.h),
          Text(msg, style: GoogleFonts.inter(color: _textGrey)),
          SizedBox(height: 48.h),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
                foregroundColor: _textWhite,
                side: BorderSide(color: Colors.white24)),
            child: Text("VOLTAR",
                style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
          )
        ]),
      ),
    );
  }
}
