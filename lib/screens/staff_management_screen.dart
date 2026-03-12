import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../model/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/staff_form_dialog.dart';

class StaffManagementScreen extends StatefulWidget {
  final double bottomBarPadding;
  const StaffManagementScreen({super.key, this.bottomBarPadding = 80.0});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  String? _errorLoading;
  bool _isLoadingInitial = true;

  final _searchNameController = TextEditingController();
  String? _selectedRoleFilter;
  String? _selectedStatusFilter = 'Ativo';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUsers());
    _searchNameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    if (mounted)
      setState(() {
        _isLoadingInitial = true;
        _errorLoading = null;
      });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) return;

    try {
      await Provider.of<UserProvider>(context, listen: false).fetchUsers(token);
    } catch (e) {
      if (mounted)
        setState(
            () => _errorLoading = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  List<User> _applyFilters(List<User> allUsers) {
    final searchName = _searchNameController.text.trim().toLowerCase();
    return allUsers.where((user) {
      final matchesName = searchName.isEmpty ||
          user.fullName.toLowerCase().contains(searchName) ||
          user.email.toLowerCase().contains(searchName);
      final userRoles = user.roles.map((r) => r.toString()).toList();
      final matchesRole = _selectedRoleFilter == null ||
          userRoles.contains(_selectedRoleFilter);
      final matchesStatus =
          _selectedStatusFilter == null || user.status == _selectedStatusFilter;
      return matchesName && matchesRole && matchesStatus;
    }).toList();
  }

  // --- AÇÕES ---
  void _showStaffForm({User? existingUser}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StaffFormDialog(
            existingUser: existingUser,
            onSubmit: (data) async {
              final provider =
                  Provider.of<UserProvider>(context, listen: false);
              if (existingUser == null)
                await provider.addStaff(data, authProvider.token!);
              else
                await provider.updateStaff(
                    existingUser.id, data, authProvider.token!);
              if (provider.error == null) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Salvo com sucesso!"),
                    backgroundColor: Colors.green));
                return true;
              }
              return false;
            }));
  }

  void _showActionSheet(User user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark ||
        theme.scaffoldBackgroundColor.computeLuminance() < 0.5;
    final isActive = user.status == 'Ativo';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 40.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2.r))),
            SizedBox(height: 20.h),
            Row(
              children: [
                StaffAvatar(
                    fullName: user.fullName, userId: user.id, radius: 24.r),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87)),
                      Text(user.email,
                          style:
                              TextStyle(fontSize: 12.sp, color: Colors.grey)),
                    ],
                  ),
                )
              ],
            ),
            Divider(height: 30.h, color: Colors.grey.withOpacity(0.2)),
            _buildActionTile(PhosphorIcons.pencil_simple, "Editar Dados", () {
              Navigator.pop(ctx);
              _showStaffForm(existingUser: user);
            }, isDark),
            _buildActionTile(
                isActive ? PhosphorIcons.lock_key : PhosphorIcons.lock_key_open,
                isActive ? "Bloquear Acesso" : "Reativar Acesso", () {
              Navigator.pop(ctx);
              _confirmStatusChange(user);
            }, isDark, isDestructive: isActive),
          ],
        ),
      ),
    );
  }

  void _confirmStatusChange(User user) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = user.status == 'Ativo';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(isActive ? 'Inativar?' : 'Reativar?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text(
            isActive
                ? 'Isso bloqueará o acesso de "${user.fullName}".'
                : 'Isso permitirá o acesso de "${user.fullName}".',
            style:
                TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red : Colors.green),
            onPressed: () async {
              final provider =
                  Provider.of<UserProvider>(context, listen: false);
              await provider.inactivateUser(user.id, authProvider.token!);
              if (mounted) Navigator.of(ctx).pop();
            },
            child: Text(isActive ? 'Inativar' : 'Reativar',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark ||
        theme.scaffoldBackgroundColor.computeLuminance() < 0.5;

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121212), Color(0xFF1E1E1E), Color(0xFF101010)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FA), Color(0xFFF1F5F9)],
          );

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final filteredUsers = _applyFilters(userProvider.users);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(gradient: bgGradient),
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Header com Botão "Novo" Integrado (Agora rola com a tela para não bloquear filtros)
                  SliverToBoxAdapter(
                    child: _buildTopHeader(isDark),
                  ),

                  // 2. Filtros Sticky com Glassmorphism
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _GlassStickyHeaderDelegate(
                      minHeight: 130.h,
                      maxHeight: 130.h,
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: _buildModernSearchBar(
                                isDark, _searchNameController),
                          ),
                          SizedBox(height: 12.h),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Row(
                              children: [
                                _buildModernChip(
                                    "Todos Cargos",
                                    _selectedRoleFilter,
                                    isDark,
                                    () => _showRoleSelector(isDark)),
                                SizedBox(width: 8.w),
                                _buildStatusToggleModern(isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Lista de Funcionários
                  if (_isLoadingInitial)
                    const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()))
                  else if (filteredUsers.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIcons.users_three,
                                size: 64.sp,
                                color: Colors.grey.withOpacity(0.3)),
                            SizedBox(height: 10.h),
                            Text("Ninguém encontrado",
                                style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20.w, vertical: 10.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildPremiumStaffCard(
                              filteredUsers[index], theme, isDark),
                          childCount: filteredUsers.length,
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(
                      child:
                          SizedBox(height: widget.bottomBarPadding.h + 20.h)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- COMPONENTES MODERNOS ---

  Widget _buildTopHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 30.h, 20.w, 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Equipe",
                    style: GoogleFonts.sairaCondensed(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                        fontSize: 28.sp,
                        height: 1.1)),
                Text("Gestão de Acesso",
                    style: GoogleFonts.ubuntu(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        fontSize: 12.sp)),
              ],
            ),
          ),

          // Botão Novo (Topo Direito)
          InkWell(
            onTap: () => _showStaffForm(),
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFF00A859), // Verde Marca
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A859).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.plus_bold,
                      color: Colors.white, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text("Novo",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14.sp)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModernSearchBar(bool isDark, TextEditingController controller) {
    final fillColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1);

    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: "Buscar colaborador...",
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
          prefixIcon: Icon(PhosphorIcons.magnifying_glass,
              color: isDark ? Colors.grey[400] : Colors.grey, size: 20.sp),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => controller.clear())
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
        ),
      ),
    );
  }

  Widget _buildModernChip(
      String label, String? selectedValue, bool isDark, VoidCallback onTap) {
    final hasValue = selectedValue != null;
    final activeBg = isDark ? Colors.white : Colors.black;
    final activeText = isDark ? Colors.black : Colors.white;
    final inactiveBg = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final inactiveBorder =
        isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: hasValue ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: hasValue ? activeBg : inactiveBorder),
        ),
        child: Row(
          children: [
            Text(
              hasValue ? selectedValue! : label,
              style: GoogleFonts.inter(
                  color: hasValue
                      ? activeText
                      : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.sp),
            ),
            if (!hasValue) ...[
              SizedBox(width: 4.w),
              Icon(PhosphorIcons.caret_down, size: 12.sp, color: Colors.grey),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusToggleModern(bool isDark) {
    String label = _selectedStatusFilter ?? "Status";
    bool isActive = _selectedStatusFilter == 'Ativo';
    bool isInactive = _selectedStatusFilter == 'Inativo';

    Color chipColor;
    Color textColor;

    if (isActive) {
      chipColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
    } else if (isInactive) {
      chipColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red;
    } else {
      chipColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
      textColor = isDark ? Colors.grey[300]! : Colors.grey[700]!;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedStatusFilter == 'Ativo')
            _selectedStatusFilter = 'Inativo';
          else if (_selectedStatusFilter == 'Inativo')
            _selectedStatusFilter = null;
          else
            _selectedStatusFilter = 'Ativo';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
              color: isActive
                  ? Colors.green.withOpacity(0.2)
                  : (isInactive
                      ? Colors.red.withOpacity(0.2)
                      : (isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.2)))),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp)),
      ),
    );
  }

  Widget _buildPremiumStaffCard(User user, ThemeData theme, bool isDark) {
    final bool isActive = user.status == 'Ativo';

    String mainRole = "Colaborador";
    if (user.staffProfiles.isNotEmpty)
      mainRole = user.staffProfiles.first.mainRole;
    else if (user.roles.isNotEmpty) mainRole = user.roles.first;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showActionSheet(user);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.transparent)),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // Avatar com Status Ring
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isActive ? Colors.green : Colors.red,
                        width: 2.w)),
                padding: EdgeInsets.all(2.w),
                child: StaffAvatar(
                    fullName: user.fullName, userId: user.id, radius: 24.r),
              ),

              SizedBox(width: 16.w),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                          color:
                              isDark ? Colors.white : const Color(0xFF1F2937)),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6.r)),
                          child: Text(mainRole,
                              style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800])),
                        ),
                        if (!isActive) ...[
                          SizedBox(width: 6.w),
                          Text("•  BLOQUEADO",
                              style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ]
                      ],
                    )
                  ],
                ),
              ),

              Icon(PhosphorIcons.caret_right,
                  color: Colors.grey.withOpacity(0.5), size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleSelector(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) {
        final roles = ['Professor', 'Coordenador', 'Admin', 'Staff'];
        return Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Filtrar por Cargo",
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black)),
              SizedBox(height: 20.h),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Todos",
                    style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.black87)),
                trailing: _selectedRoleFilter == null
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedRoleFilter = null);
                  Navigator.pop(ctx);
                },
              ),
              ...roles.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r,
                        style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.black87)),
                    trailing: _selectedRoleFilter == r
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _selectedRoleFilter = r);
                      Navigator.pop(ctx);
                    },
                  ))
            ],
          ),
        );
      },
    );
  }

  // Reutilizando seu componente (ou adicione aqui se precisar)
  Widget _buildActionTile(
      IconData icon, String label, VoidCallback onTap, bool isDark,
      {bool isDestructive = false}) {
    // ... (Copie do código anterior se necessário, ou use o do StaffManagementScreen)
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withOpacity(0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  shape: BoxShape.circle),
              child: Icon(icon,
                  color: isDestructive
                      ? Colors.red
                      : (isDark ? Colors.white : Colors.black87),
                  size: 20.sp),
            ),
            SizedBox(width: 16.w),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: isDestructive
                        ? Colors.red
                        : (isDark ? Colors.white : Colors.black87))),
          ],
        ),
      ),
    );
  }
}

class _GlassStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _GlassStickyHeaderDelegate(
      {required this.child, required this.minHeight, required this.maxHeight});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;
  @override
  bool shouldRebuild(_GlassStickyHeaderDelegate oldDelegate) => true;
}

class StaffAvatar extends StatelessWidget {
  final String fullName;
  final String userId;
  final double radius;
  const StaffAvatar(
      {super.key,
      required this.fullName,
      required this.userId,
      this.radius = 20});
  @override
  Widget build(BuildContext context) {
    final initials =
        fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : '?';
    final colorIndex =
        (fullName.length + initials.codeUnitAt(0)) % Colors.primaries.length;
    final color = Colors.primaries[colorIndex];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.15),
      child: Text(initials,
          style: GoogleFonts.saira(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: radius * 0.9)),
    );
  }
}
