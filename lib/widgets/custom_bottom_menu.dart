import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomSpeedDialMenu extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  // Ações de Staff/Professor
  final VoidCallback onNavigateToAttendance;
  final VoidCallback onNavigateToStaff;

  // [NOVO] Ação do Scanner de Provas
  final VoidCallback? onNavigateToScanner;

  // [NOVO] Ação do Boletim para Professor
  final VoidCallback? onNavigateToReportCards;

  // Ações de Aluno
  final VoidCallback? onStudentAction1; // Ex: Boletim
  final VoidCallback? onStudentAction2; // Ex: Comunicados/Mural

  final bool isProfessor;
  final bool isStudent;

  const CustomSpeedDialMenu({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onNavigateToStaff,
    required this.onNavigateToAttendance,
    this.onNavigateToScanner,
    this.onNavigateToReportCards,
    this.onStudentAction1,
    this.onStudentAction2,
    this.isProfessor = false,
    this.isStudent = false,
  });

  @override
  State<CustomSpeedDialMenu> createState() => _CustomSpeedDialMenuState();
}

class _CustomSpeedDialMenuState extends State<CustomSpeedDialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  bool _isOpen = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  List<_RadialMenuAction> _buildActions() {
    if (widget.isStudent) {
      return [
        _RadialMenuAction(
          angle: 120,
          distance: 130.h,
          icon: PhosphorIcons.exam_fill,
          label: 'Boletim',
          color: const Color(0xFF00A859),
          iconColor: Colors.white,
          onTap: widget.onStudentAction1 ?? () {},
          isBig: true,
        ),
        _RadialMenuAction(
          angle: 60,
          distance: 130.h,
          icon: PhosphorIcons.megaphone_fill,
          label: 'Mural de\nAvisos',
          color: Colors.white,
          iconColor: Colors.blueAccent,
          onTap: widget.onStudentAction2 ?? () {},
          isBig: true,
        ),
      ];
    }

    if (widget.isProfessor) {
      return [
        _RadialMenuAction(
          angle: 150,
          distance: 128.h,
          icon: PhosphorIcons.check_circle_fill,
          label: 'Realizar\nChamada',
          color: const Color(0xFF00A859),
          iconColor: Colors.white,
          onTap: widget.onNavigateToAttendance,
          isBig: true,
        ),
        _RadialMenuAction(
          angle: 115,
          distance: 142.h,
          icon: PhosphorIcons.file_text_fill,
          label: 'Boletins',
          color: const Color(0xFF2F80ED),
          iconColor: Colors.white,
          onTap: widget.onNavigateToReportCards ?? () {},
          isBig: true,
        ),
        _RadialMenuAction(
          angle: 75,
          distance: 142.h,
          icon: PhosphorIcons.scan_bold,
          label: 'Corrigir\nProvas',
          color: Colors.black,
          iconColor: Colors.amber,
          onTap: widget.onNavigateToScanner ?? () {},
          isBig: true,
        ),
        _RadialMenuAction(
          angle: 35,
          distance: 128.h,
          icon: PhosphorIcons.identification_card_fill,
          label: 'Meus\nDados',
          color: Colors.white,
          iconColor: Colors.blueAccent,
          onTap: widget.onNavigateToStaff,
          isBig: true,
        ),
      ];
    }

    return [
      _RadialMenuAction(
        angle: 120,
        distance: 130.h,
        icon: PhosphorIcons.check_circle_fill,
        label: 'Realizar\nChamada',
        color: const Color(0xFF00A859),
        iconColor: Colors.white,
        onTap: widget.onNavigateToAttendance,
        isBig: true,
      ),
      _RadialMenuAction(
        angle: 60,
        distance: 130.h,
        icon: PhosphorIcons.identification_card_fill,
        label: 'Gestão de\nEquipe',
        color: Colors.white,
        iconColor: Colors.blueAccent,
        onTap: widget.onNavigateToStaff,
        isBig: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kPrimaryGreen = const Color(0xFF00A859);
    final kBarColor = Theme.of(context).cardColor;

    final double barHeight = 80.h;
    final double fabBottomMargin = 25.h;
    final double fabSize = 65.w;

    final Size screenSize = MediaQuery.of(context).size;
    final double centerX = screenSize.width / 2;
    final double anchorBottom = fabBottomMargin + (fabSize / 2);

    final actions = _buildActions();

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: GestureDetector(
                onTap: _toggleMenu,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: (_controller.value * 1.0).clamp(0.0, 1.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Container(
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          ...actions.map(
            (action) => _buildPhysicalNavigationButton(
              centerX: centerX,
              anchorBottom: anchorBottom,
              angle: action.angle,
              distance: action.distance,
              icon: action.icon,
              label: action.label,
              color: action.color,
              iconColor: action.iconColor,
              onTap: action.onTap,
              isBig: action.isBig,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: kBarColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25.r),
                  topRight: Radius.circular(25.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabItem(
                    0,
                    PhosphorIcons.house_fill,
                    'Início',
                    isDark,
                  ),
                  _buildTabItem(
                    1,
                    widget.isStudent
                        ? PhosphorIcons.book_open_fill
                        : (widget.isProfessor
                            ? PhosphorIcons.student_fill
                            : PhosphorIcons.users_three_fill),
                    widget.isStudent
                        ? 'Provas'
                        : (widget.isProfessor ? 'Alunos' : 'Participantes'),
                    isDark,
                  ),
                  SizedBox(width: 60.w),
                  _buildTabItem(
                    2,
                    widget.isStudent
                        ? PhosphorIcons.receipt_fill
                        : (widget.isProfessor
                            ? PhosphorIcons.chalkboard_teacher_fill
                            : PhosphorIcons.money_fill),
                    widget.isStudent
                        ? 'Mensalidades'
                        : (widget.isProfessor ? 'Turmas' : 'Financeiro'),
                    isDark,
                  ),
                  _buildTabItem(
                    3,
                    PhosphorIcons.gear_fill,
                    'Mais',
                    isDark,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: fabBottomMargin,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: RotationTransition(
                turns: _rotateAnimation,
                child: Container(
                  width: fabSize,
                  height: fabSize,
                  decoration: BoxDecoration(
                    color: _isOpen ? Colors.white : kPrimaryGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryGreen.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isOpen
                        ? PhosphorIcons.x_bold
                        : PhosphorIcons.squares_four_bold,
                    color: _isOpen ? Colors.black : Colors.white,
                    size: 32.sp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = widget.currentIndex == index;

    return IgnorePointer(
      ignoring: _isOpen,
      child: GestureDetector(
        onTap: () => widget.onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF00A859)
                  : (isDark ? Colors.grey[600] : Colors.grey[400]),
              size: 26.sp,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF00A859)
                    : (isDark ? Colors.grey[600] : Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalNavigationButton({
    required double centerX,
    required double anchorBottom,
    required double angle,
    required double distance,
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    bool isBig = false,
  }) {
    final double rad = angle * (math.pi / 180);
    final double buttonSize = isBig ? 65.w : 55.w;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final double progress = _expandAnimation.value;
        final double currentDist = distance * progress;
        final double offsetX = currentDist * math.cos(rad);
        final double offsetY = currentDist * math.sin(rad);
        final double leftPos = centerX + offsetX - (buttonSize / 2);
        final double bottomPos = anchorBottom + offsetY - (buttonSize / 2);
        final double opacity = progress.clamp(0.0, 1.0);

        if (_controller.isDismissed) return const SizedBox();

        return Positioned(
          left: leftPos,
          bottom: bottomPos,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: progress,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      _toggleMenu();
                      Future.delayed(const Duration(milliseconds: 100), onTap);
                    },
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: isBig ? 30.sp : 24.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RadialMenuAction {
  final double angle;
  final double distance;
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isBig;

  const _RadialMenuAction({
    required this.angle,
    required this.distance,
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.isBig = false,
  });
}
