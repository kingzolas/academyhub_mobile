import 'dart:ui';

import 'package:academyhub_mobile/attendance/attendance_swipe_screen.dart';
import 'package:academyhub_mobile/attendance/class_selection_screen.dart';
import 'package:academyhub_mobile/screens/settings/shared_settings_view.dart';
import 'package:academyhub_mobile/screens/teacher/exam_scanner_screen.dart';
import 'package:academyhub_mobile/screens/teacher/screen_report_cards.dart';
import 'package:academyhub_mobile/screens/teacher/screen_teacher_dashboard.dart';
import 'package:academyhub_mobile/services/websocket.dart';
import 'package:academyhub_mobile/widgets/custom_bottom_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class ProfessorMainScreen extends StatefulWidget {
  const ProfessorMainScreen({super.key});

  @override
  State<ProfessorMainScreen> createState() => _ProfessorMainScreenState();
}

class _ProfessorMainScreenState extends State<ProfessorMainScreen> {
  static const int _homeIndex = 0;
  static const int _studentsIndex = 1;
  static const int _classesIndex = 2;
  static const int _settingsIndex = 3;

  static const int _myDataIndex = 4;
  static const int _attendanceClassSelectionIndex = 5;
  static const int _attendanceSwipeIndex = 6;
  static const int _reportCardsIndex = 7;

  String _appVersion = "";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentIndex = _homeIndex;

  String? _selectedClassId;
  String? _selectedClassName;

  WebSocketService? _webSocketService;
  WebSocketStatus _socketStatus = WebSocketStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_webSocketService == null) {
      _webSocketService = Provider.of<WebSocketService>(context, listen: false);
      _socketStatus = _webSocketService!.connectionStatus.value;
      _webSocketService!.connectionStatus.addListener(_updateSocketStatus);
    }
  }

  void _updateSocketStatus() {
    if (!mounted) return;
    setState(() {
      _socketStatus = _webSocketService?.connectionStatus.value ??
          WebSocketStatus.disconnected;
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = "v${info.version}");
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _navigateToMyDataScreen() {
    setState(() => _currentIndex = _myDataIndex);
  }

  void _navigateToAttendance() {
    setState(() => _currentIndex = _attendanceClassSelectionIndex);
  }

  void _navigateToAttendanceSwipe(String classId, String className) {
    setState(() {
      _selectedClassId = classId;
      _selectedClassName = className;
      _currentIndex = _attendanceSwipeIndex;
    });
  }

  void _backToClassSelection() {
    setState(() {
      _selectedClassId = null;
      _selectedClassName = null;
      _currentIndex = _attendanceClassSelectionIndex;
    });
  }

  void _navigateToReportCards() {
    setState(() => _currentIndex = _reportCardsIndex);
  }

  void _navigateToScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ExamScannerScreen(),
      ),
    );
  }

  bool _shouldHideAppBar() {
    return _currentIndex == _myDataIndex ||
        _currentIndex == _attendanceClassSelectionIndex ||
        _currentIndex == _attendanceSwipeIndex ||
        _currentIndex == _reportCardsIndex;
  }

  int _bottomMenuSelectedIndex() {
    if (_currentIndex == _homeIndex ||
        _currentIndex == _studentsIndex ||
        _currentIndex == _classesIndex ||
        _currentIndex == _settingsIndex) {
      return _currentIndex;
    }
    return _homeIndex;
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (_shouldHideAppBar()) return null;

    // return AppBar(
    //   elevation: 0,
    //   scrolledUnderElevation: 0,
    //   backgroundColor: Colors.transparent,
    //   centerTitle: true,
    //   automaticallyImplyLeading: false,
    //   flexibleSpace: ClipRect(
    //     child: BackdropFilter(
    //       filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    //       child: Container(
    //         color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.6),
    //       ),
    //     ),
    //   ),
    //   title: SvgPicture.asset(
    //     'lib/assets/LogoAcademy.svg',
    //     height: 28.h,
    //   ),
    //   actions: [
    //     Center(
    //       child: Container(
    //         margin: EdgeInsets.only(right: 20.w),
    //         width: 10.w,
    //         height: 10.w,
    //         decoration: BoxDecoration(
    //           color: _socketStatus == WebSocketStatus.connected
    //               ? Colors.green
    //               : Colors.red,
    //           shape: BoxShape.circle,
    //           boxShadow: [
    //             BoxShadow(
    //               color: (_socketStatus == WebSocketStatus.connected
    //                       ? Colors.green
    //                       : Colors.red)
    //                   .withOpacity(0.4),
    //               blurRadius: 4,
    //               spreadRadius: 2,
    //             ),
    //           ],
    //         ),
    //       ),
    //     ),
    //   ],
    // );
  }

  @override
  void dispose() {
    _webSocketService?.connectionStatus.removeListener(_updateSocketStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const TeacherDashboardView(),
                const Center(child: Text("Tela de Alunos (Em breve)")),
                const Center(child: Text("Tela de Turmas (Em breve)")),
                const SharedSettingsView(),
                const Center(child: Text("Tela de Meus Dados (Em breve)")),
                ClassSelectionScreen(
                  onBack: () => _onTabTapped(_homeIndex),
                  onClassSelected: _navigateToAttendanceSwipe,
                ),
                _selectedClassId != null
                    ? AttendanceSwipeScreen(
                        classId: _selectedClassId!,
                        className: _selectedClassName ?? "Turma",
                        onBack: _backToClassSelection,
                      )
                    : const Center(child: CircularProgressIndicator()),
                const ScreenReportCards(),
              ],
            ),
          ),
          Positioned.fill(
            child: CustomSpeedDialMenu(
              isProfessor: true,
              currentIndex: _bottomMenuSelectedIndex(),
              onTabSelected: _onTabTapped,
              onNavigateToAttendance: _navigateToAttendance,
              onNavigateToStaff: _navigateToMyDataScreen,
              onNavigateToReportCards: _navigateToReportCards,
              onNavigateToScanner: _navigateToScanner,
            ),
          ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }
}
