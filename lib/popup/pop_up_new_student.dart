import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NewStudentPopup extends StatefulWidget {
  final String studentName;
  final String creatorName;

  const NewStudentPopup({
    super.key,
    required this.studentName,
    required this.creatorName,
  });

  @override
  State<NewStudentPopup> createState() => _NewStudentPopupState();
}

class _NewStudentPopupState extends State<NewStudentPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0), // Começa fora da tela, à direita
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Inicia a animação de entrada
    _controller.forward();
  }

  // O NotificationService agora controla quando fechar, não o timer
  // O _timer foi removido.

  // O NotificationService chamará _close()
  void _close() {
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [CORREÇÃO] Removemos o AlertDialog. O widget agora é o SlideTransition.
    return SlideTransition(
      position: _offsetAnimation,
      child: Container(
        width: 417.w,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.user_plus_fill,
                color: Colors.greenAccent, size: 30.sp),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Novo Aluno Cadastrado!',
                    style: GoogleFonts.sairaCondensed(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                  ),
                  Text(
                    '${widget.studentName} foi adicionado(a) por ${widget.creatorName}.',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade300,
                      fontSize: 14.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2, // Permite quebra de linha
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                // Ao clicar no X, fecha o SnackBar
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ],
        ),
      ),
    );
  }
}
