import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionStatusPopup extends StatefulWidget {
  final String title;
  final String message;
  final bool isError;
  final VoidCallback onAnimationFinished;

  const ActionStatusPopup({
    super.key,
    required this.title,
    required this.message,
    this.isError = false,
    required this.onAnimationFinished,
  });

  @override
  State<ActionStatusPopup> createState() => _ActionStatusPopupState();
}

class _ActionStatusPopupState extends State<ActionStatusPopup>
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
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    // Tempo de exibição (maior se for erro para dar tempo de ler)
    final duration = widget.isError
        ? const Duration(seconds: 6)
        : const Duration(seconds: 4);

    _timer = Timer(duration, () {
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
    final colorTheme = widget.isError ? Colors.redAccent : Colors.greenAccent;
    final icon = widget.isError
        ? PhosphorIcons.warning_circle_fill
        : PhosphorIcons.check_circle_fill;

    // [POSICIONAMENTO] Canto inferior direito, sobrepondo o que estiver lá
    return Positioned(
      bottom: 90.h,
      right: 30.w,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 420.w, // Um pouco mais largo para mensagens de erro
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12.r),
              border: Border(left: BorderSide(color: colorTheme, width: 4.w)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: colorTheme.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colorTheme, size: 26.sp),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.sairaCondensed(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        widget.message,
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade300,
                          fontSize: 14.sp,
                        ),
                        maxLines: 3, // Permite até 3 linhas para erros longos
                        overflow: TextOverflow.ellipsis,
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
