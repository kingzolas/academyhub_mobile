import 'dart:ui';
import 'package:academyhub_mobile/model/user_model.dart';
import 'package:academyhub_mobile/screens/student/student_activities_screen.dart';
import 'package:academyhub_mobile/screens/student/student_invoices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Providers
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/theme_provider.dart';

// Widgets Globais
import 'package:academyhub_mobile/widgets/custom_bottom_menu.dart'; // O SEU MENU

class StudentDashboardView extends StatefulWidget {
  const StudentDashboardView({super.key});

  @override
  State<StudentDashboardView> createState() => _StudentDashboardViewState();
}

class _StudentDashboardViewState extends State<StudentDashboardView> {
  // Controle de navegação
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Configura a barra de status transparente para imersão
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  // Função para mudar de aba (usada pelo Bottom Menu)
  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  // --- TELAS (ABAS) ---

  // 1. A Home (Grid de Tiles)
  Widget _buildHomeContent(User? user) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20.w, 110.h, 20.w, 100.h), // Padding inferior maior p/ o menu
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de Boas Vindas
          Text(
            "Olá, ${user?.fullName.split(' ').first ?? 'Aluno'}! 👋",
            style: GoogleFonts.inter(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          Text(
            "Confira suas atividades de hoje.",
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24.h),

          // Grid de Menus
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
            childAspectRatio: 1.1,
            children: [
              _buildMenuCard(
                title: "Minhas Notas",
                icon: PhosphorIcons.exam,
                color: Colors.blueAccent,
                onTap: () {
                  // Navegação futura
                },
              ),
              _buildMenuCard(
                title: "Frequência",
                icon: PhosphorIcons.calendar_check,
                color: Colors.green,
                onTap: () {},
              ),
              _buildMenuCard(
                title: "Financeiro",
                icon: PhosphorIcons.currency_dollar,
                color: Colors.orange,
                onTap: () {
                  // Se o menu inferior tiver aba financeira, podemos mudar o index:
                  // _onTabTapped(2);
                },
              ),
              _buildMenuCard(
                title: "Secretaria",
                icon: PhosphorIcons.files,
                color: Colors.purple,
                onTap: () {},
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Área de Avisos / Pendências
          Text(
            "Mural de Avisos",
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          _buildTaskCard("Rematrícula 2024", "Prazo: 20/12"),
          SizedBox(height: 10.h),
          _buildTaskCard("Feira de Ciências", "Sábado, 09:00"),
        ],
      ),
    );
  }

  // 2. Tela de Perfil/Configurações (Reutilizando lógica visual)
  Widget _buildProfileContent(User? user) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 110.h, 20.w, 100.h),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40.sp,
            backgroundColor: Colors.grey.shade200,
            // Se tiver foto, usar NetworkImage
            child: Icon(PhosphorIcons.student, size: 40.sp, color: Colors.grey),
          ),
          SizedBox(height: 16.h),
          Text(user?.fullName ?? "Aluno",
              style: GoogleFonts.inter(
                  fontSize: 20.sp, fontWeight: FontWeight.bold)),
          Text(
              "Matrícula: ${user?.username ?? '...'}", // Usando username ou enrollment se tiver no model
              style: GoogleFonts.inter(color: Colors.grey)),
          SizedBox(height: 32.h),
          Card(
            elevation: 0,
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
                  leading:
                      const Icon(PhosphorIcons.sign_out, color: Colors.red),
                  title: const Text("Sair da Conta",
                      style: TextStyle(color: Colors.red)),
                  onTap: () => Provider.of<AuthProvider>(context, listen: false)
                      .logout(),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---
  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // Adapta ao tema
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(String title, String subtitle) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style:
                      GoogleFonts.inter(color: Colors.grey, fontSize: 12.sp)),
            ],
          )
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false, // Remove seta de voltar
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
        height: 24.h,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // 1. CONTEÚDO DAS ABAS
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeContent(user), // Index 0: Home
                const StudentActivitiesScreen(), // Index 1: Placeholder
                const StudentInvoicesScreen(), // Index 2: Placeholder
                _buildProfileContent(
                    user), // Index 3: Perfil (Ajuste conforme o índice do seu Menu)

                // IMPORTANTE: Adicione placeholders vazios se o seu menu tiver mais itens
                // O IndexedStack precisa ter o mesmo número de filhos que o maior índice do menu
                const SizedBox(), // 4
                const SizedBox(), // 5
                const SizedBox(), // 6
              ],
            ),
          ),

          // 2. MENU FLUTUANTE (BOTTOM BAR)
          Positioned.fill(
            child: CustomSpeedDialMenu(
              isStudent: true, // <-- ISSO AQUI FAZ A MÁGICA ACONTECER
              currentIndex: _currentIndex,
              onTabSelected: _onTabTapped,

              // --- CALLBACKS ESPECÍFICOS DE STAFF ---
              // Como estamos reusando o componente do Staff, precisamos passar algo.
              // Passamos funções vazias pois aluno não faz chamada nem gere staff.
              onNavigateToAttendance: () {
                debugPrint(
                    "Aluno tentou acessar chamada (Bloqueado/Invisível)");
              },
              onNavigateToStaff: () {
                debugPrint(
                    "Aluno tentou acessar gestão de staff (Bloqueado/Invisível)");
              },
            ),
          ),
        ],
      ),
    );
  }
}
