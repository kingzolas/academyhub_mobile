import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ApprovalSuccessPopup extends StatefulWidget {
  final String studentName;
  final VoidCallback onAnimationFinished;

  const ApprovalSuccessPopup({
    super.key,
    required this.studentName,
    required this.onAnimationFinished,
  });

  @override
  State<ApprovalSuccessPopup> createState() => _ApprovalSuccessPopupState();
}

class _ApprovalSuccessPopupState extends State<ApprovalSuccessPopup>
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

    // Fecha automaticamente após 4 segundos
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
            width: 420.w,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark Theme padrão
              borderRadius: BorderRadius.circular(12.r),
              border: Border(
                  left: BorderSide(color: Colors.greenAccent, width: 4.w)),
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
                        'Matrícula Aprovada!',
                        style: GoogleFonts.sairaCondensed(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20.sp,
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
                            const TextSpan(text: 'O aluno '),
                            TextSpan(
                                text: widget.studentName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const TextSpan(
                                text: ' foi matriculado com sucesso.'),
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
