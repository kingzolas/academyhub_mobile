import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

// --- IMPORTS DOS PROVIDERS E SERVIÇOS ---
import 'package:academyhub_mobile/services/websocket.dart';

// --- IMPORTS DAS TELAS ---
import 'package:academyhub_mobile/screens/teacher/screen_teacher_dashboard.dart';
import 'package:academyhub_mobile/screens/settings/shared_settings_view.dart';
import 'package:academyhub_mobile/attendance/class_selection_screen.dart';
import 'package:academyhub_mobile/attendance/attendance_swipe_screen.dart';
import 'package:academyhub_mobile/widgets/custom_bottom_menu.dart'; // Onde está o CustomSpeedDialMenu

// [NOVO] IMPORT DA TELA DO SCANNER
import 'package:academyhub_mobile/screens/teacher/exam_scanner_screen.dart';

class ProfessorMainScreen extends StatefulWidget {
  const ProfessorMainScreen({super.key});

  @override
  State<ProfessorMainScreen> createState() => _ProfessorMainScreenState();
}

class _ProfessorMainScreenState extends State<ProfessorMainScreen> {
  // --- VARIÁVEIS DE UI ---
  String _appVersion = "";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentIndex = 0;

  // --- NAVEGAÇÃO INTERNA DE CHAMADA ---
  String? _selectedClassId;
  String? _selectedClassName;

  // --- SERVIÇO E STATUS DO SOCKET ---
  WebSocketService? _webSocketService;
  WebSocketStatus _socketStatus = WebSocketStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    // Configuração Visual
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Pegamos o serviço via Provider apenas uma vez quando a tela é construída
    if (_webSocketService == null) {
      // Tenta pegar do contexto. (Certifique-se de que o WebSocketService foi injetado no MultiProvider no main.dart)
      _webSocketService = Provider.of<WebSocketService>(context, listen: false);

      // Define o status inicial
      _socketStatus = _webSocketService!.connectionStatus.value;

      // Começa a escutar as mudanças de status
      _webSocketService!.connectionStatus.addListener(_updateSocketStatus);
    }
  }

  void _updateSocketStatus() {
    if (mounted) {
      setState(() {
        _socketStatus = _webSocketService?.connectionStatus.value ??
            WebSocketStatus.disconnected;
      });
    }
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = "v${info.version}");
  }

  // --- NAVEGAÇÃO PRINCIPAL ---
  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  // Vai para a tela de Meus Dados (O botão flutuante direito do Professor)
  void _navigateToMyDataScreen() {
    setState(() => _currentIndex = 4);
  }

  // Vai para a tela de Seleção de Turma (Início do Fluxo de Chamada)
  void _navigateToAttendance() {
    setState(() => _currentIndex = 5);
  }

  // Lógica Interna: Seleção de Turma -> Tela de Swipe
  void _navigateToAttendanceSwipe(String classId, String className) {
    setState(() {
      _selectedClassId = classId;
      _selectedClassName = className;
      _currentIndex = 6; // Índice da tela de swipe
    });
  }

  // Lógica Interna: Tela de Swipe -> Voltar para Seleção
  void _backToClassSelection() {
    setState(() {
      _selectedClassId = null;
      _selectedClassName = null;
      _currentIndex = 5;
    });
  }

  @override
  void dispose() {
    // Importante: Remover o listener para não causar memory leak
    _webSocketService?.connectionStatus.removeListener(_updateSocketStatus);
    super.dispose();
  }

  // --- COMPONENTES VISUAIS ---
  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    // Escondemos o AppBar nas telas internas (4: Dados, 5: Seleção, 6: Swipe)
    if (_currentIndex == 4 || _currentIndex == 5 || _currentIndex == 6) {
      return null;
    }
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: true,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.6),
          ),
        ),
      ),
      title: SvgPicture.asset(
        'lib/assets/LogoAcademy.svg',
        height: 28.h,
      ),
      actions: [
        Center(
          child: Container(
            margin: EdgeInsets.only(right: 20.w),
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              color: _socketStatus == WebSocketStatus.connected
                  ? Colors.green
                  : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: (_socketStatus == WebSocketStatus.connected
                            ? Colors.green
                            : Colors.red)
                        .withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 2)
              ],
            ),
          ),
        ),
      ],
    );
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
          // 1. CONTEÚDO PRINCIPAL
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                // [ÍNDICE 0] Dashboard do Professor
                const TeacherDashboardView(),

                // [ÍNDICE 1] Alunos
                const Center(child: Text("Tela de Alunos (Em breve)")),

                // [ÍNDICE 2] Turmas
                const Center(child: Text("Tela de Turmas (Em breve)")),

                // [ÍNDICE 3] Configurações Compartilhadas
                const SharedSettingsView(),

                // [ÍNDICE 4] Meus Dados (Ação do botão direito)
                const Center(child: Text("Tela de Meus Dados (Em breve)")),

                // [ÍNDICE 5] Seleção de Turma (Ação do botão esquerdo)
                ClassSelectionScreen(
                  onBack: () => _onTabTapped(0),
                  onClassSelected: _navigateToAttendanceSwipe,
                ),

                // [ÍNDICE 6] Tela de Swipe (Tinder de Chamada)
                _selectedClassId != null
                    ? AttendanceSwipeScreen(
                        classId: _selectedClassId!,
                        className: _selectedClassName ?? "Turma",
                        onBack: _backToClassSelection,
                      )
                    : const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),

          // 2. MENU CUSTOMIZADO
          Positioned.fill(
            child: CustomSpeedDialMenu(
              isProfessor: true,
              currentIndex: _currentIndex,
              onTabSelected: _onTabTapped,
              onNavigateToAttendance: _navigateToAttendance,
              onNavigateToStaff: _navigateToMyDataScreen,

              // [NOVO] INJETAMOS A NAVEGAÇÃO PARA A CÂMERA AQUI
              onNavigateToScanner: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExamScannerScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }
}
