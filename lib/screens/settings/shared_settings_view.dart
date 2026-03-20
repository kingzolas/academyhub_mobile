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
import 'package:academyhub_mobile/providers/class_provider.dart'; // [NOVO] Para pegar turmas e alunos
import 'package:academyhub_mobile/providers/horario_provider.dart'; // [NOVO] Para saber onde ele dá aula

// Models
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/staff_profile_model.dart';

// Widgets
import 'package:academyhub_mobile/widgets/whatsapp_connection_dialog.dart';
import 'package:academyhub_mobile/screens/staff_management_screen.dart';

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

  String _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return '--';
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return '$age anos';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final horarioProvider = Provider.of<HorarioProvider>(context);
    final user = authProvider.user;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1D2024) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2E34) : const Color(0xFFE7EBF2);

    // --- LÓGICA DE PERMISSÃO E DADOS ---
    bool isGestor = false;
    String displayRole = "Usuário";
    StaffProfile? staffProfile;

    if (user != null) {
      final lowerRoles = user.roles.map((r) => r.toLowerCase()).toList();
      isGestor = lowerRoles.contains('admin') ||
          lowerRoles.contains('diretor') ||
          lowerRoles.contains('coordenador') ||
          lowerRoles.contains('administrador');

      if (user.roles.isNotEmpty) {
        displayRole = user.roles.first.toUpperCase();
      }

      if (user.staffProfiles.isNotEmpty) {
        staffProfile = user.staffProfiles.first;
        if (staffProfile.mainRole.isNotEmpty) {
          displayRole = staffProfile.mainRole.toUpperCase();
        }
      }
    }

    // --- CÁLCULO DE TURMAS E ALUNOS (Para Professores) ---
    int totalStudents = 0;
    List<ClassModel> myClasses = [];

    if (!isGestor && user != null) {
      // 1. Pega todas as aulas desse professor
      final myHorarios = horarioProvider.horarios
          .where((h) => h.teacherId == user.id)
          .toList();
      // 2. Extrai os IDs únicos das turmas
      final myClassIds = myHorarios.map((h) => h.classId).toSet();
      // 3. Busca os objetos completos dessas turmas
      myClasses = classProvider.classes
          .where((c) => myClassIds.contains(c.id))
          .toList();
      // 4. Soma a quantidade de alunos
      totalStudents =
          myClasses.fold(0, (sum, c) => sum + (c.studentCount ?? 0));
    }

    final ageString = _calculateAge(user?.birthDate);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 60.h, 16.w, 120.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // CABEÇALHO DO PERFIL
          // ==========================================
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 70.w,
                  height: 70.w,
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF2F80ED).withOpacity(0.5),
                        width: 2),
                  ),
                  child: CircleAvatar(
                    backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[100],
                    backgroundImage: (user?.profilePictureUrl != null &&
                            user!.profilePictureUrl!.isNotEmpty)
                        ? NetworkImage(user.profilePictureUrl!)
                        : null,
                    child: (user?.profilePictureUrl == null ||
                            user!.profilePictureUrl!.isEmpty)
                        ? Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.inter(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2F80ED)),
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? "Usuário",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A2230),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F80ED).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(99.r),
                        ),
                        child: Text(
                          displayRole,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2F80ED),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // ==========================================
          // MÉTRICAS RÁPIDAS (Exclusivo para Professores)
          // ==========================================
          if (!isGestor && myClasses.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: "Alunos Atendidos",
                    value: totalStudents.toString(),
                    icon: PhosphorIcons.users_three_fill,
                    color: const Color(0xFF2DBE60),
                    isDark: isDark,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _StatCard(
                    title: "Minhas Turmas",
                    value: myClasses.length.toString(),
                    icon: PhosphorIcons.chalkboard_teacher_fill,
                    color: const Color(0xFFF2994A),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 32.h),
          ],

          // ==========================================
          // PERFIL PROFISSIONAL
          // ==========================================
          if (staffProfile != null ||
              user?.birthDate != null ||
              (!isGestor && myClasses.isNotEmpty)) ...[
            _SectionTitle(title: "Resumo Profissional"),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InfoBadge(
                        icon: PhosphorIcons.calendar_blank,
                        title: "Idade",
                        value: ageString,
                        color: const Color(0xFFF2994A),
                        isDark: isDark,
                      ),
                      SizedBox(width: 16.w),
                      if (staffProfile?.employmentType != null &&
                          staffProfile!.employmentType.isNotEmpty)
                        _InfoBadge(
                          icon: PhosphorIcons.briefcase,
                          title: "Contrato",
                          value: staffProfile.employmentType,
                          color: const Color(0xFF7A5AF8),
                          isDark: isDark,
                        ),
                    ],
                  ),

                  // -- LISTA DE TURMAS DO PROFESSOR --
                  if (!isGestor && myClasses.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    Text(
                      "Turmas que leciono",
                      style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: myClasses.map((turma) {
                        return _TagChip(
                          label: turma.name,
                          color: const Color(0xFF2F80ED),
                          isDark: isDark,
                          icon: PhosphorIcons.chalkboard,
                        );
                      }).toList(),
                    ),
                  ],

                  if (staffProfile?.academicFormation != null &&
                      staffProfile!.academicFormation!.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    Text(
                      "Formação Acadêmica",
                      style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      staffProfile.academicFormation!,
                      style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],

                  if (staffProfile != null &&
                      staffProfile.enabledSubjects.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    Text(
                      "Disciplinas Habilitadas",
                      style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: staffProfile.enabledSubjects.map((subject) {
                        return _TagChip(
                            label: subject.name,
                            color: const Color(0xFF2DBE60),
                            isDark: isDark);
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 32.h),
          ],

          // ==========================================
          // ADMINISTRAÇÃO (Apenas Gestores)
          // ==========================================
          if (isGestor) ...[
            _SectionTitle(title: "Administração"),
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: borderColor),
              ),
              child: ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                leading: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2F80ED).withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(PhosphorIcons.users_three_fill,
                      color: Color(0xFF2F80ED)),
                ),
                title: Text("Gestão de Equipe",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 15.sp)),
                trailing: const Icon(PhosphorIcons.caret_right,
                    size: 20, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const StaffManagementScreen()));
                },
              ),
            ),
            SizedBox(height: 32.h),
          ],

          // ==========================================
          // PREFERÊNCIAS E CONFIGURAÇÕES
          // ==========================================
          _SectionTitle(title: "Preferências e Conta"),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                // Info de Contato (Para ele conferir se tá certo)
                if (user?.email != null && user!.email.isNotEmpty)
                  ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 0.h),
                    leading: Icon(PhosphorIcons.envelope_simple,
                        color: Colors.grey, size: 22.sp),
                    title: Text("E-mail Cadastrado",
                        style: GoogleFonts.inter(
                            fontSize: 12.sp, color: Colors.grey)),
                    subtitle: Text(user.email,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.sp,
                            color: isDark ? Colors.white : Colors.black87)),
                  ),
                Divider(
                    height: 1,
                    color: borderColor,
                    indent: 20.w,
                    endIndent: 20.w),

                ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
                  leading: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                        color: const Color(0xFF7A5AF8).withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(
                        isDark
                            ? PhosphorIcons.moon_fill
                            : PhosphorIcons.sun_fill,
                        color: const Color(0xFF7A5AF8)),
                  ),
                  title: Text("Modo Escuro",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 15.sp)),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    activeColor: const Color(0xFF7A5AF8),
                    onChanged: themeProvider.toggleTheme,
                  ),
                ),

                // Conexão do Whatsapp APENAS para gestores
                if (isGestor) ...[
                  Divider(
                      height: 1,
                      color: borderColor,
                      indent: 20.w,
                      endIndent: 20.w),
                  ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
                    leading: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2DBE60).withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(PhosphorIcons.whatsapp_logo_fill,
                          color: Color(0xFF2DBE60)),
                    ),
                    title: Text("Conexão WhatsApp",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, fontSize: 15.sp)),
                    trailing: const Icon(PhosphorIcons.caret_right,
                        size: 20, color: Colors.grey),
                    onTap: () => _showWhatsappDialog(context),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 40.h),

          // ==========================================
          // BOTÃO SAIR
          // ==========================================
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => authProvider.logout(context),
              icon: const Icon(PhosphorIcons.sign_out, color: Colors.white),
              label: Text("Sair da Conta",
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                backgroundColor: const Color(0xFFFF4B4B),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
          ),

          SizedBox(height: 20.h),

          Center(
            child: Text(
              _appVersion,
              style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500),
            ),
          )
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES DE LAYOUT ---

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2024) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
            color: isDark ? const Color(0xFF2A2E34) : const Color(0xFFE7EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28.sp),
          SizedBox(height: 12.h),
          Text(
            value,
            style: GoogleFonts.sairaCondensed(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                height: 1),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool isDark;

  const _InfoBadge(
      {required this.icon,
      required this.title,
      required this.value,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r)),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 11.5.sp,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final IconData? icon;

  const _TagChip(
      {required this.label,
      required this.color,
      required this.isDark,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 14.sp, color: isDark ? color.withOpacity(0.9) : color),
            SizedBox(width: 6.w),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? color.withOpacity(0.9) : color,
            ),
          ),
        ],
      ),
    );
  }
}
