import 'dart:ui';
import 'package:academyhub_mobile/providers/privacy_provider.dart';
import 'package:academyhub_mobile/screens/ScreenFinanceiro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

// --- IMPORTS DOS PROVIDERS ---
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/theme_provider.dart';
import 'package:academyhub_mobile/providers/user_provider.dart';
import 'package:academyhub_mobile/providers/whatsapp_provider.dart';

// --- IMPORTS DAS TELAS ---
import 'package:academyhub_mobile/attendance/attendance_swipe_screen.dart';
import 'package:academyhub_mobile/attendance/class_selection_screen.dart';
import 'package:academyhub_mobile/screens/financeiro/expense_form_dialog.dart';
import 'package:academyhub_mobile/screens/financeiro/screen_financeiro_despesas.dart';
import 'package:academyhub_mobile/screens/ScreenHomePage.dart';
import 'package:academyhub_mobile/screens/ScreenParticipantes.dart';
import 'package:academyhub_mobile/screens/staff_management_screen.dart';

// --- IMPORTS DE SERVIÇOS E WIDGETS ---
import 'package:academyhub_mobile/services/websocket.dart';
import 'package:academyhub_mobile/widgets/custom_bottom_menu.dart';
import 'package:academyhub_mobile/widgets/whatsapp_connection_dialog.dart';
import 'package:academyhub_mobile/widgets/staff_form_dialog.dart';

class StaffDashboardView extends StatefulWidget {
  // Recebemos o serviço do pai para monitorar o status (Online/Offline)
  final WebSocketService webSocketService;

  const StaffDashboardView({
    super.key,
    required this.webSocketService,
  });

  @override
  State<StaffDashboardView> createState() => _StaffDashboardViewState();
}

class _StaffDashboardViewState extends State<StaffDashboardView> {
  // --- VARIÁVEIS DE UI ---
  String _appVersion = "";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentIndex = 0;

  // --- NAVEGAÇÃO INTERNA DE CHAMADA ---
  String? _selectedClassId;
  String? _selectedClassName;

  // --- STATUS DO SOCKET (Para UI apenas) ---
  late WebSocketStatus _socketStatus;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    // Configuração Visual
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Inicializa o status atual
    _socketStatus = widget.webSocketService.connectionStatus.value;

    // Escuta mudanças no status para atualizar a bolinha verde/vermelha
    widget.webSocketService.connectionStatus.addListener(_updateSocketStatus);
  }

  void _updateSocketStatus() {
    if (mounted) {
      setState(() {
        _socketStatus = widget.webSocketService.connectionStatus.value;
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

  // Vai para a tela de Equipe (Staff)
  void _navigateToStaffScreen() {
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

  void _openAddExpense() {
    setState(() => _currentIndex = 2);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => const ExpenseFormSheet(),
    );
  }

  void _openAddStaff() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StaffFormDialog(onSubmit: (data) async {
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        ;
        await userProvider.addStaff(data, authProvider.token!);
        return userProvider.error == null;
      }),
    );
  }

  void _showWhatsappDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 0.8.sh,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: ChangeNotifierProvider(
          create: (_) => WhatsappProvider(),
          child: const WhatsappConnectionDialog(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Importante: Remover o listener para não causar memory leak
    widget.webSocketService.connectionStatus
        .removeListener(_updateSocketStatus);
    super.dispose();
  }

  // --- CONTEÚDO DAS TELAS ---
  Widget _buildHomePage() {
    return ScreenHomePage(
      onNavigateToExpenses: (filter) => _onTabTapped(2),
    );
  }

  Widget _buildSettingsPage() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 110.h, 16.w, 120.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30.sp,
                backgroundColor: Colors.grey.shade200,
                child: Icon(PhosphorIcons.user,
                    size: 35.sp, color: Colors.grey.shade700),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.fullName ?? "Usuário",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 18.sp)),
                  Text(user?.username ?? "Academy Hub",
                      style: GoogleFonts.inter(
                          fontSize: 14.sp, color: Colors.grey)),
                ],
              ),
            ],
          ),
          SizedBox(height: 32.h),
          Text("Administração",
              style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          SizedBox(height: 10.h),
          Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(color: Colors.grey.withOpacity(0.1))),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(PhosphorIcons.users_three,
                      color: Colors.blueAccent),
                  title: const Text("Gestão de Equipe"),
                  trailing: const Icon(PhosphorIcons.caret_right, size: 16),
                  onTap: _navigateToStaffScreen,
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Text("Preferências",
              style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          SizedBox(height: 10.h),
          Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(color: Colors.grey.withOpacity(0.1))),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(PhosphorIcons.moon_stars),
                  title: const Text("Modo Escuro"),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: themeProvider.toggleTheme,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(PhosphorIcons.whatsapp_logo,
                      color: Colors.green),
                  title: const Text("Conexão WhatsApp"),
                  trailing: const Icon(PhosphorIcons.caret_right, size: 16),
                  onTap: _showWhatsappDialog,
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => authProvider.logout(),
              icon: const Icon(PhosphorIcons.sign_out, color: Colors.redAccent),
              label: const Text("Sair da Conta",
                  style: TextStyle(color: Colors.redAccent)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Center(
            child: Text(
              _appVersion,
              style:
                  GoogleFonts.inter(color: Colors.grey[400], fontSize: 12.sp),
            ),
          )
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    // Escondemos o AppBar nas telas internas (4, 5 e 6)
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
    // O ScreenUtilInit já deve estar no main.dart ou no Dashboard pai.
    // Mas se quiser manter por garantia de contexto, pode deixar.
    // Normalmente removemos daqui se o pai já tiver.
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
                _buildHomePage(), // 0
                const ScreenparticipantesMobile(), // 1
                ChangeNotifierProvider(
                    create: (_) => PrivacyProvider(),
                    child: ScreenFinanceiro()), // 2
                _buildSettingsPage(), // 3
                const StaffManagementScreen(), // 4

                // [ÍNDICE 5] Seleção de Turma
                ClassSelectionScreen(
                  onBack: () => _onTabTapped(0),
                  onClassSelected: _navigateToAttendanceSwipe,
                ),

                // [ÍNDICE 6] Tela de Swipe (Tinder)
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
              onNavigateToAttendance: _navigateToAttendance,
              currentIndex: _currentIndex,
              onTabSelected: _onTabTapped,
              onNavigateToStaff: _navigateToStaffScreen,
            ),
          ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }
}
