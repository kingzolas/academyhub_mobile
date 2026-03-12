import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NewRegistrationPopup extends StatefulWidget {
  final String candidateName;
  final String typeLabel; // Ex: "Maior de Idade" ou "Menor de Idade"
  final VoidCallback onAnimationFinished;

  const NewRegistrationPopup({
    super.key,
    required this.candidateName,
    required this.typeLabel,
    required this.onAnimationFinished,
  });

  @override
  State<NewRegistrationPopup> createState() => _NewRegistrationPopupState();
}

class _NewRegistrationPopupState extends State<NewRegistrationPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0), // Entra da direita
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // Efeito de "pulo" suave ao entrar
    ));

    _controller.forward();

    // Fecha automaticamente após 6 segundos
    _timer = Timer(const Duration(seconds: 6), () {
      if (mounted) _controller.reverse();
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onAnimationFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [POSICIONAMENTO] Canto inferior direito
    return Positioned(
      bottom: 90.h, // Altura para ficar próximo ao FAB/Assistente
      right: 30.w,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400.w,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12.r),
              // Borda lateral laranja/indigo para indicar "Web/Solicitação"
              border: Border(
                  left: BorderSide(color: Colors.indigoAccent, width: 4.w)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PhosphorIcons.globe_hemisphere_west_fill,
                      color: Colors.indigoAccent, size: 26.sp),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nova Solicitação Web!',
                        style: GoogleFonts.sairaCondensed(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade400,
                            fontSize: 14.sp,
                          ),
                          children: [
                            TextSpan(
                                text: widget.candidateName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            TextSpan(text: '\n${widget.typeLabel}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () {
                    _timer?.cancel();
                    _controller.reverse();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
