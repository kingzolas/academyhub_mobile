import 'package:academyhub_mobile/screens/financeiro/expense_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../model/expense_model.dart';
// Import do seu Sheet de Formulário (ajuste o caminho se necessário)
// import 'expense_form_sheet.dart';

class ScreenFinanceiroDespesas extends StatefulWidget {
  final String initialFilter;
  final double bottomBarPadding;

  const ScreenFinanceiroDespesas({
    super.key,
    this.initialFilter = 'todos',
    this.bottomBarPadding = 80.0,
  });

  @override
  State<ScreenFinanceiroDespesas> createState() =>
      _ScreenFinanceiroDespesasState();
}

class _ScreenFinanceiroDespesasState extends State<ScreenFinanceiroDespesas> {
  final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  late String _filterStatus;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      await Provider.of<ExpenseProvider>(context, listen: false)
          .fetchExpenses(authProvider.token!);
    }
  }

  void _openExpensePopup(BuildContext context, {Expense? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseFormSheet(existingExpense: expense),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate =
          DateTime(_selectedDate.year, _selectedDate.month + offset);
    });
  }

  bool _isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cores
    final kPrimaryGreen = const Color(0xFF00A859);
    final kBgColor = theme.scaffoldBackgroundColor;
    final kTextPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final kTextSecondary = isDark ? Colors.grey[400] : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: kBgColor,
      body: Consumer<ExpenseProvider>(
        builder: (ctx, provider, child) {
          // 1. Filtragem por DATA
          final monthlyExpenses = provider.expenses
              .where((e) => _isSameMonth(e.date, _selectedDate))
              .toList();

          // 2. Cálculos de KPI
          final totalPending = monthlyExpenses
              .where((e) => e.status == 'pending' || e.status == 'late')
              .fold(0.0, (sum, e) => sum + e.amount);

          final totalPaid = monthlyExpenses
              .where((e) => e.status == 'paid')
              .fold(0.0, (sum, e) => sum + e.amount);

          final totalMonth = totalPending + totalPaid;

          // 3. Filtragem da LISTA VISUAL
          final filteredList = monthlyExpenses.where((e) {
            if (_filterStatus == 'todos') return true;
            return e.status == _filterStatus;
          }).toList();

          filteredList.sort((a, b) => b.date.compareTo(a.date));

          return SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- HEADER ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Financeiro",
                                  style: GoogleFonts.sairaCondensed(
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary,
                                    fontSize: 28.sp,
                                  ),
                                ),
                                Text(
                                  "Gerencie suas despesas",
                                  style: GoogleFonts.ubuntu(
                                    fontWeight: FontWeight.w500,
                                    color: kTextSecondary,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => _openExpensePopup(context),
                              icon: Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.grey[800]!
                                          : Colors.grey[300]!),
                                ),
                                child: Icon(PhosphorIcons.plus,
                                    size: 20.sp, color: kPrimaryGreen),
                              ),
                            )
                          ],
                        ),
                        SizedBox(height: 20.h),
                        _buildMonthSelector(theme, isDark, kTextPrimary),
                      ],
                    ),
                  ),
                ),

                // --- CARROSSEL DE KPIS ---
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120.h, // Altura reduzida para compactar
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      children: [
                        _buildKpiCard(
                          "A Pagar",
                          totalPending,
                          PhosphorIcons.clock_fill,
                          Colors.orange,
                          theme,
                          isDark,
                          borderColor: Colors.orange,
                        ),
                        SizedBox(width: 12.w),
                        _buildKpiCard(
                          "Pago",
                          totalPaid,
                          PhosphorIcons.check_circle_fill,
                          kPrimaryGreen,
                          theme,
                          isDark,
                          borderColor: kPrimaryGreen,
                        ),
                        SizedBox(width: 12.w),
                        _buildKpiCard(
                          "Total Mês",
                          totalMonth,
                          PhosphorIcons.chart_line_up_fill,
                          Colors.blueAccent,
                          theme,
                          isDark,
                          borderColor: Colors.blueAccent,
                        ),
                      ],
                    ),
                  ),
                ),

                // --- FILTROS ---
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyFilterDelegate(
                    minHeight: 70.h,
                    maxHeight: 70.h,
                    child: Container(
                      color: kBgColor,
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildFilterChip("Todos", 'todos', isDark),
                          SizedBox(width: 10.w),
                          _buildFilterChip("Pendentes", 'pending', isDark),
                          SizedBox(width: 10.w),
                          _buildFilterChip("Pagos", 'paid', isDark),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- LISTA ---
                if (provider.isLoading)
                  SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(color: kPrimaryGreen)),
                  )
                else if (filteredList.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(isDark),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20.w, vertical: 6.h),
                          child: _buildExpenseCard(
                            context,
                            filteredList[index],
                            provider,
                            theme,
                            isDark,
                          ),
                        );
                      },
                      childCount: filteredList.length,
                    ),
                  ),

                SliverToBoxAdapter(
                    child: SizedBox(height: widget.bottomBarPadding.h + 20.h)),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES OTIMIZADOS ---

  Widget _buildKpiCard(String title, double value, IconData icon,
      Color accentColor, ThemeData theme, bool isDark,
      {required Color borderColor}) {
    // CORREÇÃO DE CORES: Adaptação real para Dark/Light Mode
    // Se isDark é true, texto é branco. Se false, é preto.
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: 150.w,
      height: 85.h, // Altura reduzida (Compacto)
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          // Borda Lateral
          Container(
            width: 4.w,
            height: double.infinity,
            color: borderColor,
          ),

          Expanded(
            child: Padding(
              // Padding reduzido para densidade
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment
                    .center, // Centraliza verticalmente para tirar o vazio
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accentColor, size: 18.sp),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: subTextColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h), // Espaçamento pequeno
                  Text(
                    currencyFormat.format(value),
                    style: GoogleFonts.sairaCondensed(
                      color: textColor,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(ThemeData theme, bool isDark, Color textColor) {
    final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(_selectedDate);
    final capitalized = monthName[0].toUpperCase() + monthName.substring(1);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => _changeMonth(-1),
            borderRadius: BorderRadius.circular(8.r),
            child: Icon(PhosphorIcons.caret_left_bold,
                size: 20.sp, color: isDark ? Colors.white70 : Colors.grey[600]),
          ),
          Text(
            capitalized,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 15.sp,
              color: textColor,
            ),
          ),
          InkWell(
            onTap: () => _changeMonth(1),
            borderRadius: BorderRadius.circular(8.r),
            child: Icon(PhosphorIcons.caret_right_bold,
                size: 20.sp, color: isDark ? Colors.white70 : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _filterStatus == value;
    final activeColor = const Color(0xFF00A859);

    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.transparent : Colors.grey[300]!),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(BuildContext context, Expense expense,
      ExpenseProvider provider, ThemeData theme, bool isDark) {
    final isPaid = expense.status == 'paid';
    final style = _getCategoryStyle(expense.category, isDark);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Dismissible(
      key: Key(expense.id ?? DateTime.now().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 25.w),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text("Excluir",
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8.w),
            Icon(PhosphorIcons.trash_bold, color: Colors.white, size: 24.sp),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDelete(context, expense, provider, isDark);
      },
      child: InkWell(
        onTap: () => _openExpensePopup(context, expense: expense),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.transparent),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                    color: style.bgColor,
                    borderRadius: BorderRadius.circular(14.r)),
                child: Icon(style.icon, size: 24.sp, color: style.color),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                            fontSize: 15.sp)),
                    SizedBox(height: 4.h),
                    Text(expense.category,
                        style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(currencyFormat.format(expense.amount),
                      style: GoogleFonts.sairaCondensed(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          fontSize: 18.sp)),
                  SizedBox(height: 4.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.r)),
                    child: Text(
                      isPaid ? "PAGO" : "PENDENTE",
                      style: GoogleFonts.inter(
                          color:
                              isPaid ? Colors.green[700] : Colors.orange[800],
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Expense expense,
      ExpenseProvider provider, bool isDark) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r)),
            title: Text("Excluir Despesa",
                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            content: const Text("Tem certeza? Isso não pode ser desfeito."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Cancelar")),
              TextButton(
                onPressed: () {
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);
                  provider.deleteExpense(auth.token!, expense.id!);
                  Navigator.of(ctx).pop(true);
                },
                child:
                    const Text("Excluir", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(PhosphorIcons.receipt,
                size: 40.sp,
                color: isDark ? Colors.grey[500] : Colors.grey[400]),
          ),
          SizedBox(height: 16.h),
          Text("Tudo limpo por aqui!",
              style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
          Text("Nenhuma despesa encontrada neste filtro.",
              style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey[600] : Colors.grey[500])),
        ],
      ),
    );
  }

  ExpenseCategoryStyle _getCategoryStyle(String category, bool isDark) {
    Color getBg(Color base) =>
        isDark ? base.withOpacity(0.15) : base.withOpacity(0.1);

    final cleanCategory = category.trim().toLowerCase();

    if (cleanCategory.contains('energia')) {
      return ExpenseCategoryStyle(PhosphorIcons.lightning_fill,
          Colors.amber[700]!, getBg(Colors.amber));
    } else if (cleanCategory.contains('água') ||
        cleanCategory.contains('agua')) {
      return ExpenseCategoryStyle(
          PhosphorIcons.drop_fill, Colors.blue[600]!, getBg(Colors.blue));
    } else if (cleanCategory.contains('internet')) {
      return ExpenseCategoryStyle(
          PhosphorIcons.wifi_high_bold, Colors.cyan[600]!, getBg(Colors.cyan));
    } else if (cleanCategory.contains('pessoal')) {
      return ExpenseCategoryStyle(PhosphorIcons.users_three_fill,
          Colors.purple[600]!, getBg(Colors.purple));
    } else if (cleanCategory.contains('vale') ||
        cleanCategory.contains('adiantamento')) {
      return ExpenseCategoryStyle(PhosphorIcons.hand_soap_fill,
          Colors.redAccent[700]!, getBg(Colors.red));
    } else if (cleanCategory.contains('aluguel')) {
      return ExpenseCategoryStyle(PhosphorIcons.house_line_fill,
          Colors.indigo[600]!, getBg(Colors.indigo));
    } else if (cleanCategory.contains('manutenção') ||
        cleanCategory.contains('manutencao')) {
      return ExpenseCategoryStyle(
          PhosphorIcons.wrench_fill, Colors.brown[600]!, getBg(Colors.brown));
    } else if (cleanCategory.contains('marketing')) {
      return ExpenseCategoryStyle(
          PhosphorIcons.megaphone_fill, Colors.pink[600]!, getBg(Colors.pink));
    } else if (cleanCategory.contains('impostos')) {
      return ExpenseCategoryStyle(PhosphorIcons.bank_fill,
          Colors.blueGrey[700]!, getBg(Colors.blueGrey));
    } else {
      return ExpenseCategoryStyle(
          PhosphorIcons.tag_fill,
          isDark ? Colors.grey[400]! : Colors.grey[600]!,
          isDark ? Colors.grey[800]! : Colors.grey[200]!);
    }
  }
}

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _StickyFilterDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(_StickyFilterDelegate oldDelegate) =>
      maxHeight != oldDelegate.maxHeight ||
      minHeight != oldDelegate.minHeight ||
      child != oldDelegate.child;
}

class ExpenseCategoryStyle {
  final IconData icon;
  final Color color;
  final Color bgColor;
  ExpenseCategoryStyle(this.icon, this.color, this.bgColor);
}
