import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class TransactionSuccessPopup extends StatefulWidget {
  final String title;
  final String amount; // Ex: "R$ 1.200,00"
  final VoidCallback onAnimationFinished;

  const TransactionSuccessPopup({
    super.key,
    required this.title,
    required this.amount,
    required this.onAnimationFinished,
  });

  @override
  State<TransactionSuccessPopup> createState() =>
      _TransactionSuccessPopupState();
}

class _TransactionSuccessPopupState extends State<TransactionSuccessPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(
          milliseconds: 600), // Um pouco mais lento para ser elegante
      reverseDuration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart, // Curva bem suave
    ));

    _controller.forward();

    // Fecha após 4 segundos (transações são leituras rápidas)
    _timer = Timer(const Duration(seconds: 4), () {
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
    return Positioned(
      bottom: 90.h,
      right: 30.w,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 380.w,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16.r),
              // Borda verde para indicar sucesso financeiro
              border: Border(
                  left: BorderSide(color: Colors.greenAccent, width: 4.w)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
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
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PhosphorIcons.check_circle_fill,
                      color: Colors.greenAccent, size: 28.sp),
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
                      SizedBox(height: 2.h),
                      Text(
                        "Valor registrado: ${widget.amount}",
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                          fontSize: 14.sp,
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
