import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateAvailablePopup extends StatefulWidget {
  final String newVersion;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  const UpdateAvailablePopup({
    super.key,
    required this.newVersion,
    required this.onUpdate,
    required this.onDismiss,
  });

  @override
  State<UpdateAvailablePopup> createState() => _UpdateAvailablePopupState();
}

class _UpdateAvailablePopupState extends State<UpdateAvailablePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0), // Vem da direita
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  Future<void> _close(VoidCallback action) async {
    await _controller.reverse();
    action();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mantendo seu posicionamento original
    return Positioned(
      bottom: 50.h,
      right: 30.w,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400.w,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Seu fundo dark
              borderRadius: BorderRadius.circular(12.r),
              border: Border(
                left: BorderSide(
                    color: Colors.greenAccent, width: 4.w), // Verde para Update
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(PhosphorIcons.download_simple_bold,
                          color: Colors.greenAccent, size: 26.sp),
                    ),
                    SizedBox(width: 15.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Nova Versão Disponível!',
                            style: GoogleFonts.sairaCondensed(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            "A versão ${widget.newVersion} está pronta para instalar.",
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white54, size: 20),
                      onPressed: () => _close(widget.onDismiss),
                    ),
                  ],
                ),
                SizedBox(height: 15.h),
                // Botões de Ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _close(widget.onDismiss),
                      child: Text(
                        "Depois",
                        style: GoogleFonts.leagueSpartan(
                            color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    ElevatedButton(
                      onPressed: widget.onUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        "Atualizar Agora",
                        style: GoogleFonts.leagueSpartan(
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
