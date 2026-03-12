import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Providers
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/theme_provider.dart';
import 'package:academyhub_mobile/providers/whatsapp_provider.dart';

// Widgets
import 'package:academyhub_mobile/widgets/whatsapp_connection_dialog.dart';
import 'package:academyhub_mobile/screens/staff_management_screen.dart'; // Importe a tela de gestão

class SharedSettingsView extends StatefulWidget {
  const SharedSettingsView({super.key});

  @override
  State<SharedSettingsView> createState() => _SharedSettingsViewState();
}

class _SharedSettingsViewState extends State<SharedSettingsView> {
  String _appVersion = "";

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = "v${info.version}");
  }

  void _showWhatsappDialog(BuildContext context) {
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
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 110.h, 16.w, 120.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER DO PERFIL ---
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

          // --- SEÇÃO ADMINISTRAÇÃO ---
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
                  onTap: () {
                    // Navegação direta para a tela de gestão
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StaffManagementScreen()));
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // --- SEÇÃO PREFERÊNCIAS ---
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
                  onTap: () => _showWhatsappDialog(context),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // --- BOTÃO SAIR ---
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
}
