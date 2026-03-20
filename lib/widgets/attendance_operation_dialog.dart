import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

Future<bool?> showAttendanceOperationDialog({
  required BuildContext context,
  required Future<void> Function() operation,
  String loadingTitle = 'Salvando Chamada',
  String loadingMessage = 'Registrando a presença dos alunos...',
  String successTitle = 'Chamada Salva!',
  String successMessage = 'A frequência da turma foi registrada com sucesso.',
  String? loadingDetail,
  Duration minimumLoadingDuration = const Duration(milliseconds: 900),
  Duration successVisibleDuration = const Duration(milliseconds: 1500),
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (_) => _AttendanceOperationDialog(
      operation: operation,
      loadingTitle: loadingTitle,
      loadingMessage: loadingMessage,
      loadingDetail: loadingDetail,
      successTitle: successTitle,
      successMessage: successMessage,
      minimumLoadingDuration: minimumLoadingDuration,
      successVisibleDuration: successVisibleDuration,
    ),
  );
}

class _AttendanceOperationDialog extends StatefulWidget {
  final Future<void> Function() operation;
  final String loadingTitle;
  final String loadingMessage;
  final String? loadingDetail;
  final String successTitle;
  final String successMessage;
  final Duration minimumLoadingDuration;
  final Duration successVisibleDuration;

  const _AttendanceOperationDialog({
    required this.operation,
    required this.loadingTitle,
    required this.loadingMessage,
    required this.successTitle,
    required this.successMessage,
    required this.minimumLoadingDuration,
    required this.successVisibleDuration,
    this.loadingDetail,
  });

  @override
  State<_AttendanceOperationDialog> createState() =>
      _AttendanceOperationDialogState();
}

enum _AttendanceDialogPhase { loading, success, error }

class _AttendanceOperationDialogState extends State<_AttendanceOperationDialog>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _dotsController;

  _AttendanceDialogPhase _phase = _AttendanceDialogPhase.loading;
  String? _errorMessage;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runOperation();
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  Future<void> _runOperation() async {
    final stopwatch = Stopwatch()..start();

    try {
      await widget.operation();

      final elapsed = stopwatch.elapsed;
      if (elapsed < widget.minimumLoadingDuration) {
        await Future.delayed(widget.minimumLoadingDuration - elapsed);
      }

      if (!mounted) return;
      setState(() {
        _phase = _AttendanceDialogPhase.success;
      });

      _pulseController.stop();

      _closeTimer = Timer(widget.successVisibleDuration, () {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _AttendanceDialogPhase.error;
        _errorMessage = _normalizeError(e);
      });
      _pulseController.stop();
      _dotsController.stop();
    } finally {
      stopwatch.stop();
    }
  }

  String _normalizeError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Exception', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _AttendanceDialogPalette(isDark: isDark);
    final indicatorColor = switch (_phase) {
      _AttendanceDialogPhase.loading => palette.accentBlue,
      _AttendanceDialogPhase.success => palette.accentGreen,
      _AttendanceDialogPhase.error => palette.accentRed,
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480.w, minWidth: 360.w),
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.backgroundGradient,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: _buildBody(
              key: ValueKey(_phase),
              palette: palette,
              indicatorColor: indicatorColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required Key key,
    required _AttendanceDialogPalette palette,
    required Color indicatorColor,
  }) {
    switch (_phase) {
      case _AttendanceDialogPhase.loading:
        return _LoadingBody(
          key: key,
          palette: palette,
          indicatorColor: indicatorColor,
          controller: _pulseController,
          dotsController: _dotsController,
          title: widget.loadingTitle,
          message: widget.loadingMessage,
          detail: widget.loadingDetail,
        );
      case _AttendanceDialogPhase.success:
        return _SuccessBody(
          key: key,
          palette: palette,
          indicatorColor: indicatorColor,
          title: widget.successTitle,
          message: widget.successMessage,
        );
      case _AttendanceDialogPhase.error:
        return _ErrorBody(
          key: key,
          palette: palette,
          indicatorColor: indicatorColor,
          title: 'Falha ao salvar',
          message: _errorMessage ?? 'Não foi possível concluir a operação.',
        );
    }
  }
}

class _LoadingBody extends StatelessWidget {
  final _AttendanceDialogPalette palette;
  final Color indicatorColor;
  final AnimationController controller;
  final AnimationController dotsController;
  final String title;
  final String message;
  final String? detail;

  const _LoadingBody(
      {super.key,
      required this.palette,
      required this.indicatorColor,
      required this.controller,
      required this.dotsController,
      required this.title,
      required this.message,
      this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StatusIcon(
                controller: controller,
                color: indicatorColor,
                icon: PhosphorIcons.calendar_check,
                palette: palette),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.sairaCondensed(
                          fontSize: 25.sp,
                          fontWeight: FontWeight.w700,
                          color: palette.title,
                          height: 1)),
                  SizedBox(height: 5.h),
                  Text(message,
                      style: GoogleFonts.inter(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w500,
                          color: palette.subtitle,
                          height: 1.35)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 18.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: palette.borderSoft)),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                    color: palette.iconSurface,
                    borderRadius: BorderRadius.circular(12.r)),
                child: Icon(PhosphorIcons.student,
                    size: 18.sp, color: indicatorColor),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail ?? 'Sincronizando com o sistema...',
                        style: GoogleFonts.inter(
                            fontSize: 13.2.sp,
                            fontWeight: FontWeight.w600,
                            color: palette.title)),
                    SizedBox(height: 4.h),
                    Text('Não feche esta janela enquanto a operação termina.',
                        style: GoogleFonts.inter(
                            fontSize: 11.8.sp,
                            fontWeight: FontWeight.w500,
                            color: palette.muted)),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              _AnimatedDots(controller: dotsController, color: indicatorColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuccessBody extends StatelessWidget {
  final _AttendanceDialogPalette palette;
  final Color indicatorColor;
  final String title;
  final String message;

  const _SuccessBody(
      {super.key,
      required this.palette,
      required this.indicatorColor,
      required this.title,
      required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _SuccessIcon(color: indicatorColor, palette: palette),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.sairaCondensed(
                          fontSize: 27.sp,
                          fontWeight: FontWeight.w700,
                          color: palette.title,
                          height: 1)),
                  SizedBox(height: 5.h),
                  Text(message,
                      style: GoogleFonts.inter(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w500,
                          color: palette.subtitle,
                          height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final _AttendanceDialogPalette palette;
  final Color indicatorColor;
  final String title;
  final String message;

  const _ErrorBody(
      {super.key,
      required this.palette,
      required this.indicatorColor,
      required this.title,
      required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ErrorIcon(color: indicatorColor, palette: palette),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.sairaCondensed(
                          fontSize: 27.sp,
                          fontWeight: FontWeight.w700,
                          color: palette.title,
                          height: 1)),
                  SizedBox(height: 5.h),
                  Text(message,
                      style: GoogleFonts.inter(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w500,
                          color: palette.subtitle,
                          height: 1.35)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 18.h),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: Text('Fechar',
                style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: palette.title)),
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final IconData icon;
  final _AttendanceDialogPalette palette;

  const _StatusIcon(
      {required this.controller,
      required this.color,
      required this.icon,
      required this.palette});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 0.96 + (controller.value * 0.04);
        final glow = 0.18 + (controller.value * 0.12);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 74.w,
            height: 74.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.iconSurface,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(glow),
                    blurRadius: 22,
                    spreadRadius: 2)
              ],
              border: Border.all(color: color.withOpacity(0.24), width: 1.2),
            ),
            child: Center(
              child: SizedBox(
                width: 34.w,
                height: 34.w,
                child: CircularProgressIndicator(
                    strokeWidth: 3.2,
                    color: color,
                    backgroundColor: color.withOpacity(0.12)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  final Color color;
  final _AttendanceDialogPalette palette;

  const _SuccessIcon({required this.color, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74.w,
      height: 74.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.successSurface,
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.20), blurRadius: 22, spreadRadius: 2)
        ],
        border: Border.all(color: color.withOpacity(0.22), width: 1.2),
      ),
      child: Icon(PhosphorIcons.check_circle_fill, size: 34.sp, color: color),
    );
  }
}

class _ErrorIcon extends StatelessWidget {
  final Color color;
  final _AttendanceDialogPalette palette;

  const _ErrorIcon({required this.color, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74.w,
      height: 74.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.errorSurface,
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.18), blurRadius: 22, spreadRadius: 2)
        ],
        border: Border.all(color: color.withOpacity(0.22), width: 1.2),
      ),
      child: Icon(PhosphorIcons.warning_circle_fill, size: 34.sp, color: color),
    );
  }
}

class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _AnimatedDots({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final opacities = List<double>.generate(3, (index) {
          final phase = (t + index * 0.22) % 1.0;
          final wave = (phase < 0.5) ? phase / 0.5 : (1 - phase) / 0.5;
          return 0.35 + (wave * 0.65);
        });

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 6.w),
              child: Opacity(
                opacity: opacities[index],
                child: Container(
                    width: 8.w,
                    height: 8.w,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: color)),
              ),
            );
          }),
        );
      },
    );
  }
}

class _AttendanceDialogPalette {
  final bool isDark;
  _AttendanceDialogPalette({required this.isDark});

  Color get surface => isDark ? const Color(0xFF17191C) : Colors.white;
  Color get surfaceAlt =>
      isDark ? const Color(0xFF1D2024) : const Color(0xFFF8FAFD);
  Color get iconSurface =>
      isDark ? const Color(0xFF1D2228) : const Color(0xFFF2F6FD);
  Color get border =>
      isDark ? const Color(0xFF2A2E34) : const Color(0xFFE4E8F0);
  Color get borderSoft =>
      isDark ? const Color(0xFF24282E) : const Color(0xFFEDF1F6);
  Color get title => isDark ? Colors.white : const Color(0xFF1A2230);
  Color get subtitle =>
      isDark ? const Color(0xFF9CA4B2) : const Color(0xFF7C889B);
  Color get muted => isDark ? const Color(0xFF7D8796) : const Color(0xFF98A2B3);
  Color get accentBlue => const Color(0xFF2F80ED);
  Color get accentGreen => const Color(0xFF2DBE60);
  Color get accentRed => const Color(0xFFE05555);
  Color get successSurface =>
      isDark ? const Color(0xFF16211B) : const Color(0xFFEAF8EF);
  Color get errorSurface =>
      isDark ? const Color(0xFF251819) : const Color(0xFFFDEEEE);

  List<Color> get backgroundGradient => isDark
      ? [const Color(0xFF17191C), const Color(0xFF131519)]
      : [Colors.white, const Color(0xFFF7F9FC)];
}
