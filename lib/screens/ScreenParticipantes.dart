import 'dart:async';
import 'dart:typed_data';

import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/model/registration_request_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:academyhub_mobile/screens/ScreenCadastroAluno.dart';
import 'package:academyhub_mobile/services/enrollment_service.dart';
import 'package:academyhub_mobile/services/notification.service.dart';
import 'package:academyhub_mobile/services/registration_request_service.dart';
import 'package:academyhub_mobile/services/student_service.dart';
import 'package:academyhub_mobile/services/websocket.dart';
import 'package:academyhub_mobile/widgets/request_details_dialog.dart';
import 'package:academyhub_mobile/widgets/student_details_popup.dart';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

class ScreenparticipantesMobile extends StatefulWidget {
  const ScreenparticipantesMobile({super.key});

  @override
  State<ScreenparticipantesMobile> createState() =>
      _ScreenparticipantesMobileState();
}

class _ScreenparticipantesMobileState extends State<ScreenparticipantesMobile>
    with SingleTickerProviderStateMixin {
  // --- Serviços ---
  final StudentService _studentService = StudentService();
  final EnrollmentService _enrollmentService = EnrollmentService();
  final RegistrationRequestService _requestService =
      RegistrationRequestService();
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription? _socketSubscription;

  // --- Estado de Controle ---
  int _selectedTabIndex = 0;
  late TabController _tabController;

  // --- Listas de Dados ---
  List<Student> _allStudents = [];
  List<Enrollment> _allActiveEnrollments = [];
  List<ClassModel> _availableClasses = [];
  List<RegistrationRequest> _pendingRequests = [];

  String? _error;
  bool _isLoading = true;

  // --- Controllers de Filtro ---
  final _searchNameController = TextEditingController();
  final _searchTutorController = TextEditingController();
  String? _selectedClassId;
  String? _selectedEnrollmentStatus;

  // --- Estado do Modal de Filtro ---
  bool _showFilterModal = false;

  bool get _hasActiveFilters =>
      _searchNameController.text.isNotEmpty ||
      _searchTutorController.text.isNotEmpty ||
      _selectedClassId != null ||
      _selectedEnrollmentStatus != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });

    _searchNameController.addListener(() => setState(() {}));
    _searchTutorController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
      _listenToSocketEvents();
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      if (mounted) {
        setState(() {
          _error = "Erro de autenticação.";
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final userSchoolId = authProvider.user?.schoolId;
      Future<void> schoolFuture = Future.value(null);

      if (userSchoolId != null && schoolProvider.school == null) {
        schoolFuture = schoolProvider.loadSchoolData(userSchoolId, token);
      }

      final results = await Future.wait([
        _studentService.getStudents(token),
        _enrollmentService.getEnrollments(token, filter: {'status': 'Ativa'}),
        Provider.of<ClassProvider>(context, listen: false).fetchClasses(token),
        schoolFuture,
      ]);

      List<RegistrationRequest> requests = [];
      try {
        requests = await _requestService.getPendingRequests(token);
      } catch (e) {
        debugPrint("Aviso: Falha ao carregar solicitações: $e");
      }

      if (mounted) {
        setState(() {
          _allStudents = List<Student>.from(results[0] as List<Student>);
          _allActiveEnrollments =
              List<Enrollment>.from(results[1] as List<Enrollment>);
          _availableClasses = List<ClassModel>.from(
              Provider.of<ClassProvider>(context, listen: false).classes);
          _availableClasses.sort((a, b) => a.name.compareTo(b.name));

          _pendingRequests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erro Fetch: $e");
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _listenToSocketEvents() {
    _socketSubscription?.cancel();
    _socketSubscription = _webSocketService.stream.listen((message) {
      final type = message['type'];
      if (type == 'NEW_REGISTRATION_REQUEST' ||
          type == 'registration:created') {
        _refreshRequestsOnly();
      }
    });
  }

  Future<void> _refreshRequestsOnly() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    try {
      final requests = await _requestService.getPendingRequests(token);
      if (mounted) setState(() => _pendingRequests = requests);
    } catch (e) {
      debugPrint("Erro ao atualizar requests via socket: $e");
    }
  }

  void _copyLink() {
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);
    final link = schoolProvider.publicRegistrationLink;
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Link não disponível no momento'),
          backgroundColor: Colors.red));
      return;
    }
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(PhosphorIcons.link, color: Colors.white),
        SizedBox(width: 10.w),
        const Text('Link de matrícula copiado!')
      ]),
      backgroundColor: Colors.indigo,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  void _handleApproveRequest(RegistrationRequest request) {
    showDialog(
      context: context,
      builder: (context) => RequestDetailsDialog(
        request: request,
        onApprove: () {
          Navigator.pop(context);
          _fetchData();
          NotificationService.instance.showApprovalSuccessNotification(
              request.studentData['fullName'] ?? 'Aluno');
        },
        onReject: () {
          Navigator.pop(context);
          _fetchData();
        },
      ),
    );
  }

  void _showStudentDetailsPopup(Student student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StudentDetailsPopup(student: student),
    ).then((value) {
      if (value == true) _fetchData();
    });
  }

  void _showCadastroAlunoPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CadastroAlunoDialog(
        onSaveSuccess: () => _fetchData(),
      ),
    );
  }

  void _toggleFilterModal() {
    setState(() {
      _showFilterModal = !_showFilterModal;
    });
  }

  @override
  void dispose() {
    _searchNameController.dispose();
    _searchTutorController.dispose();
    _socketSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<Student> _applyStudentFilters(
      List<Student> students, Map<String, Enrollment> activeEnrollmentMap) {
    final searchNome = _searchNameController.text.toLowerCase();
    final searchTutor = _searchTutorController.text.toLowerCase();

    return students.where((student) {
      final enrollment = activeEnrollmentMap[student.id];
      final isEnrolled = enrollment != null;

      final matchesNome = student.fullName.toLowerCase().contains(searchNome);
      final matchesTutor = searchTutor.isEmpty ||
          student.tutors.any((tutor) =>
              tutor.tutorInfo.fullName.toLowerCase().contains(searchTutor) ||
              tutor.tutorInfo.phoneNumber.contains(searchTutor));
      final matchesStatus = _selectedEnrollmentStatus == null ||
          (_selectedEnrollmentStatus == 'Matriculados' && isEnrolled) ||
          (_selectedEnrollmentStatus == 'Não Matriculados' && !isEnrolled);
      final matchesTurma = _selectedClassId == null ||
          (isEnrolled && enrollment.classInfo.id == _selectedClassId);

      return matchesNome && matchesTutor && matchesStatus && matchesTurma;
    }).toList();
  }

  List<RegistrationRequest> _applyRequestFilters() {
    final searchNome = _searchNameController.text.toLowerCase();
    if (searchNome.isEmpty) return _pendingRequests;
    return _pendingRequests.where((req) {
      final name = req.studentData['fullName']?.toString().toLowerCase() ?? '';
      return name.contains(searchNome);
    }).toList();
  }

  void _clearFilters() {
    _searchNameController.clear();
    _searchTutorController.clear();
    setState(() {
      _selectedClassId = null;
      _selectedEnrollmentStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cores adaptadas para mobile
    final Color textPrimary = isDark ? Colors.white : Colors.black;
    final Color textSecondary =
        isDark ? Colors.grey[400]! : const Color(0xff777F85);
    final Color scaffoldBackground =
        isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    final activeEnrollmentMap = {
      for (var e in _allActiveEnrollments) e.student.id: e
    };
    final filteredStudents =
        _applyStudentFilters(_allStudents, activeEnrollmentMap);
    final filteredRequests = _applyRequestFilters();

    return ScreenUtilInit(
      designSize: const Size(360, 800),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: scaffoldBackground,
          body: SafeArea(
            bottom: false, // Permite que a lista role por trás do menu inferior
            child: CustomScrollView(
              slivers: [
                // --- 1. HEADER (Rola com a tela) ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0.sp, 16.w,
                        0), // Top padding ajustado para a AppBar de vidro
                    child: Column(
                      children: [
                        // Título
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Participantes",
                                  style: GoogleFonts.sairaCondensed(
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    fontSize: 28.sp,
                                  ),
                                ),
                                Text(
                                  "Gerencie alunos e solicitações",
                                  style: GoogleFonts.ubuntu(
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                            // Botão de Copiar Link
                            IconButton(
                              onPressed: _copyLink,
                              icon: Icon(PhosphorIcons.link,
                                  color: theme.primaryColor, size: 24.sp),
                              tooltip: 'Copiar link de matrícula',
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),

                // --- 2. FILTROS FIXOS (Sticky Header) ---
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    minHeight: 130.h, // Altura suficiente para Tabs + Busca
                    maxHeight: 130.h,
                    child: Container(
                      color:
                          scaffoldBackground, // Fundo opaco para esconder a lista ao rolar
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 10.h),
                      child: Column(
                        children: [
                          // Tabs (Alunos / Solicitações)
                          Container(
                            height: 45.h,
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: theme.primaryColor,
                              unselectedLabelColor: textSecondary,
                              indicatorColor: theme.primaryColor,
                              indicatorWeight: 3,
                              labelStyle: GoogleFonts.inter(
                                  fontSize: 14.sp, fontWeight: FontWeight.w600),
                              tabs: [
                                Tab(text: 'Alunos'),
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Solicitações'),
                                      if (_pendingRequests.isNotEmpty) ...[
                                        SizedBox(width: 6.w),
                                        Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${_pendingRequests.length}',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 12.h),

                          // Barra de Busca e Ações
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 45.h,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _searchNameController,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black),
                                    decoration: InputDecoration(
                                      hintText: _selectedTabIndex == 0
                                          ? 'Buscar aluno...'
                                          : 'Buscar candidato...',
                                      hintStyle: TextStyle(
                                          color: textSecondary.withOpacity(0.6),
                                          fontSize: 14.sp),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(
                                          PhosphorIcons.magnifying_glass,
                                          color: textSecondary,
                                          size: 20.sp),
                                      suffixIcon: _searchNameController
                                              .text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(Icons.clear,
                                                  size: 18.sp,
                                                  color: textSecondary),
                                              onPressed: () =>
                                                  _searchNameController.clear(),
                                            )
                                          : null,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 10.h),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              // Botão Filtros Avançados (Só na aba Alunos)
                              if (_selectedTabIndex == 0)
                                InkWell(
                                  onTap: _toggleFilterModal,
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Container(
                                    height: 45.h,
                                    width: 45.h,
                                    decoration: BoxDecoration(
                                        color: _hasActiveFilters
                                            ? theme.primaryColor
                                            : (isDark
                                                ? Colors.grey[800]
                                                : Colors.white),
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: Offset(0, 2))
                                        ],
                                        border: Border.all(
                                            color: _hasActiveFilters
                                                ? Colors.transparent
                                                : Colors.grey
                                                    .withOpacity(0.3))),
                                    child: Icon(PhosphorIcons.funnel_simple,
                                        color: _hasActiveFilters
                                            ? Colors.white
                                            : textSecondary,
                                        size: 20.sp),
                                  ),
                                ),
                              SizedBox(width: 10.w),
                              // Botão Novo
                              if (_selectedTabIndex == 0)
                                InkWell(
                                  onTap: _showCadastroAlunoPopup,
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Container(
                                    height: 45.h,
                                    width: 45.h,
                                    decoration: BoxDecoration(
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                      borderRadius: BorderRadius.circular(12.r),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: Offset(0, 2))
                                      ],
                                    ),
                                    child: Icon(PhosphorIcons.plus,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                        size: 20.sp),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- 3. LISTA DE CONTEÚDO (Alunos ou Requests) ---
                if (_isLoading)
                  const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                        child: Text("Erro: $_error",
                            style: TextStyle(color: Colors.red))),
                  )
                else if (_selectedTabIndex == 0)
                  // Lista de Alunos
                  filteredStudents.isEmpty
                      ? _buildEmptyState(
                          "Nenhum aluno encontrado", textSecondary)
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final student = filteredStudents[index];
                              final enrollment =
                                  activeEnrollmentMap[student.id];
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 6.h),
                                child: _buildStudentCard(
                                    student, enrollment, theme, isDark),
                              );
                            },
                            childCount: filteredStudents.length,
                          ),
                        )
                else
                  // Lista de Solicitações
                  filteredRequests.isEmpty
                      ? _buildEmptyState(
                          "Nenhuma solicitação pendente", textSecondary)
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 6.h),
                                child: _buildRequestCard(
                                    filteredRequests[index], theme, isDark),
                              );
                            },
                            childCount: filteredRequests.length,
                          ),
                        ),

                // Espaço final para o FAB/Menu não cobrir o último item
                SliverToBoxAdapter(child: SizedBox(height: 100.h)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, Color textColor) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.magnifying_glass,
                size: 48.sp, color: Colors.grey.withOpacity(0.5)),
            SizedBox(height: 16.h),
            Text(message,
                style: GoogleFonts.inter(fontSize: 16.sp, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(
    Student student,
    Enrollment? enrollment,
    ThemeData theme,
    bool isDark,
  ) {
    final primaryTutor = student.tutors.isNotEmpty
        ? student.tutors.first.tutorInfo.fullName
        : 'Sem tutor';

    return Card(
      margin: EdgeInsets.zero, // Controlado pelo Padding do SliverList
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      color: theme.cardColor,
      child: InkWell(
        onTap: () => _showStudentDetailsPopup(student),
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudentAvatarMobile(
                studentId: student.id,
                fullName: student.fullName,
                radius: 28.r,
                fontSize: 16.sp,
                hasEnrollment: enrollment != null,
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(PhosphorIcons.user,
                            size: 14.sp, color: Colors.grey),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            primaryTutor,
                            style: GoogleFonts.inter(
                                fontSize: 13.sp, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: enrollment != null
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        enrollment != null
                            ? enrollment.classInfo.name
                            : 'Sem matrícula',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color:
                              enrollment != null ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIcons.caret_right, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    RegistrationRequest request,
    ThemeData theme,
    bool isDark,
  ) {
    final candidateName = request.studentData['fullName'] ?? 'Sem nome';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.blue.withOpacity(0.2)),
      ),
      color: isDark
          ? Colors.blue.withOpacity(0.05)
          : Colors.blue.withOpacity(0.02),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.clock,
                          size: 14.sp, color: Colors.orange),
                      SizedBox(width: 4.w),
                      Text('PENDENTE',
                          style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                ),
                Text(
                  intl.DateFormat('dd/MM HH:mm').format(request.createdAt),
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              candidateName,
              style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleApproveRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: Text("Revisar"),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApproveRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: Text("Aprovar"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- CLASSE DELEGATE PARA O HEADER FIXO ---
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _StickyHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

// --- WIDGET AVATAR MANTIDO ---
class StudentAvatarMobile extends StatelessWidget {
  final String studentId;
  final String fullName;
  final double radius;
  final double fontSize;
  final bool hasEnrollment;

  const StudentAvatarMobile({
    Key? key,
    required this.studentId,
    required this.fullName,
    required this.radius,
    required this.fontSize,
    required this.hasEnrollment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String initials = '';
    if (fullName.isNotEmpty) {
      List<String> parts = fullName.trim().split(' ');
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[parts.length - 1][0]}';
      } else {
        initials = parts[0][0];
      }
    }
    initials = initials.toUpperCase();
    final int colorIndex = initials.codeUnitAt(0) % Colors.primaries.length;
    final Color bgColor = Colors.primaries[colorIndex].shade100;
    final Color textColor = Colors.primaries[colorIndex].shade800;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final studentService = StudentService();

    return Stack(
      children: [
        FutureBuilder<Uint8List?>(
          future: studentService.getStudentPhoto(studentId, token),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircleAvatar(
                radius: radius,
                backgroundColor: bgColor,
                child: Text(initials,
                    style: GoogleFonts.saira(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return CircleAvatar(
                radius: radius,
                backgroundColor: Colors.transparent,
                backgroundImage: MemoryImage(snapshot.data!),
              );
            }
            return CircleAvatar(
              radius: radius,
              backgroundColor: bgColor,
              child: Text(initials,
                  style: GoogleFonts.saira(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            );
          },
        ),
        if (hasEnrollment)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border:
                    Border.all(color: Theme.of(context).cardColor, width: 2),
              ),
              child: Icon(Icons.check, size: 10.sp, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
