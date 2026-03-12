// Salve como: lib/widgets/payment_received_popup.dart

import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentReceivedPopup extends StatefulWidget {
  final String title;
  final String description;

  const PaymentReceivedPopup({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  State<PaymentReceivedPopup> createState() => _PaymentReceivedPopupState();
}

class _PaymentReceivedPopupState extends State<PaymentReceivedPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // [CORREÇÃO] Alinhado com a animação do NewUserPopup (400ms)
      duration: const Duration(milliseconds: 1000),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      // O Container já tem a largura correta (417.w),
      // assim como o NewUserPopup.
      child: Container(
        width: 417.w,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // Mesmo estilo preto
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
            // Ícone de sucesso (Pagamento)
            Icon(PhosphorIcons.check_circle_fill,
                color: Colors.greenAccent,
                size: 30.sp), // Tamanho idêntico ao NewUserPopup
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title, // Título dinâmico
                    style: GoogleFonts.sairaCondensed(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp, // Fonte idêntica
                    ),
                  ),
                  Text(
                    widget.description, // Descrição dinâmica
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade300,
                      fontSize: 14.sp, // Fonte idêntica
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            // Botão de fechar discreto (idêntico ao NewUserPopup)
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
