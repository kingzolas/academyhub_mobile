import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/invoice_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:academyhub_mobile/providers/theme_provider.dart';
import 'package:academyhub_mobile/screens/guardian_activities_screen.dart';
import 'package:academyhub_mobile/screens/guardian_attendance_screen.dart';
import 'package:academyhub_mobile/screens/guardian_schedule_screen.dart';
import 'package:academyhub_mobile/services/guardian_auth_service.dart';
import 'package:academyhub_mobile/widgets/custom_bottom_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class GuardianPortalScreen extends StatefulWidget {
  const GuardianPortalScreen({super.key});

  @override
  State<GuardianPortalScreen> createState() => _GuardianPortalScreenState();
}

class _GuardianPortalScreenState extends State<GuardianPortalScreen> {
  final GuardianAuthService _guardianAuthService = GuardianAuthService();

  int _currentIndex = 0;
  GuardianPortalHomeData? _portalHome;
  bool _isPortalLoading = false;
  String? _portalError;
  String? _selectedStudentId;

  String get _currentSectionLabel {
    switch (_currentIndex) {
      case 1:
        return 'Acompanhar';
      case 2:
        return 'Financeiro';
      case 3:
        return 'Conta';
      case 0:
      default:
        return 'Início';
    }
  }

  GuardianLinkedStudent? get _selectedStudent {
    final home = _portalHome;
    if (home == null) return null;
    final selectedId = (_selectedStudentId ?? '').trim();
    if (selectedId.isEmpty) return home.selectedStudent;

    for (final student in home.linkedStudents) {
      if (student.id == selectedId) {
        return student;
      }
    }
    return home.selectedStudent;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshGuardianPortal();
    });
  }

  Future<void> _refreshGuardianPortal() async {
    final auth = context.read<AuthProvider>();
    final preferredStudentId = (_selectedStudentId ??
            auth.guardianSelectedStudentId ??
            auth.guardianSession?.defaultStudent?.id)
        ?.trim();

    await _loadGuardianPortalData(studentId: preferredStudentId);
    await _loadGuardianInvoices(studentId: _selectedStudentId);
  }

  Future<void> _loadGuardianPortalData({String? studentId}) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    if (token == null || token.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _portalHome = null;
        _portalError =
            'Sua sessão expirou. Entre novamente para acompanhar o aluno.';
        _isPortalLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isPortalLoading = true;
        _portalError = null;
      });
    }

    try {
      final result = await _guardianAuthService.getGuardianPortalHome(
        token: token,
        studentId: studentId,
      );
      final preferredStudentId =
          (studentId ?? auth.guardianSelectedStudentId ?? '').trim();
      final resolvedStudentId = result.linkedStudents.any(
        (student) => student.id == preferredStudentId,
      )
          ? preferredStudentId
          : (result.selectedStudent?.id ??
              (result.linkedStudents.isNotEmpty
                  ? result.linkedStudents.first.id
                  : null));

      if (!mounted) return;
      setState(() {
        _portalHome = result;
        _selectedStudentId = resolvedStudentId;
        _isPortalLoading = false;
      });

      await auth.setGuardianSelectedStudentId(resolvedStudentId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _portalError = e.toString().replaceFirst('Exception: ', '');
        _isPortalLoading = false;
      });
    }
  }

  Future<void> _loadGuardianInvoices({String? studentId}) async {
    final auth = context.read<AuthProvider>();
    final invoices = context.read<InvoiceProvider>();

    if (auth.token == null || auth.token!.isEmpty) {
      invoices.setError(
        'Sua sessão expirou. Entre novamente para visualizar os boletos.',
      );
      return;
    }

    await invoices.fetchGuardianInvoices(
      token: auth.token!,
      studentId: studentId,
    );
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _copyInvoiceCode(Invoice invoice) async {
    final code = _resolveInvoiceCode(invoice);
    if (code == null || code.isEmpty) {
      _showFeedback('Este boleto não possui código disponível para cópia.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _showFeedback('Código do boleto copiado com sucesso.');
  }

  Future<void> _openInvoiceBoleto(Invoice invoice) async {
    final auth = context.read<AuthProvider>();
    final invoices = context.read<InvoiceProvider>();

    try {
      if ((invoice.boletoUrl ?? '').trim().isNotEmpty) {
        final opened = await launchUrl(
          Uri.parse(invoice.boletoUrl!.trim()),
          mode: LaunchMode.externalApplication,
        );

        if (!opened && mounted) {
          _showFeedback('Não foi possível abrir o boleto.');
        }
        return;
      }

      if (auth.token == null || auth.token!.isEmpty) {
        _showFeedback(
          'Sua sessão expirou. Entre novamente para baixar o boleto.',
        );
        return;
      }

      await invoices.generateGuardianBatchPdf(
        invoiceIds: [invoice.id],
        token: auth.token!,
        studentId: _selectedStudent?.id,
      );

      if (!mounted) return;
      if (invoices.error != null) {
        _showFeedback(invoices.error!);
      }
    } catch (_) {
      if (!mounted) return;
      _showFeedback('Não foi possível abrir ou baixar o boleto.');
    }
  }

  Future<void> _openScheduleScreen() async {
    final student = _selectedStudent;
    if (student == null) {
      _showFeedback('Nenhum aluno vinculado foi encontrado neste acesso.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuardianScheduleScreen(student: student),
      ),
    );
  }

  Future<void> _openAttendanceScreen() async {
    final student = _selectedStudent;
    if (student == null) {
      _showFeedback('Nenhum aluno vinculado foi encontrado neste acesso.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuardianAttendanceScreen(student: student),
      ),
    );
  }

  Future<void> _openActivitiesScreen() async {
    final student = _selectedStudent;
    if (student == null) {
      _showFeedback('Nenhum aluno vinculado foi encontrado neste acesso.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuardianActivitiesScreen(student: student),
      ),
    );
  }

  Future<void> _showStudentPicker() async {
    final students =
        _portalHome?.linkedStudents ?? const <GuardianLinkedStudent>[];
    if (students.length < 2) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _guardianSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (context) {
        final primaryText = _guardianTextPrimary(context);
        final secondaryText = _guardianTextSecondary(context);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: _guardianBorder(context),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Trocar aluno',
                  style: GoogleFonts.inter(
                    color: primaryText,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Escolha quem você quer acompanhar agora.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    color: secondaryText,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 12.h),
                ...students.map(
                  (student) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _GuardianStudentOptionTile(
                      student: student,
                      selected: student.id == _selectedStudent?.id,
                      onTap: () async {
                        Navigator.of(context).pop();
                        setState(() => _selectedStudentId = student.id);
                        await context
                            .read<AuthProvider>()
                            .setGuardianSelectedStudentId(student.id);
                        await _loadGuardianPortalData(studentId: student.id);
                        await _loadGuardianInvoices(studentId: student.id);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPinSecurityInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _guardianSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 28.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: _guardianBorder(context),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  'Segurança em preparação',
                  style: GoogleFonts.inter(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: _guardianTextPrimary(context),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'A alteração de PIN por e-mail ainda depende de um fluxo seguro no backend para envio e validação do código.',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: _guardianTextSecondary(context),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: _guardianSoftSurface(context),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: _guardianBorder(context)),
                  ),
                  child: Text(
                    'Assim que esse backend estiver pronto, esta área poderá enviar um código para o e-mail verificado do responsável e permitir a definição de um novo PIN.',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: _guardianTextSecondary(context),
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF00A859),
                      foregroundColor: Colors.white,
                      minimumSize: Size.fromHeight(46.h),
                    ),
                    child: const Text('Entendi'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  PreferredSizeWidget _buildLegacyAppBar(GuardianSession? session) {
    /*
      if ((student?.classInfo?.name ?? '').trim().isNotEmpty)
        student!.classInfo!.name,
      if ((student?.classInfo?.shift ?? '').trim().isNotEmpty)
        student!.classInfo!.shift,
      if ((student?.relationship ?? '').trim().isNotEmpty)
        student!.relationship,
    ].join(' · ');
    final subtitle = studentContext.isNotEmpty
        ? studentContext
        : (schoolName.isNotEmpty ? schoolName : 'Academy Hub');
    */
    final isDark = _isDarkContext(context);

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 66.h,
      automaticallyImplyLeading: false,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: _guardianAppBarBackground(context),
          border: Border(
            bottom: BorderSide(color: _guardianBorder(context)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Portal do responsável',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: _guardianTextSecondary(context),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _currentSectionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _guardianTextPrimary(context),
                        fontSize: 18.sp,
                        fontFamily: 'GR Milesons Three',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(GuardianSession? session) {
    final isDark = _isDarkContext(context);

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 54.h,
      automaticallyImplyLeading: false,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: _guardianAppBarBackground(context),
          border: Border(
            bottom: BorderSide(color: _guardianBorder(context)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 3.h, 20.w, 4.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Responsável',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: _guardianTextSecondary(context),
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  _currentSectionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _guardianTextPrimary(context),
                    fontSize: 16.5.sp,
                    fontFamily: 'GR Milesons Three',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    GuardianSession? session,
    InvoiceProvider invoiceProvider,
  ) {
    final invoiceGroups = _invoiceGroups(invoiceProvider.guardianInvoices);
    final home = _portalHome;
    final selectedStudent = _selectedStudent;

    return RefreshIndicator(
      color: const Color(0xFF00A859),
      onRefresh: _refreshGuardianPortal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 84.h, 20.w, 128.h),
        children: [
          _buildHeaderBlock(
            title: 'Resumo do dia',
            subtitle: selectedStudent == null
                ? 'Veja rapidamente aula, frequência, atividades e o financeiro do aluno.'
                : 'Acompanhe os principais sinais do dia de ${selectedStudent.firstName} em poucos toques.',
          ),
          SizedBox(height: 14.h),
          if (selectedStudent == null && _isPortalLoading)
            const _GuardianLoadingCard(
              label: 'Carregando o contexto do aluno...',
            )
          else if (selectedStudent == null)
            const _EmptyStateCard(
              title: 'Nenhum aluno disponível',
              message:
                  'Quando houver um vínculo acadêmico ativo para este acesso, ele aparecerá aqui.',
            ),
          SizedBox(height: 14.h),
          if (_portalError != null && home == null)
            _ErrorCard(
              message: _portalError!,
              onRetry: _refreshGuardianPortal,
            )
          else if (_isPortalLoading && home == null)
            Column(
              children: [
                const _GuardianLoadingCard(
                  label: 'Atualizando aula atual e resumos acadêmicos...',
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    const Expanded(
                      child: _GuardianLoadingCard(label: 'Frequência'),
                    ),
                    SizedBox(width: 10.w),
                    const Expanded(
                      child: _GuardianLoadingCard(label: 'Atividades'),
                    ),
                  ],
                ),
              ],
            )
          else ...[
            _GuardianLessonSummaryCard(
              schedule: home?.schedule,
              onOpenSchedule: _openScheduleScreen,
            ),
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _GuardianHomeSummaryCard(
                    title: 'Frequência',
                    accentColor: _attendanceAccent(
                      home?.attendance.summary.attentionLevel,
                    ),
                    icon: PhosphorIcons.check_circle_fill,
                    headline:
                        '${home?.attendance.summary.presenceRate.toStringAsFixed(0) ?? '0'}%',
                    subtitle: _buildAttendanceHomeSubtitle(
                      home?.attendance.summary,
                    ),
                    actionLabel: 'Ver detalhes',
                    onTap: _openAttendanceScreen,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _GuardianHomeSummaryCard(
                    title: 'Atividades',
                    accentColor: const Color(0xFF2F80ED),
                    icon: PhosphorIcons.notepad_fill,
                    headline: _buildActivitiesHomeHeadline(
                      home?.activitiesSummary,
                    ),
                    subtitle: _buildActivitiesHomeSubtitle(
                      home?.activitiesSummary,
                    ),
                    actionLabel: 'Ver atividades',
                    onTap: _openActivitiesScreen,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 14.h),
          _buildSectionLabel('Resumo do portal'),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _PortalShortcutCard(
                  title: 'Acompanhar',
                  subtitle: 'Grade, frequência e atividades',
                  icon: PhosphorIcons.book_open_fill,
                  color: const Color(0xFF2F80ED),
                  onTap: () => _onTabTapped(1),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _PortalShortcutCard(
                  title: 'Financeiro',
                  subtitle: 'Boleto do mês e histórico',
                  icon: PhosphorIcons.money_fill,
                  color: const Color(0xFF00A859),
                  onTap: () => _onTabTapped(2),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _buildSectionLabel('Financeiro em destaque'),
          SizedBox(height: 10.h),
          if (invoiceProvider.error != null &&
              invoiceProvider.error!.trim().isNotEmpty)
            _ErrorCard(
              message: invoiceProvider.error!,
              onRetry: _loadGuardianInvoices,
            )
          else if (invoiceGroups.featured != null)
            _PortalFinanceSpotlight(
              invoice: invoiceGroups.featured!,
              onOpenFinance: () => _onTabTapped(2),
              onCopyCode: () => _copyInvoiceCode(invoiceGroups.featured!),
              onOpenBoleto: () => _openInvoiceBoleto(invoiceGroups.featured!),
            )
          else
            const _EmptyStateCard(
              title: 'Nenhuma cobrança urgente',
              message:
                  'Quando houver um boleto vencido ou o próximo vencimento, ele aparecerá aqui.',
            ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Pendentes',
                  count: invoiceGroups.pending.length,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricCard(
                  label: 'Em atraso',
                  count: invoiceGroups.overdue.length,
                  color: const Color(0xFFEF4444),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricCard(
                  label: 'Pagos',
                  count: invoiceGroups.paid.length,
                  color: const Color(0xFF00A859),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTab() {
    final home = _portalHome;
    final selectedStudent = _selectedStudent;

    return RefreshIndicator(
      color: const Color(0xFF00A859),
      onRefresh: _refreshGuardianPortal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 84.h, 20.w, 128.h),
        children: [
          _buildHeaderBlock(
            title: 'Acompanhar',
            subtitle: selectedStudent == null
                ? 'Entre nas áreas acadêmicas com uma visão clara do que está acontecendo agora.'
                : 'Abra grade, frequência e atividades de ${selectedStudent.firstName} sem perder o contexto atual.',
          ),
          SizedBox(height: 18.h),
          if (selectedStudent == null && _isPortalLoading)
            const _GuardianLoadingCard(
              label: 'Carregando dados de acompanhamento...',
            )
          else if (selectedStudent == null)
            const _EmptyStateCard(
              title: 'Sem contexto acadêmico',
              message:
                  'Assim que houver um aluno vinculado a este acesso, o acompanhamento ficará disponível aqui.',
            ),
          SizedBox(height: 18.h),
          if (_portalError != null && home == null)
            _ErrorCard(
              message: _portalError!,
              onRetry: _refreshGuardianPortal,
            )
          else ...[
            _GuardianHubCard(
              title: 'Grade e horários',
              icon: PhosphorIcons.clock_fill,
              accent: const Color(0xFF2F80ED),
              description: _buildScheduleHubDescription(home?.schedule),
              footnote: 'Veja aula atual, próxima aula e a semana completa.',
              onTap: _openScheduleScreen,
            ),
            SizedBox(height: 12.h),
            _GuardianHubCard(
              title: 'Frequência',
              icon: PhosphorIcons.check_circle_fill,
              accent:
                  _attendanceAccent(home?.attendance.summary.attentionLevel),
              description: _buildAttendanceHomeSubtitle(
                home?.attendance.summary,
              ),
              footnote:
                  'Consulte o percentual de presença e os registros recentes.',
              onTap: _openAttendanceScreen,
            ),
            SizedBox(height: 12.h),
            _GuardianHubCard(
              title: 'Atividades',
              icon: PhosphorIcons.notepad_fill,
              accent: const Color(0xFF7C3AED),
              description: _buildActivitiesHubDescription(
                home?.activitiesSummary,
              ),
              footnote: 'Acompanhe entregas, pendências e atividades recentes.',
              onTap: _openActivitiesScreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanceTab(
    GuardianSession? session,
    InvoiceProvider invoiceProvider,
  ) {
    final invoiceGroups = _invoiceGroups(invoiceProvider.guardianInvoices);

    return RefreshIndicator(
      color: const Color(0xFF00A859),
      onRefresh: _refreshGuardianPortal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 84.h, 20.w, 128.h),
        children: [
          _buildHeaderBlock(
            title: 'Financeiro',
            subtitle:
                'Acompanhe seus boletos, veja prioridades e resolva tudo com o código correto e abertura rápida do PDF.',
          ),
          SizedBox(height: 18.h),
          if (invoiceProvider.error != null &&
              invoiceProvider.error!.trim().isNotEmpty)
            _ErrorCard(
              message: invoiceProvider.error!,
              onRetry: _loadGuardianInvoices,
            )
          else if (invoiceGroups.featured == null && !invoiceProvider.isLoading)
            _EmptyStateCard(
              title: 'Tudo em dia',
              message: (session?.linkedStudentsCount ?? 0) > 0
                  ? 'Não encontramos boletos pendentes para esta conta neste momento.'
                  : 'Assim que existirem cobranças vinculadas a este acesso, elas aparecerão aqui.',
            )
          else if (invoiceGroups.featured != null)
            _buildFeaturedCard(invoiceGroups.featured!),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Pendentes',
                  count: invoiceGroups.pending.length,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricCard(
                  label: 'Em atraso',
                  count: invoiceGroups.overdue.length,
                  color: const Color(0xFFEF4444),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricCard(
                  label: 'Pagos',
                  count: invoiceGroups.paid.length,
                  color: const Color(0xFF00A859),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildInvoiceSection('Em atraso', invoiceGroups.overdue),
          SizedBox(height: 16.h),
          _buildInvoiceSection('Pendentes', invoiceGroups.pending),
          SizedBox(height: 16.h),
          _buildInvoiceSection(
            'Pagos',
            invoiceGroups.paid.take(4).toList(),
            showPaidAccent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTab(AuthProvider auth, GuardianSession? session) {
    final themeProvider = context.watch<ThemeProvider>();
    final schoolProvider = context.watch<SchoolProvider>();
    final providerSchool = schoolProvider.currentSchool;
    final sessionSchoolName = (session?.schoolName ?? '').trim();
    final resolvedSchoolName = sessionSchoolName.isNotEmpty
        ? sessionSchoolName
        : ((providerSchool?.name ?? '').trim().isNotEmpty
            ? providerSchool!.name
            : 'Academy Hub');
    final providerMatchesSession = providerSchool != null &&
        ((session?.schoolPublicId ?? '').trim().isNotEmpty
            ? providerSchool.publicIdentifier == session!.schoolPublicId
            : providerSchool.name.trim().toLowerCase() ==
                resolvedSchoolName.toLowerCase());
    final schoolLogoBytes =
        providerMatchesSession ? providerSchool.logoBytes : null;
    final currentStudent = _selectedStudent;
    final linkedStudentsCount = session?.linkedStudentsCount ?? 0;
    final currentStudentLabel = currentStudent == null
        ? 'Nenhum aluno selecionado'
        : [
            currentStudent.fullName,
            if ((currentStudent.classInfo?.name ?? '').trim().isNotEmpty)
              currentStudent.classInfo!.name,
          ].join(' · ');

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 84.h, 20.w, 128.h),
      children: [
        _buildHeaderBlock(
          title: 'Conta e preferências',
          subtitle:
              'Ajuste aparência, segurança e sessão do seu acesso sem mexer no contexto acadêmico do portal.',
        ),
        SizedBox(height: 18.h),
        _GuardianAccountContextCard(
          schoolName: resolvedSchoolName,
          schoolLogoBytes: schoolLogoBytes,
          currentStudent: currentStudent,
          linkedStudentsCount: linkedStudentsCount,
        ),
        SizedBox(height: 14.h),
        _SettingsSectionCard(
          title: 'Contexto atual',
          subtitle:
              'Troque o aluno acompanhado sem sair do portal quando precisar.',
          child: Column(
            children: [
              _SettingsActionRow(
                icon: PhosphorIcons.student_fill,
                title: linkedStudentsCount > 1 ? 'Trocar aluno' : 'Aluno atual',
                subtitle: currentStudentLabel,
                badgeLabel: linkedStudentsCount > 1 ? 'Alternar' : null,
                onTap: linkedStudentsCount > 1 ? _showStudentPicker : null,
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        _SettingsSectionCard(
          title: 'Conta',
          child: Column(
            children: [
              _SettingsInfoRow(
                icon: PhosphorIcons.identification_card_fill,
                label: 'Identificador',
                value: session?.identifierMasked ?? '--',
              ),
              _SettingsInfoRow(
                icon: PhosphorIcons.users_three_fill,
                label: 'Alunos vinculados',
                value: '$linkedStudentsCount',
              ),
              const _SettingsInfoRow(
                icon: PhosphorIcons.envelope_simple_fill,
                label: 'E-mail para recuperação',
                value:
                    'Disponível quando o backend validar o endereço do responsável.',
                helper:
                    'Ainda não há um fluxo seguro publicado para envio de código por e-mail.',
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        _SettingsSectionCard(
          title: 'Aparência',
          subtitle:
              'Use o mesmo sistema de tema já disponível no restante do app.',
          child: _ThemeModeSelector(
            themeMode: themeProvider.themeMode,
            onThemeModeSelected: themeProvider.setThemeMode,
          ),
        ),
        SizedBox(height: 14.h),
        _SettingsSectionCard(
          title: 'Segurança',
          child: Column(
            children: [
              _SettingsInfoRow(
                icon: PhosphorIcons.shield_check_fill,
                label: 'Status do acesso',
                value: _buildAccessStatusLabel(session?.status ?? 'active'),
              ),
              _SettingsActionRow(
                icon: PhosphorIcons.password_fill,
                title: 'Alterar PIN',
                subtitle:
                    'Este fluxo vai usar código por e-mail assim que o backend publicar a validação segura.',
                badgeLabel: 'Em breve',
                onTap: _showPinSecurityInfo,
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        _SettingsSectionCard(
          title: 'Sessão',
          child: Column(
            children: [
              SizedBox(height: 2.h),
              SizedBox(
                height: 48.h,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => auth.logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B1F24),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Encerrar sessão',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBlock({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: _guardianTextPrimary(context),
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w500,
            color: _guardianTextSecondary(context),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: _guardianTextPrimary(context),
      ),
    );
  }

  void _showInvoiceDetails(Invoice invoice) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _guardianSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 28.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: _guardianBorder(context),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                SizedBox(height: 22.h),
                Text(
                  'Detalhes do boleto',
                  style: GoogleFonts.inter(
                    color: _guardianTextPrimary(context),
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12.h),
                _InfoCard(label: 'Descrição', value: invoice.description),
                SizedBox(height: 10.h),
                _InfoCard(
                  label: 'Referência',
                  value: _buildReferenceLabel(invoice),
                ),
                SizedBox(height: 10.h),
                _InfoCard(
                  label: 'Valor',
                  value: _formatCurrency(invoice.value),
                ),
                SizedBox(height: 10.h),
                _InfoCard(
                  label: 'Vencimento',
                  value: _buildDate(invoice.dueDate),
                ),
                SizedBox(height: 10.h),
                _InfoCard(
                  label: 'Status',
                  value: _buildStatusLabel(_resolveInvoiceState(invoice)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturedCard(Invoice invoice) {
    final state = _resolveInvoiceState(invoice);
    final accent = _buildStatusColor(state);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: _isDarkContext(context) ? 0.18 : 0.14),
            _guardianSurface(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusChip(label: _buildFeaturedLabel(state), color: accent),
          SizedBox(height: 14.h),
          Text(
            _buildReferenceLabel(invoice),
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _guardianTextSecondary(context),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            invoice.description,
            style: GoogleFonts.inter(
              color: _guardianTextPrimary(context),
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            _formatCurrency(invoice.value),
            style: GoogleFonts.inter(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: _guardianTextPrimary(context),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _buildDueText(invoice),
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: _guardianTextSecondary(context),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyInvoiceCode(invoice),
                  icon: Icon(PhosphorIcons.copy_simple, size: 16.sp),
                  label: const Text('Copiar código'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openInvoiceBoleto(invoice),
                  icon: Icon(PhosphorIcons.download_simple, size: 16.sp),
                  label: const Text('Abrir boleto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSection(
    String title,
    List<Invoice> items, {
    bool showPaidAccent = false,
  }) {
    if (items.isEmpty) {
      return _EmptyStateCard(
        title: '$title sem itens',
        message: title == 'Pagos'
            ? 'Os boletos pagos mais recentes aparecerão aqui.'
            : 'Quando houver boletos nesta categoria, eles aparecerão nesta seção.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: _guardianTextPrimary(context),
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10.h),
        ...items.map(
          (invoice) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _InvoiceListTileCard(
              invoice: invoice,
              highlightPaid: showPaidAccent,
              onCopyCode: () => _copyInvoiceCode(invoice),
              onOpenBoleto: () => _openInvoiceBoleto(invoice),
              onDetails: () => _showInvoiceDetails(invoice),
            ),
          ),
        ),
      ],
    );
  }

  _GuardianInvoiceGroups _invoiceGroups(List<Invoice> invoices) {
    final overdue = _sortInvoices(
      invoices.where(
        (invoice) => _resolveInvoiceState(invoice) == _InvoiceState.overdue,
      ),
    );
    final pending = _sortInvoices(
      invoices.where(
        (invoice) => _resolveInvoiceState(invoice) == _InvoiceState.pending,
      ),
    );
    final paid = _sortInvoices(
      invoices.where(
        (invoice) => _resolveInvoiceState(invoice) == _InvoiceState.paid,
      ),
      descending: true,
    );

    final featured = overdue.isNotEmpty
        ? overdue.first
        : pending.isNotEmpty
            ? pending.first
            : null;

    return _GuardianInvoiceGroups(
      overdue: overdue,
      pending: pending,
      paid: paid,
      featured: featured,
    );
  }

  String? _resolveInvoiceCode(Invoice invoice) {
    final digitable = _digitsOnly(invoice.boletoDigitableLine);
    if (digitable.length == 47) {
      return digitable;
    }

    final barcode = _digitsOnly(invoice.boletoBarcode);
    if (barcode.length == 47) {
      return barcode;
    }
    if (barcode.length == 44) {
      return _convertToDigitableLine(barcode) ?? barcode;
    }
    if (barcode.isNotEmpty) {
      return barcode;
    }
    return null;
  }

  String _digitsOnly(String? value) {
    return (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? _convertToDigitableLine(String rawBarcode) {
    final barcode = _digitsOnly(rawBarcode);
    if (barcode.length != 44) return null;

    int mod10(String block) {
      int sum = 0;
      bool multiplyBy2 = true;
      for (int i = block.length - 1; i >= 0; i--) {
        final digit = int.parse(block[i]);
        final multiplied = digit * (multiplyBy2 ? 2 : 1);
        sum += multiplied > 9
            ? (multiplied ~/ 10) + (multiplied % 10)
            : multiplied;
        multiplyBy2 = !multiplyBy2;
      }
      final remainder = sum % 10;
      final dv = 10 - remainder;
      return dv == 10 ? 0 : dv;
    }

    final field1Base = barcode.substring(0, 4) + barcode.substring(19, 24);
    final field2Base = barcode.substring(24, 34);
    final field3Base = barcode.substring(34, 44);
    return '$field1Base${mod10(field1Base)}'
        '$field2Base${mod10(field2Base)}'
        '$field3Base${mod10(field3Base)}'
        '${barcode.substring(4, 5)}${barcode.substring(5, 19)}';
  }

  String _buildScheduleHubDescription(GuardianScheduleSnapshot? schedule) {
    if (schedule?.currentClass != null) {
      return 'Aula em andamento: ${schedule!.currentClass!.subjectName} · ${schedule.currentClass!.timeLabel}';
    }
    if (schedule?.nextClass != null) {
      return 'Próxima aula: ${schedule!.nextClass!.subjectName} · ${schedule.nextClass!.timeLabel}';
    }
    return 'Sem aulas em destaque no momento.';
  }

  String _buildAttendanceHomeSubtitle(GuardianAttendanceSummary? summary) {
    if (summary == null || summary.totalRecords == 0) {
      return 'Ainda não há registros suficientes para resumir a frequência.';
    }

    final recentAbsences = summary.recentAbsences;
    final absences = summary.absentCount;
    if (recentAbsences > 0) {
      return '$absences faltas registradas · $recentAbsences recentes';
    }
    return '$absences faltas registradas · presença dentro do esperado';
  }

  String _buildActivitiesHomeHeadline(GuardianActivitiesSummary? summary) {
    if (summary == null) return 'Sem dados';
    if (summary.pendingCount > 0) {
      return '${summary.pendingCount} pendentes';
    }
    return '${summary.recentCount} recentes';
  }

  String _buildActivitiesHomeSubtitle(GuardianActivitiesSummary? summary) {
    if (summary == null || summary.totalActivities == 0) {
      return 'As atividades registradas para responsáveis aparecerão aqui.';
    }

    final last = summary.lastActivity;
    if (last != null) {
      return '${summary.deliveredCount} entregues · última em ${last.subjectName}';
    }
    return '${summary.deliveredCount} entregues · ${summary.overdueCount} em atraso';
  }

  String _buildActivitiesHubDescription(GuardianActivitiesSummary? summary) {
    if (summary == null || summary.totalActivities == 0) {
      return 'Nenhuma atividade com visibilidade para responsáveis no momento.';
    }
    return '${summary.recentCount} atividades recentes · ${summary.pendingCount} pendentes · ${summary.overdueCount} em atraso';
  }

  Color _attendanceAccent(String? attentionLevel) {
    return attentionLevel == 'attention'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF00A859);
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final invoices = context.watch<InvoiceProvider>();
    final session = auth.guardianSession;

    return Scaffold(
      backgroundColor: _guardianScreenBackground(context),
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(session),
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(session, invoices),
                _buildTrackingTab(),
                _buildFinanceTab(session, invoices),
                _buildAccountTab(auth, session),
              ],
            ),
          ),
          Positioned.fill(
            child: CustomSpeedDialMenu(
              currentIndex: _currentIndex,
              onTabSelected: _onTabTapped,
              onNavigateToStaff: () {},
              onNavigateToAttendance: () {},
              isGuardian: true,
              onGuardianRefresh: _refreshGuardianPortal,
              onGuardianAccount: () => _onTabTapped(3),
              onGuardianStudentSwitcher: (session?.linkedStudentsCount ?? 0) > 1
                  ? _showStudentPicker
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianInvoiceGroups {
  final List<Invoice> overdue;
  final List<Invoice> pending;
  final List<Invoice> paid;
  final Invoice? featured;

  const _GuardianInvoiceGroups({
    required this.overdue,
    required this.pending,
    required this.paid,
    required this.featured,
  });
}

enum _InvoiceState { pending, overdue, paid, canceled }

bool _isDarkContext(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _guardianScreenBackground(BuildContext context) =>
    _isDarkContext(context) ? const Color(0xFF0B1117) : const Color(0xFFF4F7FB);

Color _guardianSurface(BuildContext context) => Theme.of(context).cardColor;

Color _guardianSoftSurface(BuildContext context) =>
    _isDarkContext(context) ? const Color(0xFF121A23) : const Color(0xFFF8FAFC);

Color _guardianBorder(BuildContext context) =>
    _isDarkContext(context) ? const Color(0xFF223042) : const Color(0xFFE5E7EB);

Color _guardianTextPrimary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color _guardianTextSecondary(BuildContext context) =>
    _isDarkContext(context) ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

Color _guardianAppBarBackground(BuildContext context) => _isDarkContext(context)
    ? const Color(0xFF0B1117).withValues(alpha: 0.96)
    : Colors.white.withValues(alpha: 0.94);

String _guardianInitials(String? value) {
  final parts = (value ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'A';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

List<Invoice> _sortInvoices(
  Iterable<Invoice> invoices, {
  bool descending = false,
}) {
  final items = invoices.toList();
  items.sort((left, right) {
    final comparison = left.dueDate.compareTo(right.dueDate);
    return descending ? -comparison : comparison;
  });
  return items;
}

_InvoiceState _resolveInvoiceState(Invoice invoice) {
  final status = invoice.status.toLowerCase().trim();
  if (status == 'paid' || status == 'pago') return _InvoiceState.paid;
  if (status == 'canceled' || status == 'cancelado') {
    return _InvoiceState.canceled;
  }
  if (status == 'overdue' || status == 'vencido') {
    return _InvoiceState.overdue;
  }

  final today = DateUtils.dateOnly(DateTime.now());
  final dueDate = DateUtils.dateOnly(invoice.dueDate);
  if (dueDate.isBefore(today)) {
    return _InvoiceState.overdue;
  }
  return _InvoiceState.pending;
}

String _buildStatusLabel(_InvoiceState state) {
  switch (state) {
    case _InvoiceState.overdue:
      return 'Em atraso';
    case _InvoiceState.paid:
      return 'Pago';
    case _InvoiceState.canceled:
      return 'Cancelado';
    case _InvoiceState.pending:
      return 'Pendente';
  }
}

String _buildFeaturedLabel(_InvoiceState state) {
  switch (state) {
    case _InvoiceState.overdue:
      return 'Boleto mais urgente';
    case _InvoiceState.pending:
      return 'Próximo vencimento';
    case _InvoiceState.paid:
      return 'Último boleto pago';
    case _InvoiceState.canceled:
      return 'Boleto cancelado';
  }
}

Color _buildStatusColor(_InvoiceState state) {
  switch (state) {
    case _InvoiceState.overdue:
      return const Color(0xFFEF4444);
    case _InvoiceState.paid:
      return const Color(0xFF00A859);
    case _InvoiceState.canceled:
      return const Color(0xFF64748B);
    case _InvoiceState.pending:
      return const Color(0xFFF59E0B);
  }
}

String _buildAccessStatusLabel(String status) {
  switch (status.toLowerCase().trim()) {
    case 'blocked':
      return 'Bloqueado';
    case 'inactive':
      return 'Desativado';
    case 'pending':
      return 'Pendente';
    case 'active':
    default:
      return 'Ativo';
  }
}

String _buildReferenceLabel(Invoice invoice) {
  final raw = DateFormat('MMMM yyyy', 'pt_BR').format(invoice.dueDate);
  return toBeginningOfSentenceCase(raw) ?? raw;
}

String _buildDate(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
}

String _buildDueText(Invoice invoice) {
  if (_resolveInvoiceState(invoice) == _InvoiceState.paid &&
      invoice.effectivePaidAt != null) {
    return 'Pago em ${_buildDate(invoice.effectivePaidAt!)}';
  }

  final dueDate = DateUtils.dateOnly(invoice.dueDate);
  final today = DateUtils.dateOnly(DateTime.now());
  final formatted = _buildDate(invoice.dueDate);

  if (_resolveInvoiceState(invoice) == _InvoiceState.overdue) {
    final days = today.difference(dueDate).inDays;
    return days <= 0
        ? 'Venceu em $formatted'
        : 'Vencido há $days ${days == 1 ? 'dia' : 'dias'}';
  }

  final diff = dueDate.difference(today).inDays;
  if (diff == 0) return 'Vence hoje · $formatted';
  if (diff == 1) return 'Vence amanhã · $formatted';
  return 'Vence em $diff dias · $formatted';
}

String _formatCurrency(int valueInCents) {
  return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
      .format(valueInCents / 100);
}

class _GuardianAccountContextCard extends StatelessWidget {
  final String schoolName;
  final Uint8List? schoolLogoBytes;
  final GuardianLinkedStudent? currentStudent;
  final int linkedStudentsCount;

  const _GuardianAccountContextCard({
    required this.schoolName,
    required this.schoolLogoBytes,
    required this.currentStudent,
    required this.linkedStudentsCount,
  });

  @override
  Widget build(BuildContext context) {
    final studentLabel = currentStudent == null
        ? 'Nenhum aluno selecionado'
        : currentStudent!.firstName;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _guardianBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: _guardianSoftSurface(context),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: schoolLogoBytes != null && schoolLogoBytes!.isNotEmpty
                ? Image.memory(
                    schoolLogoBytes!,
                    fit: BoxFit.cover,
                  )
                : Center(
                    child: Text(
                      _guardianInitials(schoolName),
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF00A859),
                      ),
                    ),
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escola atual',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _guardianTextSecondary(context),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  schoolName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _guardianTextPrimary(context),
                  ),
                ),
                SizedBox(height: 5.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _AccountMiniBadge(
                      icon: PhosphorIcons.student_fill,
                      label: studentLabel,
                    ),
                    _AccountMiniBadge(
                      icon: PhosphorIcons.users_three_fill,
                      label:
                          '$linkedStudentsCount ${linkedStudentsCount == 1 ? 'filho vinculado' : 'filhos vinculados'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountMiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AccountMiniBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: _guardianSoftSurface(context),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: _guardianBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12.sp,
            color: const Color(0xFF00A859),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: _guardianTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianStudentOptionTile extends StatelessWidget {
  final GuardianLinkedStudent student;
  final bool selected;
  final VoidCallback onTap;

  const _GuardianStudentOptionTile({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final classLabel = student.classInfo?.name ?? student.relationship;
    const accent = Color(0xFF00A859);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : _guardianSoftSurface(context),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? accent : _guardianBorder(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: _guardianSurface(context),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _guardianInitials(student.fullName),
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: _guardianTextPrimary(context),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    classLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: _guardianTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                PhosphorIcons.check_circle_fill,
                color: accent,
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SettingsSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _guardianBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: _guardianTextPrimary(context),
            ),
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 5.h),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: _guardianTextSecondary(context),
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? helper;

  const _SettingsInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: _guardianSoftSurface(context),
              borderRadius: BorderRadius.circular(12.r),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18.sp,
              color: const Color(0xFF00A859),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _guardianTextSecondary(context),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _guardianTextPrimary(context),
                    height: 1.3,
                  ),
                ),
                if ((helper ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: 3.h),
                  Text(
                    helper!,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: _guardianTextSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeLabel;
  final VoidCallback? onTap;

  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: _guardianSoftSurface(context),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _guardianBorder(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: _guardianSurface(context),
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 16.sp,
                color: const Color(0xFF00A859),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: _guardianTextPrimary(context),
                          ),
                        ),
                      ),
                      if ((badgeLabel ?? '').trim().isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF00A859).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: Text(
                            badgeLabel!,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF00A859),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: _guardianTextSecondary(context),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: 10.w),
              Icon(
                PhosphorIcons.caret_right_bold,
                size: 15.sp,
                color: _guardianTextSecondary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeSelected;

  const _ThemeModeSelector({
    required this.themeMode,
    required this.onThemeModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ThemeModeChoiceChip(
                label: 'Sistema',
                icon: PhosphorIcons.gear_fill,
                selected: themeMode == ThemeMode.system,
                onTap: () => onThemeModeSelected(ThemeMode.system),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _ThemeModeChoiceChip(
                label: 'Claro',
                icon: PhosphorIcons.sun_fill,
                selected: themeMode == ThemeMode.light,
                onTap: () => onThemeModeSelected(ThemeMode.light),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _ThemeModeChoiceChip(
                label: 'Escuro',
                icon: PhosphorIcons.moon_fill,
                selected: themeMode == ThemeMode.dark,
                onTap: () => onThemeModeSelected(ThemeMode.dark),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Text(
          'A preferência fica salva neste dispositivo e reaproveita o mesmo sistema de tema do aplicativo.',
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: _guardianTextSecondary(context),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ThemeModeChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7A5AF8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : _guardianSoftSurface(context),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: selected ? accent : _guardianBorder(context),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: selected ? accent : _guardianTextSecondary(context),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: selected ? accent : _guardianTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianLessonSummaryCard extends StatelessWidget {
  final GuardianScheduleSnapshot? schedule;
  final VoidCallback onOpenSchedule;

  const _GuardianLessonSummaryCard({
    required this.schedule,
    required this.onOpenSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final currentLesson = schedule?.currentClass;
    final nextLesson = schedule?.nextClass;
    final spotlight = currentLesson ?? nextLesson;
    final isCurrent = currentLesson != null;
    final accent =
        isCurrent ? const Color(0xFF00A859) : const Color(0xFF2F80ED);

    if (spotlight == null) {
      return const _EmptyStateCard(
        title: 'Sem aulas em destaque',
        message:
            'Quando houver aulas programadas, a aula atual ou a próxima aula aparecerá aqui.',
      );
    }

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: _isDarkContext(context) ? 0.18 : 0.12),
            _guardianSurface(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusChip(
            label: isCurrent ? 'Acontecendo agora' : 'Próxima aula',
            color: accent,
          ),
          SizedBox(height: 12.h),
          Text(
            spotlight.subjectName,
            style: GoogleFonts.inter(
              color: _guardianTextPrimary(context),
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            spotlight.timeLabel,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: _guardianTextPrimary(context),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            [
              spotlight.teacherName,
              if ((spotlight.room ?? '').trim().isNotEmpty) spotlight.room!,
              if (spotlight.weekdayLabel.trim().isNotEmpty)
                spotlight.weekdayLabel,
            ].join(' · '),
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: _guardianTextSecondary(context),
              height: 1.35,
            ),
          ),
          if ((schedule?.todayCount ?? 0) > 0) ...[
            SizedBox(height: 10.h),
            Text(
              '${schedule!.todayCount} aula(s) programada(s) para hoje',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
          SizedBox(height: 14.h),
          ElevatedButton.icon(
            onPressed: onOpenSchedule,
            icon: Icon(PhosphorIcons.calendar_blank, size: 16.sp),
            label: const Text('Ver grade completa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianHomeSummaryCard extends StatelessWidget {
  final String title;
  final Color accentColor;
  final IconData icon;
  final String headline;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _GuardianHomeSummaryCard({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.headline,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: _guardianSurface(context),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(icon, color: accentColor, size: 18.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: _guardianTextPrimary(context),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              headline,
              style: GoogleFonts.inter(
                color: _guardianTextPrimary(context),
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: _guardianTextSecondary(context),
                height: 1.35,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianHubCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String description;
  final String footnote;
  final VoidCallback onTap;

  const _GuardianHubCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.description,
    required this.footnote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: _guardianSurface(context),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(icon, color: accent, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      color: _guardianTextPrimary(context),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  PhosphorIcons.caret_right_bold,
                  color: accent,
                  size: 18.sp,
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: _guardianTextPrimary(context),
                height: 1.35,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              footnote,
              style: GoogleFonts.inter(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: _guardianTextSecondary(context),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianLoadingCard extends StatelessWidget {
  final String label;

  const _GuardianLoadingCard({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _guardianBorder(context)),
      ),
      child: Row(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF00A859),
            strokeWidth: 2.4,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w500,
                color: _guardianTextSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalShortcutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PortalShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: _guardianSurface(context),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: _guardianTextPrimary(context),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: _guardianTextSecondary(context),
                height: 1.35,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Abrir módulo',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalFinanceSpotlight extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onOpenFinance;
  final Future<void> Function() onCopyCode;
  final Future<void> Function() onOpenBoleto;

  const _PortalFinanceSpotlight({
    required this.invoice,
    required this.onOpenFinance,
    required this.onCopyCode,
    required this.onOpenBoleto,
  });

  @override
  Widget build(BuildContext context) {
    final state = _resolveInvoiceState(invoice);
    final accent = _buildStatusColor(state);

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destaque do financeiro',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            invoice.description,
            style: GoogleFonts.inter(
              color: _guardianTextPrimary(context),
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '${_buildStatusLabel(state)} · ${_buildDueText(invoice)}',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: _guardianTextSecondary(context),
              height: 1.3,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            _formatCurrency(invoice.value),
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: _guardianTextPrimary(context),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenFinance,
                  icon: Icon(PhosphorIcons.money_fill, size: 16.sp),
                  label: const Text('Ir para financeiro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A859),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: Size.fromHeight(44.h),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopyCode,
                  icon: Icon(PhosphorIcons.copy_simple, size: 15.sp),
                  label: const Text('Copiar código'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenBoleto,
                  icon: Icon(PhosphorIcons.download_simple, size: 15.sp),
                  label: const Text('Abrir boleto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceListTileCard extends StatelessWidget {
  final Invoice invoice;
  final bool highlightPaid;
  final VoidCallback onDetails;
  final Future<void> Function() onCopyCode;
  final Future<void> Function() onOpenBoleto;

  const _InvoiceListTileCard({
    required this.invoice,
    required this.highlightPaid,
    required this.onDetails,
    required this.onCopyCode,
    required this.onOpenBoleto,
  });

  @override
  Widget build(BuildContext context) {
    final state = _resolveInvoiceState(invoice);
    final accent =
        highlightPaid ? const Color(0xFF00A859) : _buildStatusColor(state);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buildReferenceLabel(invoice),
                      style: GoogleFonts.inter(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      invoice.description,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: _guardianTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: _buildStatusLabel(state), color: accent),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            _formatCurrency(invoice.value),
            style: GoogleFonts.inter(
              color: _guardianTextPrimary(context),
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            _buildDueText(invoice),
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: _guardianTextSecondary(context),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopyCode,
                  icon: Icon(PhosphorIcons.copy_simple, size: 15.sp),
                  label: const Text('Copiar'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenBoleto,
                  icon: Icon(PhosphorIcons.download_simple, size: 15.sp),
                  label: const Text('Abrir'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDetails,
                  icon: Icon(PhosphorIcons.info, size: 15.sp),
                  label: const Text('Detalhes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: _guardianTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _guardianBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: _guardianTextSecondary(context),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: _guardianTextPrimary(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyStateCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _guardianBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: _guardianTextPrimary(context),
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: _guardianTextSecondary(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: _guardianSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Não foi possível carregar tudo agora',
            style: GoogleFonts.inter(
              color: const Color(0xFF991B1B),
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7F1D1D),
              height: 1.45,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: Icon(PhosphorIcons.arrow_clockwise, size: 16.sp),
            label: const Text('Tentar novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
