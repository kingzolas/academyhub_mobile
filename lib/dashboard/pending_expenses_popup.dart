import 'package:academyhub_mobile/model/expense_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/expense_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PendingExpensesPopup extends StatefulWidget {
  // [NOVO] Callback para navegação interna
  final VoidCallback onViewAll;

  const PendingExpensesPopup({super.key, required this.onViewAll});

  @override
  State<PendingExpensesPopup> createState() => _PendingExpensesPopupState();
}

class _PendingExpensesPopupState extends State<PendingExpensesPopup> {
  bool _isLoading = true;
  List<Expense> _pendingList = [];
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    await provider.fetchExpenses(auth.token!);

    if (mounted) {
      final all =
          provider.expenses.where((e) => e.status == 'pending').toList();
      all.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _pendingList = all.take(10).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.centerRight,
      insetPadding: EdgeInsets.only(right: 40.w, top: 100.h, bottom: 50.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: Container(
        width: 450.w,
        height: 600.h,
        padding: EdgeInsets.all(24.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.warning_circle_fill,
                        color: Colors.orange, size: 24.sp),
                    SizedBox(width: 10.w),
                    Text("Contas a Pagar (Top 10)",
                        style: GoogleFonts.sairaCondensed(
                            fontSize: 22.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 20.sp))
              ],
            ),
            Divider(height: 30.h, color: Colors.grey[200]),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingList.isEmpty
                      ? Center(
                          child: Text("Nenhuma conta pendente!",
                              style: GoogleFonts.inter(color: Colors.green)))
                      : ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse
                            },
                          ),
                          child: ListView.separated(
                            itemCount: _pendingList.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey[100]),
                            itemBuilder: (ctx, i) {
                              final expense = _pendingList[i];
                              final isLate =
                                  expense.date.isBefore(DateTime.now());

                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 4.h),
                                leading: Container(
                                  padding: EdgeInsets.all(8.sp),
                                  decoration: BoxDecoration(
                                      color: isLate
                                          ? Colors.red[50]
                                          : Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8.r)),
                                  child: Icon(
                                      isLate
                                          ? PhosphorIcons.alarm_fill
                                          : PhosphorIcons.clock_fill,
                                      color:
                                          isLate ? Colors.red : Colors.orange,
                                      size: 20.sp),
                                ),
                                title: Text(expense.description,
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.sp),
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    "${DateFormat('dd/MM').format(expense.date)} • ${expense.category}",
                                    style: GoogleFonts.inter(
                                        fontSize: 12.sp,
                                        color: isLate
                                            ? Colors.red[400]
                                            : Colors.grey[500])),
                                trailing: Text(
                                    _currencyFormat.format(expense.amount),
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp,
                                        color: Colors.black87)),
                              );
                            },
                          ),
                        ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context); // Fecha o popup
                  widget
                      .onViewAll(); // [MODIFICADO] Chama a função do pai (Dashboard)
                },
                style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r))),
                child: Text("Gerenciar Todas as Contas",
                    style: GoogleFonts.inter(
                        color: Colors.black87, fontWeight: FontWeight.w600)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
