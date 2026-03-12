import 'package:academyhub_mobile/services/auth_student_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class StudentExamLoginScreen extends StatefulWidget {
  final String assessmentId;

  const StudentExamLoginScreen({super.key, required this.assessmentId});

  @override
  State<StudentExamLoginScreen> createState() => _StudentExamLoginScreenState();
}

class _StudentExamLoginScreenState extends State<StudentExamLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _enrollmentController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthStudentService _authService = AuthStudentService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  // [NOVO] Controle de Estado para Prova já realizada
  bool _examAlreadyCompleted = false;

  // Tema Dark (Slate & Amber/Purple)
  final Color _bgDark = const Color(0xFF121214);
  final Color _cardDark = const Color(0xFF202024);
  final Color _primary = const Color(0xFF8257E5);
  final Color _textWhite = const Color(0xFFE1E1E6);
  final Color _textGrey = const Color(0xFFA8A8B3);
  final Color _success = const Color(0xFF04D361); // Verde Rocketseat

  Future<void> _loginAndStart() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(
        _enrollmentController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Se passou do login, tenta ir para a execução
      // (Supomos que a verificação de "já fez" ocorra aqui ou na próxima tela)
      // Se a verificação ocorrer aqui no login (ex: validação prévia):

      context.go('/aluno/prova/${widget.assessmentId}/execucao');
    } catch (e) {
      final errorString = e.toString();

      // [LÓGICA DE DETECÇÃO]
      // Verifica se o erro contém a frase específica do Backend
      if (errorString.contains("Você já realizou esta atividade")) {
        setState(() {
          _examAlreadyCompleted = true; // Ativa a tela de sucesso/aviso
          _isLoading = false;
        });
      } else {
        // Erro comum (senha errada, internet, etc)
        setState(() {
          _errorMessage = errorString.replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone de destaque (Logo)
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: _cardDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child:
                    Icon(PhosphorIcons.student, size: 40.sp, color: _primary),
              ),

              SizedBox(height: 32.h),

              // [CONDICIONAL]
              // Se já fez a prova, mostra tela informativa. Se não, mostra o Login.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _examAlreadyCompleted
                    ? _buildAlreadyCompletedView()
                    : _buildLoginForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TELA INFORMATIVA: PROVA JÁ REALIZADA ---
  Widget _buildAlreadyCompletedView() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 400.w),
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: _success.withOpacity(0.3)), // Borda Verde
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 30, offset: Offset(0, 10))
          ]),
      child: Column(
        children: [
          Icon(PhosphorIcons.check_circle, color: _success, size: 64.sp),
          SizedBox(height: 24.h),
          Text(
            "Atividade Concluída",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: _textWhite,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            "Identificamos que você já enviou suas respostas para esta avaliação anteriormente.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              color: _textGrey,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton.icon(
              onPressed: () {
                // Volta para home ou para dashboard
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/'); // Ou rota inicial
                }
              },
              icon: Icon(PhosphorIcons.arrow_left, size: 20.sp),
              label: Text("Voltar ao Início",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cardDark,
                foregroundColor: _textWhite,
                side: BorderSide(color: _textGrey.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- FORMULÁRIO DE LOGIN PADRÃO ---
  Widget _buildLoginForm() {
    return Column(
      children: [
        Text(
          "Bem-vindo(a)!",
          style: GoogleFonts.inter(
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: _textWhite,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          "Use sua matrícula e senha para acessar a atividade.",
          textAlign: TextAlign.center,
          style:
              GoogleFonts.inter(fontSize: 14.sp, color: _textGrey, height: 1.5),
        ),
        SizedBox(height: 40.h),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 400.w),
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 30,
                    offset: Offset(0, 10))
              ]),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 20.h),
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                        color: const Color(0xFFCC2937).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                            color: const Color(0xFFCC2937).withOpacity(0.3))),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.warning_circle,
                            color: const Color(0xFFCC2937), size: 20.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                            child: Text(_errorMessage!,
                                style: GoogleFonts.inter(
                                    color: const Color(0xFFCC2937),
                                    fontSize: 13.sp))),
                      ],
                    ),
                  ),
                _buildLabel("Matrícula"),
                TextFormField(
                  controller: _enrollmentController,
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  style: GoogleFonts.robotoMono(
                      fontSize: 16.sp, color: _textWhite),
                  cursorColor: _primary,
                  decoration: _inputDecoration(
                      "Ex: 68FA1AFE", PhosphorIcons.identification_card),
                ),
                SizedBox(height: 20.h),
                _buildLabel("Senha"),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  style: GoogleFonts.robotoMono(
                      fontSize: 16.sp, color: _textWhite),
                  cursorColor: _primary,
                  decoration: _inputDecoration(
                          "Senha de acesso", PhosphorIcons.lock_key)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? PhosphorIcons.eye
                            : PhosphorIcons.eye_slash,
                        color: _textGrey,
                        size: 20.sp,
                      ),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginAndStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                      elevation: 0,
                      disabledBackgroundColor: _primary.withOpacity(0.5),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20.h,
                            width: 20.h,
                            child: const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            "ACESSAR",
                            style: GoogleFonts.inter(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS AUXILIARES (Input, Label) ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, left: 4.w),
      child: Text(text,
          style: GoogleFonts.inter(
              color: _textGrey, fontSize: 13.sp, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.inter(color: _textGrey.withOpacity(0.4), fontSize: 14.sp),
      prefixIcon: Icon(icon, size: 20.sp, color: _textGrey),
      filled: true,
      fillColor: const Color(0xFF121214),
      contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFFCC2937), width: 1.5),
      ),
    );
  }
}
