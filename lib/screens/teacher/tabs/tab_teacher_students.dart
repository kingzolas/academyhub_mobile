import 'dart:async';

import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/features/participants_dashboard_provider.dart';
import 'package:academyhub_mobile/services/horario_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

class TabTeacherStudents extends StatefulWidget {
  const TabTeacherStudents({super.key});

  @override
  State<TabTeacherStudents> createState() => _TabTeacherStudentsState();
}

class _TabTeacherStudentsState extends State<TabTeacherStudents> {
  final _searchController = TextEditingController();
  final HorarioService _horarioService = HorarioService();

  // Controle de Estado
  bool _isLoading = true;
  bool _isGridView = false; // false = Lista, true = Cards

  // Lista processada para exibição (Enrollments com Students completos)
  List<Enrollment> _filteredEnrollments = [];

  // Filtros
  String? _selectedClassFilterId;
  List<ClassModel> _teacherClassesList = [];

  @override
  void initState() {
    super.initState();
    // Inicia o carregamento assim que a tela é montada
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  /// Carrega dados completos e filtra para o professor
  Future<void> _initData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dashboardProvider =
        Provider.of<ParticipantsDashboardProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final user = auth.user;

    if (auth.token == null || user == null) return;

    try {
      if (mounted) setState(() => _isLoading = true);

      // 1. Buscar quais turmas pertencem a este professor (HorarioService)
      final mySchedules = await _horarioService
          .getHorarios(auth.token!, filter: {'teacherId': user.id});

      final myClassIds = mySchedules.map((h) => h.classInfo.id).toSet();

      // 2. Mapear os objetos das turmas para o Dropdown
      final myClassesObjects = classProvider.classes
          .where((c) => myClassIds.contains(c.id))
          .toList();

      if (mounted) {
        setState(() {
          _teacherClassesList = myClassesObjects;
        });
      }

      // 3. Buscar dados globais (Alunos Completos) via Provider
      // Se o usuário já passou pela tela de participantes, isso é instantâneo (cache).
      await dashboardProvider.fetchDashboardData(auth.token!);

      // 4. Cruzar dados: Pegar alunos globais e filtrar se estão nas turmas do professor
      _filterDataLocally(dashboardProvider, myClassIds);
    } catch (e) {
      debugPrint("Erro crítico em TabTeacherStudents: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Lógica Core: Cruza o mapa de matrículas com a lista de alunos completos
  void _filterDataLocally(
      ParticipantsDashboardProvider provider, Set<String> teacherClassIds) {
    final allStudents =
        provider.students; // Lista de Alunos Completos (Foto, CPF, Pais)
    final enrollMap =
        provider.activeEnrollmentMap; // Mapa ID Aluno -> Matrícula Ativa

    List<Enrollment> localList = [];

    for (var student in allStudents) {
      final enrollment = enrollMap[student.id];

      // Verifica se o aluno tem matrícula ativa E se a turma é do professor
      if (enrollment != null &&
          teacherClassIds.contains(enrollment.classInfo.id)) {
        // [IMPORTANTE] Aqui criamos um Enrollment Híbrido.
        // Pegamos os dados da matrícula, mas substituímos a referência do aluno
        // pelo objeto 'student' completo que veio do provider.
        localList.add(enrollment.copyWith(student: student));
      }
    }

    // Ordenação A-Z
    localList.sort((a, b) => a.student.fullName.compareTo(b.student.fullName));

    if (mounted) {
      setState(() {
        _filteredEnrollments = localList;
      });
    }
  }

  // --- Helpers de Dados ---

  String _getResponsibleName(Student student) {
    if (student.tutors.isNotEmpty) {
      // Acessa o primeiro tutor da lista e pega o nome
      return student.tutors.first.tutorInfo.fullName;
    }
    return "Não informado";
  }

  String _getMatricula(Student student) {
    return student.enrollmentNumber ?? '---';
  }

  // --- Helpers Visuais ---

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return "?";
    List<String> parts = fullName.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return "${parts.first[0]}${parts.last[0]}".toUpperCase();
  }

  Color _getAvatarColor(String fullName) {
    if (fullName.isEmpty) return Colors.grey;
    final int hash = fullName.hashCode;
    return Colors.primaries[hash.abs() % Colors.primaries.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filtragem de Interface (Busca por nome e Dropdown selecionado)
    final displayList = _filteredEnrollments.where((e) {
      final nameMatch = e.student.fullName
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());

      final classMatch = _selectedClassFilterId == null
          ? true
          : e.classInfo.id == _selectedClassFilterId;

      return nameMatch && classMatch;
    }).toList();

    final totalRecords = displayList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de Ferramentas
        _buildToolbar(totalRecords, isDark),

        SizedBox(height: 15.h),

        // Área de Conteúdo
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : displayList.isEmpty
                  ? _buildEmptyState()
                  : _isGridView
                      ? _buildGridView(isDark, displayList)
                      : _buildTableView(isDark, displayList, totalRecords),
        ),
      ],
    );
  }

  Widget _buildToolbar(int totalRecords, bool isDark) {
    final inputColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final inputBorderColor = isDark ? Colors.transparent : Colors.grey.shade300;
    final iconColor = isDark ? Colors.white70 : Colors.grey;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Row(
      children: [
        // Campo de Busca
        Expanded(
          flex: 3,
          child: Container(
            height: 45.h,
            decoration: BoxDecoration(
              color: inputColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: inputBorderColor),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            child: Row(
              children: [
                Icon(PhosphorIcons.magnifying_glass,
                    color: iconColor, size: 18.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    style: GoogleFonts.inter(color: textColor, fontSize: 13.sp),
                    cursorColor: Colors.blueAccent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: "Buscar por nome...",
                      hintStyle:
                          GoogleFonts.inter(color: iconColor, fontSize: 13.sp),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchController.clear()),
                    child: Icon(Icons.close, color: iconColor, size: 16.sp),
                  )
              ],
            ),
          ),
        ),
        SizedBox(width: 10.w),

        // Filtro de Turma (Dropdown)
        Expanded(
          flex: 2,
          child: Container(
            height: 45.h,
            decoration: BoxDecoration(
              color: inputColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: inputBorderColor),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                isExpanded: true,
                hint: Row(
                  children: [
                    Icon(PhosphorIcons.funnel, color: iconColor, size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text("Todas as Turmas",
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: textColor, fontSize: 13.sp)),
                    ),
                  ],
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text("Todas as Turmas",
                        style: GoogleFonts.inter(color: textColor)),
                  ),
                  ..._teacherClassesList.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name,
                            style: GoogleFonts.inter(color: textColor)),
                      ))
                ],
                value: _selectedClassFilterId,
                onChanged: (v) => setState(() => _selectedClassFilterId = v),
                buttonStyleData: const ButtonStyleData(height: 45),
                dropdownStyleData: DropdownStyleData(
                  decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      borderRadius: BorderRadius.circular(8.r)),
                ),
                menuItemStyleData: const MenuItemStyleData(
                    padding: EdgeInsets.symmetric(horizontal: 16)),
                iconStyleData: IconStyleData(
                    icon: Icon(Icons.keyboard_arrow_down, color: iconColor)),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),

        // Toggle View Mode (Lista/Grade)
        Container(
          height: 45.h,
          decoration: BoxDecoration(
            color: inputColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: inputBorderColor),
          ),
          child: Row(
            children: [
              _viewModeButton(
                  icon: PhosphorIcons.list_dashes,
                  isActive: !_isGridView,
                  isDark: isDark,
                  onTap: () => setState(() => _isGridView = false)),
              Container(
                  width: 1,
                  height: 25.h,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              _viewModeButton(
                  icon: PhosphorIcons.squares_four,
                  isActive: _isGridView,
                  isDark: isDark,
                  onTap: () => setState(() => _isGridView = true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewModeButton(
      {required IconData icon,
      required bool isActive,
      required bool isDark,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 45.w,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: isActive
              ? const Color(0xFF2563EB)
              : (isDark ? Colors.grey : Colors.grey.shade400),
          size: 20.sp,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.student, size: 48.sp, color: Colors.grey[300]),
          SizedBox(height: 10.h),
          Text("Nenhum aluno encontrado.",
              style: TextStyle(color: Colors.grey, fontSize: 16.sp)),
        ],
      ),
    );
  }

  // --- VIEW: TABELA (LISTA) ---
  Widget _buildTableView(bool isDark, List<Enrollment> students, int total) {
    final headerStyle = GoogleFonts.inter(
        fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.black87);

    return Column(
      children: [
        // Cabeçalho
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
          ),
          child: Row(
            children: [
              SizedBox(
                  width: 50.w,
                  child: Center(child: Text("#", style: headerStyle))),
              SizedBox(
                  width: 60.w,
                  child: Center(child: Text("Foto", style: headerStyle))),
              Expanded(
                  flex: 3, child: Text("Nome / Matrícula", style: headerStyle)),
              Expanded(
                  flex: 3,
                  child: Text("Responsável / CPF", style: headerStyle)),
              Expanded(flex: 1, child: Text("Turma", style: headerStyle)),
              SizedBox(
                  width: 80.w,
                  child: Center(child: Text("Ações", style: headerStyle))),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: ListView.separated(
            itemCount: students.length,
            separatorBuilder: (ctx, i) =>
                Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
            itemBuilder: (context, index) {
              final item = students[index];
              final student = item.student;
              final displayIndex = total - index;

              final rowColor = index % 2 == 0
                  ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                  : (isDark
                      ? const Color(0xFF252525)
                      : const Color(0xFFF9F9F9));

              final classObj = _teacherClassesList
                  .firstWhereOrNull((c) => c.id == item.classInfo.id);
              final className = classObj?.name ?? "---";

              // DADOS COMPLETOS (Garantido pelo Provider)
              final matricula = _getMatricula(student);
              final responsavel = _getResponsibleName(student);
              final cpf = (student.cpf != null && student.cpf!.isNotEmpty)
                  ? student.cpf!
                  : "CPF n/d";
              final avatarColor = _getAvatarColor(student.fullName);

              return Container(
                height: 75.h,
                color: rowColor,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Row(
                  children: [
                    // Índice
                    SizedBox(
                      width: 50.w,
                      child: Center(
                        child: Text("$displayIndex",
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ),
                    ),

                    // Foto / Avatar Colorido
                    SizedBox(
                      width: 60.w,
                      child: Center(
                        child: CircleAvatar(
                          radius: 20.r,
                          backgroundColor: avatarColor.withOpacity(0.2),
                          child: Text(
                            _getInitials(student.fullName),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                color: avatarColor),
                          ),
                        ),
                      ),
                    ),

                    // Nome e Matrícula
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp,
                                  color:
                                      isDark ? Colors.white : Colors.black87)),
                          SizedBox(height: 2.h),
                          Text("Mat: $matricula",
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 11.sp, color: Colors.grey)),
                        ],
                      ),
                    ),

                    // Responsável e CPF
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(PhosphorIcons.user,
                                  size: 14.sp, color: Colors.grey),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(responsavel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontSize: 12.sp,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87)),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Icon(PhosphorIcons.identification_card,
                                  size: 14.sp, color: Colors.grey),
                              SizedBox(width: 4.w),
                              Text(cpf,
                                  style: GoogleFonts.inter(
                                      fontSize: 11.sp, color: Colors.grey)),
                            ],
                          )
                        ],
                      ),
                    ),

                    // Turma
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.r)),
                          child: Text(className,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: const Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.sp)),
                        ),
                      ),
                    ),

                    // Botão Ação
                    SizedBox(
                      width: 80.w,
                      child: IconButton(
                        icon: Icon(PhosphorIcons.caret_right_bold,
                            size: 18.sp, color: const Color(0xFF2563EB)),
                        onPressed: () => _showDetails(context, item, className),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- VIEW: GRADE (CARDS) ---
  Widget _buildGridView(bool isDark, List<Enrollment> students) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsividade do Grid
        int crossAxisCount = 2;
        if (constraints.maxWidth > 600) crossAxisCount = 3;
        if (constraints.maxWidth > 900) crossAxisCount = 4;

        return GridView.builder(
          padding: EdgeInsets.only(bottom: 20.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: 15.w,
            mainAxisSpacing: 15.h,
          ),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final item = students[index];
            final student = item.student;
            final avatarColor = _getAvatarColor(student.fullName);
            final matricula = _getMatricula(student);
            final classObj = _teacherClassesList
                .firstWhereOrNull((c) => c.id == item.classInfo.id);
            final className = classObj?.name ?? "---";

            return GestureDetector(
              onTap: () => _showDetails(context, item, className),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                  border: Border.all(
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar Grande
                    Hero(
                      tag: 'student_avatar_${student.id}',
                      child: CircleAvatar(
                        radius: 35.r,
                        backgroundColor: avatarColor.withOpacity(0.2),
                        child: Text(
                          _getInitials(student.fullName),
                          style: GoogleFonts.inter(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: avatarColor),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Nome do Aluno
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Text(
                        student.fullName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827)),
                      ),
                    ),

                    SizedBox(height: 4.h),
                    // Matrícula
                    Text("Mat: $matricula",
                        style: GoogleFonts.inter(
                            fontSize: 11.sp, color: Colors.grey)),

                    SizedBox(height: 6.h),

                    // Chip da Turma
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4.r)),
                      child: Text(className,
                          style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color:
                                  isDark ? Colors.grey : Colors.grey.shade700)),
                    ),

                    const Spacer(),
                    Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200),

                    // Botão Ver Detalhes
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF252525)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(12.r))),
                      child: Text("Ver Detalhes",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp)),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL DE DETALHES ---
  void _showDetails(
      BuildContext context, Enrollment enrollment, String className) {
    final student = enrollment.student;
    final avatarColor = _getAvatarColor(student.fullName);
    final matricula = _getMatricula(student);
    final responsavel = _getResponsibleName(student);

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
              height: 650.h,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              padding: EdgeInsets.all(30.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2)))),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Hero(
                        tag: 'student_avatar_${student.id}',
                        child: CircleAvatar(
                          radius: 35.r,
                          backgroundColor: avatarColor.withOpacity(0.2),
                          child: Text(
                            _getInitials(student.fullName),
                            style: TextStyle(
                                fontSize: 28.sp,
                                color: avatarColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(width: 15.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.fullName,
                                style: GoogleFonts.inter(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold)),
                            Text("Matrícula: $matricula",
                                style: GoogleFonts.inter(
                                    color: Colors.grey, fontSize: 13.sp)),
                            SizedBox(height: 5.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF22C55E).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4.r)),
                              child: Text("Status: ${enrollment.status}",
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF22C55E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.sp)),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 25.h),
                  const Divider(),
                  SizedBox(height: 15.h),
                  Text("Dados Acadêmicos & Pessoais",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 16.sp)),
                  SizedBox(height: 15.h),
                  Expanded(
                    child: ListView(
                      children: [
                        _detailItem(PhosphorIcons.chalkboard_teacher,
                            "Turma Atual", className),
                        _detailItem(PhosphorIcons.identification_card, "CPF",
                            student.cpf ?? "Não cadastrado"),
                        _detailItem(
                            PhosphorIcons.calendar,
                            "Data de Nascimento",
                            "${student.birthDate.day}/${student.birthDate.month}/${student.birthDate.year}"),
                        _detailItem(PhosphorIcons.users,
                            "Responsável Principal", responsavel),
                        _detailItem(PhosphorIcons.phone, "Contato",
                            student.phoneNumber ?? "N/A"),
                        _detailItem(
                            PhosphorIcons.first_aid,
                            "Saúde",
                            student.healthInfo.hasHealthProblem
                                ? "Possui restrições"
                                : "Sem restrições declaradas"),
                        _detailItem(PhosphorIcons.map_pin, "Endereço",
                            "${student.address.street}, ${student.address.number}"),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(PhosphorIcons.pencil_simple, size: 20.sp),
                      label: Text("Editar Cadastro Completo"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r))),
                    ),
                  )
                ],
              ),
            ));
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r)),
            child: Icon(icon, size: 20.sp, color: Colors.grey[700]),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey)),
                SizedBox(height: 2.h),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
