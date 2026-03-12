import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isScreenReady = false; // Controle da tela de splash pré-login

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicia o cache da imagem apenas na primeira construção
    if (!_isScreenReady) {
      _preloadAssets();
    }
  }

  // --- LÓGICA DE PRÉ-CARREGAMENTO ---
  Future<void> _preloadAssets() async {
    try {
      // Faz o cache da imagem pesada antes de exibir a tela
      await precacheImage(
          const AssetImage("lib/assets/imagem_de_login.jpg"), context);
      // Um delay mínimo para garantir uma transição suave e o carregamento das fontes na web
      await Future.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      debugPrint("Erro ao carregar imagem de login: $e");
    }

    if (mounted) {
      setState(() {
        _isScreenReady = true;
      });
    }
  }

  // --- LÓGICA DE LOGIN ---
  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    // Novo Dialog de Loading Nativo e Limpo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFFDDA0DD),
                strokeWidth: 3,
              ),
              SizedBox(height: 16.h),
              Text(
                "Validando...",
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await Provider.of<AuthProvider>(context, listen: false).login(
          _identifierController.text.trim(), _passwordController.text, context);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (error) {
      if (mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(20.r),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFFDDA0DD); // Lilás claro

    // Exibe tela de carregamento suave enquanto prepara os assets
    if (!_isScreenReady) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'lib/assets/logo_chapeu_academy.svg',
                width: 70.w,
                height: 70.h,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: 150.w,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey[200],
                  color: themeColor,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // Fundo aplicado com a mesma cor do Card Inferior para evitar o "vazio" no overscroll
      backgroundColor: const Color(0xFFF4F7FB),
      body: SingleChildScrollView(
        // ClampingScrollPhysics impede que o usuário puxe a tela além do limite mostrando as bordas
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // Imagem de topo
            Container(
              height: 350.h,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("lib/assets/imagem_de_login.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Container Branco de conteúdo refatorado
            Transform.translate(
              offset: Offset(0, -40.h), // Faz o card sobrepor a imagem
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.r),
                    topRight: Radius.circular(40.r),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      SvgPicture.asset(
                        'lib/assets/logo_chapeu_academy.svg',
                        width: 40.w,
                        height: 40.h,
                      ),
                      SizedBox(height: 16.h),

                      // Textos de Boas Vindas
                      Text(
                        'Bem vindo!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF1E1E1E),
                          fontSize: 22.sp,
                          fontFamily: 'GR Milesons Three',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        width: 250.sp,
                        child: Text(
                          'Acesse sua conta e continue sua jornada educacional.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFA6A8A9),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // Campos de Texto Funcionais
                      CustomTextFormField(
                        controller: _identifierController,
                        hintText: "Username/Email",
                        icon: PhosphorIcons.envelope_fill,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, insira seu email ou usuário.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),

                      CustomTextFormField(
                        controller: _passwordController,
                        hintText: "Senha",
                        icon: PhosphorIcons.lock_key_fill,
                        isPassword: true,
                        obscureText: !_isPasswordVisible,
                        onToggleVisibility: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira sua senha.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),

                      // Lembrar-me
                      Row(
                        children: [
                          SizedBox(
                            height: 24.h,
                            width: 24.w,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: themeColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.r)),
                              side: const BorderSide(
                                color: Color(0xFFAFAFAF),
                                width: 1.5,
                              ),
                              onChanged: (val) =>
                                  setState(() => _rememberMe = val!),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            "Lembrar-me",
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFA6A8A9),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 32.h),

                      // Botão Login
                      SizedBox(
                        width: double.infinity,
                        height: 40.h,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.2),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 24.h,
                                  width: 24.h,
                                  child: CircularProgressIndicator(
                                    color: themeColor,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 23.sp,
                                    fontFamily: 'GR Milesons Three',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 40.h),

                      // Botão Google
                      InkWell(
                        onTap: () {
                          // Lógica Google Login
                        },
                        child: Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: ShapeDecoration(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7.r),
                            ),
                            shadows: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'lib/assets/google-icon-logo-svgrepo-com.svg',
                              width: 24.w,
                              height: 24.h,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SUB-WIDGETS ---

class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;
  final IconData? icon;

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.hintText,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleVisibility,
    this.validator,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const fillColor = Colors.white;
    const hintColor = Color(0xFFA6A8A9);
    const textColor = Color(0xFF333333);

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(6.r),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 8,
            offset: Offset(0, 0),
            spreadRadius: -2,
          )
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.inter(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        decoration: InputDecoration(
          prefixIcon:
              icon != null ? Icon(icon, color: hintColor, size: 25.sp) : null,
          prefixIconConstraints: BoxConstraints(minWidth: 40.w),
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: hintColor,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    obscureText ? PhosphorIcons.eye_slash : PhosphorIcons.eye,
                    color: hintColor,
                    size: 20.sp,
                  ),
                )
              : null,
        ),
        validator: validator,
      ),
    );
  }
}
