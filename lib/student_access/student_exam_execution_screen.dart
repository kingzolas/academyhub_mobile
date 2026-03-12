import 'dart:async';
// import 'dart:html' as html; // Descomente se precisar de APIs específicas do DOM futuramente
import 'package:academyhub_mobile/model/assessment_models.dart';
import 'package:academyhub_mobile/services/assessment_attempt_service.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para capturar teclas
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

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
  final FocusNode _keyboardFocusNode =
      FocusNode(); // Necessário para ouvir teclas na Web

  Assessment? _assessment;
  String? _attemptId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  // Estado: Prova já realizada
  bool _isAlreadyCompleted = false;

  // Estado: UI iniciada
  bool _hasStartedExamUI = false;

  int _currentQuestionIndex = 0;
  Map<int, int> _selectedAnswers = {};

  // --- TELEMETRIA ---
  DateTime? _examStartTime;
  DateTime? _questionStartTime;
  Map<int, int> _timeSpentPerQuestion = {};

  int _focusLostCount = 0;
  int _focusLostTimeMs = 0;
  DateTime? _focusLostTimestamp;
  int _screenshotCount = 0;
  int _resizeCount = 0;

  // Cores
  final Color _bgScreen = const Color(0xFF020617);
  final Color _bgCard = const Color(0xFF0F172A);
  final Color _borderColor = const Color(0xFF1E293B);
  final Color _accentColor = const Color(0xFFF59E0B);
  final Color _textPrimary = const Color(0xFFE2E8F0);
  final Color _textSecondary = const Color(0xFF94A3B8);
  final Color _successColor = const Color(0xFF04D361);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExamData();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 1. DETECÇÃO DE MUDANÇA DE ABA/JANELA (Funciona no Chrome)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasStartedExamUI) return;

    // Na Web: 'inactive' ou 'paused' geralmente significa que o usuário trocou de aba
    // ou minimizou o navegador.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _focusLostCount++;
      _focusLostTimestamp = DateTime.now();
      // Opcional: Você pode "borrar" a tela aqui se quiser ser mais agressivo
    } else if (state == AppLifecycleState.resumed) {
      if (_focusLostTimestamp != null) {
        final timeAway =
            DateTime.now().difference(_focusLostTimestamp!).inMilliseconds;
        _focusLostTimeMs += timeAway;
        _focusLostTimestamp = null;

        _showSecurityWarning("⚠️ Atenção: Saída de aba registrada.");

        // Garante que o foco volte para capturar teclas
        FocusScope.of(context).requestFocus(_keyboardFocusNode);
      }
    }
  }

  // 2. DETECÇÃO DE REDIMENSIONAMENTO (Split Screen / DevTools)
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_hasStartedExamUI) {
      // Se a janela mudou de tamanho (ex: abriu console ou dividiu tela)
      _resizeCount++;
    }
  }

  // 3. DETECÇÃO DE TECLA (PrintScreen)
  void _handleKeyEvent(RawKeyEvent event) {
    if (!_hasStartedExamUI) return;

    if (event is RawKeyUpEvent) {
      // Detecta a tecla "Print Screen" física
      if (event.logicalKey == LogicalKeyboardKey.printScreen) {
        setState(() {
          _screenshotCount++;
        });
        _showSecurityWarning(
            "⚠️ Tecla PrintScreen detectada. Ação registrada.");
      }

      // Tentativa de detectar atalhos de cópia (Ctrl+C / Cmd+C)
      /* bool isControlPressed = event.isControlPressed || event.isMetaPressed; // Meta = Cmd no Mac
      if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
         _showSecurityWarning("Cópia de conteúdo não permitida.");
      }
      */
    }
  }

  void _showSecurityWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(PhosphorIcons.warning_octagon, color: Colors.white, size: 20.sp),
        SizedBox(width: 10.w),
        Expanded(
            child: Text(message, style: GoogleFonts.roboto(fontSize: 14.sp))),
      ]),
      backgroundColor: Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      width: 400, // Limita largura no desktop para ficar bonito
    ));
  }

  // ... (Lógica de Tempo e Load Data permanecem iguais) ...
  void _trackQuestionTime(int oldIndex) {
    if (_questionStartTime != null) {
      final timeSpent =
          DateTime.now().difference(_questionStartTime!).inMilliseconds;
      _timeSpentPerQuestion[oldIndex] =
          (_timeSpentPerQuestion[oldIndex] ?? 0) + timeSpent;
    }
    _questionStartTime = DateTime.now();
  }

  Future<void> _loadExamData() async {
    try {
      final result = await _attemptService.startAttempt(widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _attemptId = result['attemptId'];
        _assessment = result['assessment'];
        _isLoading = false;
        _examStartTime = DateTime.now();
      });
      // Garante foco para capturar teclado assim que carrega
      Future.delayed(Duration.zero,
          () => FocusScope.of(context).requestFocus(_keyboardFocusNode));
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains("Você já realizou esta atividade")) {
        setState(() {
          _isAlreadyCompleted = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = errorMsg.replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _handleStartUi() {
    setState(() {
      _hasStartedExamUI = true;
      _questionStartTime = DateTime.now();
    });
    // Foca no listener de teclado
    FocusScope.of(context).requestFocus(_keyboardFocusNode);
  }

  Future<void> _submitExam() async {
    _trackQuestionTime(_currentQuestionIndex);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text("Finalizar?",
            style: GoogleFonts.merriweather(
                color: _textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
            "Você respondeu ${_selectedAnswers.length} de ${_assessment!.questions.length} questões.",
            style: GoogleFonts.roboto(color: _textSecondary, fontSize: 16.sp)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Revisar", style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Enviar Tudo",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    final totalTime = DateTime.now().difference(_examStartTime!).inMilliseconds;
    final List<AnswerDetail> answersPayload = [];

    for (int i = 0; i < _assessment!.questions.length; i++) {
      if (_selectedAnswers.containsKey(i)) {
        answersPayload.add(AnswerDetail(
            questionIndex: i,
            selectedOptionIndex: _selectedAnswers[i]!,
            timeSpentMs: _timeSpentPerQuestion[i] ?? 0,
            switchedAppCount: 0));
      }
    }

    final attemptData = AssessmentAttempt(
        answers: answersPayload,
        telemetry: Telemetry(
            totalTimeMs: totalTime,
            focusLostCount: _focusLostCount,
            focusLostTimeMs: _focusLostTimeMs,
            screenshotCount: _screenshotCount,
            resizeCount: _resizeCount,
            deviceInfo:
                "Web Browser")); // Info hardcoded ou use device_info_plus

    try {
      final finalResult =
          await _attemptService.submitAttempt(_attemptId!, attemptData);
      if (!mounted) return;
      context.go('/aluno/prova/${widget.assessmentId}/resultado',
          extra: {'assessment': _assessment, 'attempt': finalResult});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
      setState(() => _isSubmitting = false);
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _assessment!.questions.length - 1) {
      _trackQuestionTime(_currentQuestionIndex);
      setState(() => _currentQuestionIndex++);
    } else {
      _submitExam();
    }
  }

  void _prevQuestion() {
    if (_currentQuestionIndex > 0) {
      _trackQuestionTime(_currentQuestionIndex);
      setState(() => _currentQuestionIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading
    if (_isLoading) {
      return Scaffold(
          backgroundColor: _bgScreen,
          body: Center(child: CircularProgressIndicator(color: _accentColor)));
    }

    // Já Feito
    if (_isAlreadyCompleted) {
      return Scaffold(
          backgroundColor: _bgScreen,
          body: Center(child: _buildCompletedView()));
    }

    // Erro
    if (_error != null) {
      return Scaffold(
        backgroundColor: _bgScreen,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(PhosphorIcons.warning_octagon,
                size: 50.sp, color: Colors.redAccent),
            SizedBox(height: 20.h),
            Text("Erro ao carregar",
                style: GoogleFonts.merriweather(
                    color: _textPrimary, fontSize: 20.sp)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(color: _textSecondary)),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(backgroundColor: _borderColor),
                child: const Text("Voltar"))
          ]),
        ),
      );
    }

    final progress = _hasStartedExamUI
        ? (_currentQuestionIndex + 1) / _assessment!.questions.length
        : 0.0;

    // [WIDGET PRINCIPAL] Envolvido em RawKeyboardListener
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode, // Foco obrigatório para ouvir teclas
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: _bgScreen,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                margin: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  children: [
                    // --- HEADER FIXO ---
                    Padding(
                      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(PhosphorIcons.scales,
                                        color: _accentColor, size: 20.sp),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        _assessment!.title,
                                        style: GoogleFonts.merriweather(
                                            color: _accentColor,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Text("Simulado Acadêmico",
                                    style: GoogleFonts.roboto(
                                        color: _textSecondary,
                                        fontSize: 12.sp)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("QUESTÃO",
                                  style: GoogleFonts.roboto(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                      color: _textSecondary,
                                      letterSpacing: 1.5)),
                              RichText(
                                text: TextSpan(children: [
                                  TextSpan(
                                      text: "${_currentQuestionIndex + 1}",
                                      style: GoogleFonts.roboto(
                                          color: _textPrimary,
                                          fontSize: 24.sp,
                                          fontWeight: FontWeight.bold)),
                                  TextSpan(
                                      text: "/${_assessment!.questions.length}",
                                      style: GoogleFonts.roboto(
                                          color: _textSecondary,
                                          fontSize: 16.sp)),
                                ]),
                              )
                            ],
                          )
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),
                    LinearProgressIndicator(
                        value: progress,
                        backgroundColor: _borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                        minHeight: 2.h),

                    // --- CONTEÚDO ---
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: _hasStartedExamUI
                            ? _buildQuestionContent()
                            : _buildStartContent(),
                      ),
                    ),

                    // --- BOTTOM BAR ---
                    if (_hasStartedExamUI)
                      Container(
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                            color: _bgCard,
                            border:
                                Border(top: BorderSide(color: _borderColor))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentQuestionIndex > 0)
                              TextButton.icon(
                                onPressed: _prevQuestion,
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16.w, vertical: 12.h)),
                                icon: Icon(PhosphorIcons.caret_left,
                                    color: _textSecondary, size: 16.sp),
                                label: Text("Anterior",
                                    style: GoogleFonts.roboto(
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14.sp)),
                              )
                            else
                              const SizedBox(width: 80),
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _nextQuestion,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24.w, vertical: 12.h),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(6.r))),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 16.w,
                                      height: 16.w,
                                      child: const CircularProgressIndicator(
                                          color: Colors.black, strokeWidth: 2))
                                  : Row(children: [
                                      Text(
                                          _currentQuestionIndex ==
                                                  _assessment!
                                                          .questions.length -
                                                      1
                                              ? "Finalizar"
                                              : "Próxima",
                                          style: GoogleFonts.roboto(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.sp)),
                                      SizedBox(width: 8.w),
                                      Icon(PhosphorIcons.caret_right,
                                          size: 14.sp)
                                    ]),
                            ),
                          ],
                        ),
                      )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ... (WIDGETS _buildCompletedView, _buildStartContent, _buildQuestionContent, _buildOptionCard MANTIDOS IDÊNTICOS) ...
  // Vou replicar apenas o _buildCompletedView para garantir que você tenha o bloco

  Widget _buildCompletedView() {
    return Container(
      margin: EdgeInsets.all(24.w),
      constraints: const BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: _successColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10))
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.check_circle, color: _successColor, size: 64.sp),
          SizedBox(height: 24.h),
          Text("Atividade Concluída",
              textAlign: TextAlign.center,
              style: GoogleFonts.merriweather(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          SizedBox(height: 12.h),
          Text(
              "Identificamos que você já enviou suas respostas para esta avaliação anteriormente.",
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                  fontSize: 15.sp, color: _textSecondary, height: 1.5)),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: () {
                if (context.canPop())
                  context.pop();
                else
                  context.go('/');
              },
              icon: Icon(PhosphorIcons.arrow_left, size: 20.sp),
              label: Text("Voltar ao Início",
                  style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _bgCard,
                  foregroundColor: _textPrimary,
                  side: BorderSide(color: _borderColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                  elevation: 0),
            ),
          )
        ],
      ),
    );
  }

  // Replicar os outros widgets aqui se necessário, eles não mudam a lógica.
  Widget _buildStartContent() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              margin: EdgeInsets.only(bottom: 24.h),
              decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _accentColor.withOpacity(0.3))),
              child: Icon(PhosphorIcons.bank, color: _accentColor, size: 32.sp),
            ),
            Text("Avaliação Dogmática",
                style: GoogleFonts.merriweather(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                    style: GoogleFonts.roboto(
                        color: _textSecondary, fontSize: 16.sp, height: 1.5),
                    children: [
                      const TextSpan(text: "Este teste contém "),
                      TextSpan(
                          text: "${_assessment!.questions.length} questões",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const TextSpan(text: " de nível acadêmico."),
                    ]),
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: _handleStartUi,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 40.w, vertical: 16.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r))),
              child: Text("Iniciar Simulado",
                  style: GoogleFonts.roboto(
                      fontSize: 18.sp, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContent() {
    final question = _assessment!.questions[_currentQuestionIndex];
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      physics: const BouncingScrollPhysics(),
      child: Column(
        key: ValueKey<int>(_currentQuestionIndex),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.category != null)
            Container(
              margin: EdgeInsets.only(bottom: 16.h),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                  color: _borderColor,
                  borderRadius: BorderRadius.circular(4.r)),
              child: Text(question.category!.toUpperCase(),
                  style: GoogleFonts.roboto(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: _accentColor)),
            ),
          Text(question.questionText,
              style: GoogleFonts.merriweather(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  color: _textPrimary)),
          SizedBox(height: 32.h),
          ...List.generate(question.options.length, (index) {
            final isSelected = _selectedAnswers[_currentQuestionIndex] == index;
            return _buildOptionCard(index, question.options[index], isSelected);
          }),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, String text, bool isSelected) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              setState(() => _selectedAnswers[_currentQuestionIndex] = index),
          borderRadius: BorderRadius.circular(6.r),
          hoverColor: _borderColor,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accentColor.withOpacity(0.15)
                  : _borderColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                  color: isSelected ? _accentColor : Colors.transparent,
                  width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28.w,
                  height: 28.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected ? _accentColor : _textSecondary,
                          width: 2),
                      color: isSelected ? _accentColor : Colors.transparent),
                  child: Text(String.fromCharCode(65 + index),
                      style: GoogleFonts.roboto(
                          color: isSelected ? Colors.white : _textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp)),
                ),
                SizedBox(width: 16.w),
                Expanded(
                    child: Text(text,
                        style: GoogleFonts.roboto(
                            fontSize: 15.sp,
                            height: 1.4,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : _textPrimary.withOpacity(0.9)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
