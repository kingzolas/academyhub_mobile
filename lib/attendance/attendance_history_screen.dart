import 'package:academyhub_mobile/model/attendance_history_insights.dart';
import 'package:academyhub_mobile/model/attendance_model.dart';
import 'package:academyhub_mobile/providers/attendance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const _historyBgDark = Color(0xFF0B1016);
const _historyBgLight = Color(0xFFF4F7FB);
const _historySurfaceDark = Color(0xFF131A23);
const _historySurfaceLight = Colors.white;
const _historySurfaceSoftDark = Color(0xFF18202B);
const _historySurfaceSoftLight = Color(0xFFF8FAFD);
const _historyAccent = Color(0xFF00A859);
const _historyAccent2 = Color(0xFF2F80ED);
const _historyWarning = Color(0xFFF2994A);
const _historyDanger = Color(0xFFFF5252);
const _historyTextDark = Color(0xFFF3F6FA);
const _historyTextLight = Color(0xFF101828);
const _historyMutedDark = Color(0xFF98A3B3);
const _historyMutedLight = Color(0xFF64748B);

class AttendanceHistoryScreen extends StatefulWidget {
  final String classId;
  final String className;

  const AttendanceHistoryScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _studentSearchController;

  AttendanceHistoryRange _selectedRange = AttendanceHistoryRange.month;
  String _studentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _studentSearchController = TextEditingController();
    _studentSearchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _studentSearchController.removeListener(_onSearchChanged);
    _tabController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _studentSearchQuery = _studentSearchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    await context.read<AttendanceProvider>().loadHistory(widget.classId);
  }

  Future<void> _refreshHistory() async {
    await _loadHistory();
  }

  void _selectRange(AttendanceHistoryRange range) {
    if (_selectedRange == range) return;
    setState(() => _selectedRange = range);
  }

  Color _pageBg(bool isDark) => isDark ? _historyBgDark : _historyBgLight;
  Color _surface(bool isDark) =>
      isDark ? _historySurfaceDark : _historySurfaceLight;
  Color _surfaceSoft(bool isDark) =>
      isDark ? _historySurfaceSoftDark : _historySurfaceSoftLight;
  Color _textPrimary(bool isDark) =>
      isDark ? _historyTextDark : _historyTextLight;
  Color _textSecondary(bool isDark) =>
      isDark ? _historyMutedDark : _historyMutedLight;

  Color _rateColor(double rate) {
    if (rate >= 0.9) return _historyAccent;
    if (rate >= 0.75) return _historyWarning;
    return _historyDanger;
  }

  String _pct(double value) => '${(value * 100).round().clamp(0, 100)}%';

  String _shortDate(DateTime date) => DateFormat('dd/MM', 'pt_BR').format(date);

  String _longDate(DateTime date) =>
      DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(date);

  String _timeStamp(DateTime? date) {
    if (date == null) return 'Atualização não informada';
    return DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AttendanceProvider>();
    final summary =
        buildAttendanceHistorySummary(provider.history, _selectedRange);
    final hasData = summary.entries.isNotEmpty;
    final hasError = provider.historyError != null && provider.history.isEmpty;

    return Scaffold(
      backgroundColor: _pageBg(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrow_left, color: _textPrimary(isDark)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Histórico da turma',
          style: GoogleFonts.sairaCondensed(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: _textPrimary(isDark),
          ),
        ),
        actions: [
          IconButton(
            onPressed: provider.isHistoryLoading ? null : _refreshHistory,
            icon: provider.isHistoryLoading
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _historyAccent,
                    ),
                  )
                : Icon(
                    PhosphorIcons.arrows_clockwise,
                    color: _textPrimary(isDark),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: provider.isHistoryLoading && !hasData
            ? Padding(
                padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 12.h),
                child: _buildLoadingState(isDark),
              )
            : NestedScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            _buildHeroCard(isDark, summary),
                            SizedBox(height: 14.h),
                            _buildRangeChips(isDark),
                            SizedBox(height: 14.h),
                            if (provider.isHistoryLoading && hasData)
                              Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    backgroundColor: _surfaceSoft(isDark),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _historyAccent.withOpacity(0.85),
                                    ),
                                  ),
                                ),
                              ),
                            _buildSummaryGrid(isDark, summary),
                            if (hasError)
                              Padding(
                                padding: EdgeInsets.only(top: 12.h),
                                child: _buildErrorBanner(
                                  isDark,
                                  provider.historyError!,
                                  _refreshHistory,
                                ),
                              ),
                            SizedBox(height: 10.h),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _AttendanceHistoryTabBarDelegate(
                        height: 66.h,
                        child: Container(
                          color: _pageBg(isDark),
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                          alignment: Alignment.center,
                          child: _buildTabBar(isDark),
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCallsTab(isDark, summary),
                    _buildStudentsTab(isDark, summary),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(22.w),
        decoration: BoxDecoration(
          color: _surface(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46.w,
              height: 46.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _historyAccent,
                backgroundColor: _historyAccent.withOpacity(0.12),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Carregando histórico',
              style: GoogleFonts.sairaCondensed(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: _textPrimary(isDark),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Buscando chamadas registradas para ${widget.className}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: _textSecondary(isDark),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isDark, AttendanceHistorySummary summary) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF15212D),
                  const Color(0xFF0F1822),
                  const Color(0xFF101826),
                ]
              : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFF3F8FB),
                  const Color(0xFFEFF6F3),
                ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _historyAccent.withOpacity(isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Turma ${widget.className}',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: _historyAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Histórico de chamadas',
            style: GoogleFonts.sairaCondensed(
              fontSize: 30.sp,
              fontWeight: FontWeight.w700,
              color: _textPrimary(isDark),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Leia rapidamente presença, faltas e recorrência por aluno sem sair da experiência atual de frequência.',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              height: 1.45,
              color: _textSecondary(isDark),
            ),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _HeroMiniChip(
                isDark: isDark,
                icon: PhosphorIcons.clock_counter_clockwise,
                label: summary.latestEntry == null
                    ? 'Sem chamadas registradas'
                    : formatRelativeAttendanceDate(summary.latestEntry!.date),
                color: _historyAccent,
              ),
              _HeroMiniChip(
                isDark: isDark,
                icon: PhosphorIcons.users_three,
                label: '${summary.totalCalls} chamadas',
                color: _historyAccent2,
              ),
              _HeroMiniChip(
                isDark: isDark,
                icon: PhosphorIcons.warning_circle,
                label: '${summary.atRiskStudents} em atenção',
                color: _historyWarning,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.latestEntry == null
                      ? 'Nenhuma chamada nesta janela.'
                      : summary.latestEntry!.updatedAt != null
                          ? 'Última atualização ${_timeStamp(summary.latestEntry!.updatedAt)}'
                          : 'Lido no período ${_selectedRange.label.toLowerCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: _textSecondary(isDark),
                  ),
                ),
              ),
              Container(
                width: 82.w,
                height: 82.w,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _rateColor(summary.averagePresenceRate)
                      .withOpacity(isDark ? 0.12 : 0.10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60.w,
                      height: 60.w,
                      child: CircularProgressIndicator(
                        value: summary.averagePresenceRate.clamp(0.0, 1.0),
                        strokeWidth: 6,
                        backgroundColor: _historyAccent.withOpacity(0.16),
                        color: _rateColor(summary.averagePresenceRate),
                      ),
                    ),
                    Text(
                      _pct(summary.averagePresenceRate),
                      style: GoogleFonts.sairaCondensed(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AttendanceHistoryRange.values.map((range) {
          final selected = _selectedRange == range;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ChoiceChip(
              label: Text(
                range.label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _textPrimary(isDark),
                ),
              ),
              selected: selected,
              onSelected: (_) => _selectRange(range),
              selectedColor: _historyAccent,
              backgroundColor: _surface(isDark),
              side: BorderSide(
                color: selected
                    ? _historyAccent
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryGrid(bool isDark, AttendanceHistorySummary summary) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 2.15,
      children: [
        _HistoryMetricCard(
          isDark: isDark,
          color: _historyAccent,
          icon: PhosphorIcons.calendar_check,
          label: 'Chamadas',
          value: '${summary.totalCalls}',
          subtitle: 'na janela filtrada',
        ),
        _HistoryMetricCard(
          isDark: isDark,
          color: _historyAccent2,
          icon: PhosphorIcons.chart_line_up,
          label: 'Presença média',
          value: _pct(summary.averagePresenceRate),
          subtitle: 'da turma',
        ),
        _HistoryMetricCard(
          isDark: isDark,
          color: _historyDanger,
          icon: PhosphorIcons.x_circle,
          label: 'Faltas',
          value: '${summary.totalAbsent}',
          subtitle: 'registradas no período',
        ),
        _HistoryMetricCard(
          isDark: isDark,
          color: _historyWarning,
          icon: PhosphorIcons.warning_circle,
          label: 'Em atenção',
          value: '${summary.atRiskStudents}',
          subtitle: 'alunos com risco',
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _historyAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _textSecondary(isDark),
        labelStyle: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            icon: Icon(PhosphorIcons.calendar_check),
            text: 'Chamadas',
          ),
          Tab(
            icon: Icon(PhosphorIcons.student),
            text: 'Alunos',
          ),
        ],
      ),
    );
  }

  Widget _buildCallsTab(bool isDark, AttendanceHistorySummary summary) {
    if (summary.entries.isEmpty) {
      return RefreshIndicator(
        color: _historyAccent,
        onRefresh: _refreshHistory,
        child: ListView(
          key: const PageStorageKey('attendance-history-calls-empty'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
          children: [
            _EmptyStateCard(
              isDark: isDark,
              icon: PhosphorIcons.calendar_x,
              title: 'Nenhuma chamada neste período',
              description:
                  'Ajuste a janela de tempo ou registre uma nova chamada para a turma ${widget.className}.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _historyAccent,
      onRefresh: _refreshHistory,
      child: ListView.separated(
        key: const PageStorageKey('attendance-history-calls-list'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        itemCount: summary.entries.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final sheet = summary.entries[index];
          return _HistoryEntryCard(
            sheet: sheet,
            isDark: isDark,
            isLatest: index == 0,
            onTap: () => _showEntryDetails(sheet, isDark),
            accentColor: _rateColor(sheet.presenceRate),
            formatDateTime: _timeStamp,
            formatRelativeDate: formatRelativeAttendanceDate,
            longDate: _longDate,
          );
        },
      ),
    );
  }

  Widget _buildStudentsTab(bool isDark, AttendanceHistorySummary summary) {
    final filteredStudents = summary.studentInsights.where((student) {
      if (_studentSearchQuery.isEmpty) return true;
      return student.studentName.toLowerCase().contains(_studentSearchQuery);
    }).toList(growable: false);

    if (filteredStudents.isEmpty) {
      return RefreshIndicator(
        color: _historyAccent,
        onRefresh: _refreshHistory,
        child: ListView(
          key: const PageStorageKey('attendance-history-students-empty'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
          children: [
            _buildStudentSearchField(isDark),
            SizedBox(height: 12.h),
            _EmptyStateCard(
              isDark: isDark,
              icon: PhosphorIcons.student,
              title: _studentSearchQuery.isEmpty
                  ? 'Nenhum aluno encontrado'
                  : 'Nenhum aluno corresponde à busca',
              description: _studentSearchQuery.isEmpty
                  ? 'Ainda não há dados suficientes para montar o ranking por aluno nesta janela.'
                  : 'Tente outro nome ou limpe a busca para ver todos os alunos.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _historyAccent,
      onRefresh: _refreshHistory,
      child: ListView.separated(
        key: const PageStorageKey('attendance-history-students-list'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        itemCount: filteredStudents.length + 1,
        separatorBuilder: (_, index) =>
            SizedBox(height: index == 0 ? 12.h : 10.h),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildStudentSearchField(isDark);
          }

          final student = filteredStudents[index - 1];
          return _StudentInsightCard(
            insight: student,
            isDark: isDark,
            onTap: () => _showStudentDetails(student, isDark),
            formatDate: _shortDate,
            formatRelativeDate: formatRelativeAttendanceDate,
          );
        },
      ),
    );
  }

  Widget _buildStudentSearchField(bool isDark) {
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: TextField(
        controller: _studentSearchController,
        decoration: InputDecoration(
          hintText: 'Buscar aluno...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13.sp,
            color: _textSecondary(isDark),
          ),
          prefixIcon: Icon(
            PhosphorIcons.magnifying_glass,
            color: _textSecondary(isDark),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 14.h,
          ),
        ),
        style: GoogleFonts.inter(
          fontSize: 13.sp,
          color: _textPrimary(isDark),
        ),
      ),
    );
  }

  Future<void> _showEntryDetails(
    AttendanceSheet sheet,
    bool isDark,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _AttendanceEntryDetailSheet(
          sheet: sheet,
          isDark: isDark,
          textPrimary: _textPrimary(isDark),
          textSecondary: _textSecondary(isDark),
          surface: _surface(isDark),
          surfaceSoft: _surfaceSoft(isDark),
          longDate: _longDate,
          timeStamp: _timeStamp,
          rateColor: _rateColor(sheet.presenceRate),
        );
      },
    );
  }

  Future<void> _showStudentDetails(
    AttendanceStudentInsight student,
    bool isDark,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _StudentInsightDetailSheet(
          insight: student,
          isDark: isDark,
          textPrimary: _textPrimary(isDark),
          textSecondary: _textSecondary(isDark),
          surface: _surface(isDark),
          surfaceSoft: _surfaceSoft(isDark),
          shortDate: _shortDate,
        );
      },
    );
  }

  Widget _buildErrorBanner(
    bool isDark,
    String message,
    VoidCallback onRetry,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _historyDanger.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _historyDanger.withOpacity(0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.warning_circle,
            color: _historyDanger,
            size: 22.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Não foi possível atualizar o histórico',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary(isDark),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: _textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Tentar',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: _historyDanger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceHistoryTabBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _AttendanceHistoryTabBarDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _AttendanceHistoryTabBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _HeroMiniChip extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final Color color;

  const _HeroMiniChip({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryMetricCard extends StatelessWidget {
  final bool isDark;
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _HistoryMetricCard({
    required this.isDark,
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? _historySurfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: isDark ? _historyMutedDark : _historyMutedLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: GoogleFonts.sairaCondensed(
                    fontSize: 24.sp,
                    color: isDark ? _historyTextDark : _historyTextLight,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: isDark ? _historyMutedDark : _historyMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.16)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.sairaCondensed(
                fontSize: 21.sp,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String description;

  const _EmptyStateCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? _historySurfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _historyAccent.withOpacity(isDark ? 0.16 : 0.10),
            ),
            child: Icon(
              icon,
              color: _historyAccent,
              size: 30.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.sairaCondensed(
              fontSize: 26.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? _historyTextDark : _historyTextLight,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: isDark ? _historyMutedDark : _historyMutedLight,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final AttendanceSheet sheet;
  final bool isDark;
  final bool isLatest;
  final VoidCallback onTap;
  final Color accentColor;
  final String Function(DateTime date) formatRelativeDate;
  final String Function(DateTime? date) formatDateTime;
  final String Function(DateTime date) longDate;

  const _HistoryEntryCard({
    required this.sheet,
    required this.isDark,
    required this.isLatest,
    required this.onTap,
    required this.accentColor,
    required this.formatRelativeDate,
    required this.formatDateTime,
    required this.longDate,
  });

  @override
  Widget build(BuildContext context) {
    final presence = sheet.presenceRate.clamp(0.0, 1.0);
    final rateColor = accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark ? _historySurfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isLatest
                  ? rateColor.withOpacity(0.34)
                  : (isDark ? Colors.white12 : Colors.black12),
              width: isLatest ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                longDate(sheet.date),
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? _historyTextDark
                                      : _historyTextLight,
                                ),
                              ),
                            ),
                            if (isLatest)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: rateColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Mais recente',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    color: rateColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          formatRelativeDate(sheet.date),
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color:
                                isDark ? _historyMutedDark : _historyMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: rateColor.withOpacity(isDark ? 0.14 : 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(presence * 100).round()}%',
                          style: GoogleFonts.sairaCondensed(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            color: rateColor,
                            height: 1,
                          ),
                        ),
                        Text(
                          'presença',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: rateColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  _StatPill(
                    label: 'Presentes',
                    value: '${sheet.presentCount}',
                    color: _historyAccent,
                    isDark: isDark,
                  ),
                  SizedBox(width: 8.w),
                  _StatPill(
                    label: 'Faltas',
                    value: '${sheet.absentCount}',
                    color: _historyDanger,
                    isDark: isDark,
                  ),
                  SizedBox(width: 8.w),
                  _StatPill(
                    label: 'Total',
                    value: '${sheet.totalStudents}',
                    color: _historyAccent2,
                    isDark: isDark,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: presence,
                  backgroundColor: (isDark ? Colors.white12 : Colors.black12)
                      .withOpacity(0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Icon(
                    PhosphorIcons.clock_counter_clockwise,
                    size: 15.sp,
                    color: isDark ? _historyMutedDark : _historyMutedLight,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      sheet.updatedAt != null
                          ? 'Atualizada ${formatDateTime(sheet.updatedAt)}'
                          : 'Toque para ver presentes, faltas e observações',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: isDark ? _historyMutedDark : _historyMutedLight,
                      ),
                    ),
                  ),
                  Icon(
                    PhosphorIcons.caret_right,
                    size: 16.sp,
                    color: isDark ? _historyMutedDark : _historyMutedLight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentInsightCard extends StatelessWidget {
  final AttendanceStudentInsight insight;
  final bool isDark;
  final VoidCallback onTap;
  final String Function(DateTime date) formatDate;
  final String Function(DateTime date) formatRelativeDate;

  const _StudentInsightCard({
    required this.insight,
    required this.isDark,
    required this.onTap,
    required this.formatDate,
    required this.formatRelativeDate,
  });

  Color _labelColor() {
    switch (insight.label) {
      case 'Alta frequência':
        return _historyAccent;
      case 'Atenção':
        return _historyWarning;
      case 'Risco de ausência recorrente':
        return _historyDanger;
      default:
        return isDark ? _historyMutedDark : _historyMutedLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _labelColor();
    final initials = insight.studentName.isNotEmpty
        ? insight.studentName
            .trim()
            .split(' ')
            .take(2)
            .map((part) => part.isNotEmpty ? part[0] : '')
            .join()
            .toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark ? _historySurfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.16 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24.sp,
                backgroundColor: color.withOpacity(isDark ? 0.18 : 0.12),
                backgroundImage: insight.studentPhoto != null
                    ? NetworkImage(insight.studentPhoto!)
                    : null,
                child: insight.studentPhoto == null
                    ? Text(
                        initials,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight.studentName,
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark ? _historyTextDark : _historyTextLight,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            insight.label,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${(insight.presenceRate * 100).round()}% de presença • ${insight.absentCount} faltas no período',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: isDark ? _historyMutedDark : _historyMutedLight,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _StudentMiniStat(
                          label: 'Presenças',
                          value: '${insight.presentCount}',
                          color: _historyAccent,
                          isDark: isDark,
                        ),
                        _StudentMiniStat(
                          label: 'Faltas',
                          value: '${insight.absentCount}',
                          color: _historyDanger,
                          isDark: isDark,
                        ),
                        _StudentMiniStat(
                          label: 'Sequência',
                          value: '${insight.consecutiveAbsences}',
                          color: _historyWarning,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    if (insight.lastAttendanceDate != null) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'Último registro ${formatRelativeDate(insight.lastAttendanceDate!)}',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color:
                              isDark ? _historyMutedDark : _historyMutedLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                PhosphorIcons.caret_right,
                size: 18.sp,
                color: isDark ? _historyMutedDark : _historyMutedLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StudentMiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9.sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool isDark;

  const _DetailMetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.sairaCondensed(
              fontSize: 24.sp,
              color: color,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceEntryDetailSheet extends StatelessWidget {
  final AttendanceSheet sheet;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;
  final Color surfaceSoft;
  final String Function(DateTime date) longDate;
  final String Function(DateTime? date) timeStamp;
  final Color rateColor;

  const _AttendanceEntryDetailSheet({
    required this.sheet,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
    required this.surfaceSoft,
    required this.longDate,
    required this.timeStamp,
    required this.rateColor,
  });

  @override
  Widget build(BuildContext context) {
    final presentRecords = sheet.presentRecords;
    final absentRecords = sheet.absentRecords;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.62,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 16.h),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  longDate(sheet.date),
                                  style: GoogleFonts.sairaCondensed(
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Detalhe da chamada e leitura individual',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(PhosphorIcons.x, color: textSecondary),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _DetailMetricCard(
                              title: 'Presentes',
                              value: '${sheet.presentCount}',
                              color: _historyAccent,
                              isDark: isDark,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _DetailMetricCard(
                              title: 'Faltas',
                              value: '${sheet.absentCount}',
                              color: _historyDanger,
                              isDark: isDark,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _DetailMetricCard(
                              title: 'Presença',
                              value: '${(sheet.presenceRate * 100).round()}%',
                              color: rateColor,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: rateColor.withOpacity(isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: rateColor.withOpacity(0.18)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumo rápido',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: rateColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: sheet.presenceRate.clamp(0.0, 1.0),
                                backgroundColor: rateColor.withOpacity(0.12),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(rateColor),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Atualizada ${timeStamp(sheet.updatedAt)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: textSecondary,
                                  ),
                                ),
                                Text(
                                  '${sheet.totalStudents} alunos',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _recordSection(
                        title: 'Presentes',
                        subtitle: '${presentRecords.length} aluno(s)',
                        records: presentRecords,
                        accent: _historyAccent,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        isPresent: true,
                      ),
                      SizedBox(height: 16.h),
                      _recordSection(
                        title: 'Faltas',
                        subtitle: '${absentRecords.length} aluno(s)',
                        records: absentRecords,
                        accent: _historyDanger,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        isPresent: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _recordSection({
    required String title,
    required String subtitle,
    required List<AttendanceRecord> records,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required bool isPresent,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (records.isEmpty)
            Text(
              isPresent
                  ? 'Nenhum aluno marcado como presente.'
                  : 'Nenhuma falta registrada nesta chamada.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: textSecondary,
              ),
            )
          else
            Column(
              children: records.map((record) {
                final initials = record.studentName.isNotEmpty
                    ? record.studentName
                        .trim()
                        .split(' ')
                        .take(2)
                        .map((part) => part.isNotEmpty ? part[0] : '')
                        .join()
                        .toUpperCase()
                    : '?';

                return Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isDark ? 0.02 : 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.10)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20.sp,
                          backgroundColor: accent.withOpacity(0.12),
                          backgroundImage: record.studentPhoto != null
                              ? NetworkImage(record.studentPhoto!)
                              : null,
                          child: record.studentPhoto == null
                              ? Text(
                                  initials,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                )
                              : null,
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
                                      record.studentName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      record.absenceLabel,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (record.hasObservation) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  record.observation,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _StudentInsightDetailSheet extends StatelessWidget {
  final AttendanceStudentInsight insight;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;
  final Color surfaceSoft;
  final String Function(DateTime date) shortDate;

  const _StudentInsightDetailSheet({
    required this.insight,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
    required this.surfaceSoft,
    required this.shortDate,
  });

  Color _accentForLabel() {
    switch (insight.label) {
      case 'Alta frequência':
        return _historyAccent;
      case 'Atenção':
        return _historyWarning;
      case 'Risco de ausência recorrente':
        return _historyDanger;
      default:
        return isDark ? _historyMutedDark : _historyMutedLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForLabel();
    final initials = insight.studentName.isNotEmpty
        ? insight.studentName
            .trim()
            .split(' ')
            .take(2)
            .map((part) => part.isNotEmpty ? part[0] : '')
            .join()
            .toUpperCase()
        : '?';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.62,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 16.h),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24.sp,
                            backgroundColor: accent.withOpacity(0.12),
                            backgroundImage: insight.studentPhoto != null
                                ? NetworkImage(insight.studentPhoto!)
                                : null,
                            child: insight.studentPhoto == null
                                ? Text(
                                    initials,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  insight.studentName,
                                  style: GoogleFonts.sairaCondensed(
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    height: 1,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Leitura individual de frequência',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(PhosphorIcons.x, color: textSecondary),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withOpacity(0.18)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.label,
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: insight.presenceRate.clamp(0.0, 1.0),
                                backgroundColor: accent.withOpacity(0.12),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(insight.presenceRate * 100).round()}% de presença',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${insight.consecutiveAbsences} faltas seguidas',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Row(
                        children: [
                          Expanded(
                            child: _DetailMetricCard(
                              title: 'Presenças',
                              value: '${insight.presentCount}',
                              color: _historyAccent,
                              isDark: isDark,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _DetailMetricCard(
                              title: 'Faltas',
                              value: '${insight.absentCount}',
                              color: _historyDanger,
                              isDark: isDark,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _DetailMetricCard(
                              title: 'Sequência',
                              value: '${insight.consecutiveAbsences}',
                              color: _historyWarning,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: surfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withOpacity(0.10)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ausências registradas',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              insight.absenceDates.isEmpty
                                  ? 'Nenhuma falta no período selecionado.'
                                  : '${insight.absenceDates.length} dia(s) com ausência nesta janela.',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: textSecondary,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            if (insight.absenceDates.isEmpty)
                              Text(
                                'Bom sinal: não há faltas nesta janela.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: textSecondary,
                                ),
                              )
                            else
                              Column(
                                children: insight.absenceDates.map((date) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            PhosphorIcons.calendar_x,
                                            color: accent,
                                            size: 16.sp,
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Text(
                                              shortDate(date),
                                              style: GoogleFonts.inter(
                                                fontSize: 12.sp,
                                                color: textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          _HeroMiniChip(
                            isDark: isDark,
                            icon: PhosphorIcons.calendar_blank,
                            label: insight.lastAttendanceDate == null
                                ? 'Sem último registro'
                                : 'Último registro ${shortDate(insight.lastAttendanceDate!)}',
                            color: accent,
                          ),
                          _HeroMiniChip(
                            isDark: isDark,
                            icon: PhosphorIcons.check_circle,
                            label: '${insight.justifiedAbsences} justificadas',
                            color: _historyAccent,
                          ),
                          _HeroMiniChip(
                            isDark: isDark,
                            icon: PhosphorIcons.clock_counter_clockwise,
                            label: '${insight.pendingAbsences} pendentes',
                            color: _historyWarning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
