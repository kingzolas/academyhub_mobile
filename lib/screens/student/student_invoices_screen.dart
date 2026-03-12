import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/invoice_provider.dart';
import 'package:academyhub_mobile/model/invoice_model.dart';

class StudentInvoicesScreen extends StatefulWidget {
  const StudentInvoicesScreen({super.key});

  @override
  State<StudentInvoicesScreen> createState() => _StudentInvoicesScreenState();
}

class _StudentInvoicesScreenState extends State<StudentInvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final invoiceProv = Provider.of<InvoiceProvider>(context, listen: false);

      if (auth.user != null && auth.token != null) {
        invoiceProv.fetchInvoicesByStudent(
          studentId: auth.user!.id,
          token: auth.token!,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7F9);
    final primaryColor = const Color(0xFF00A859);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caret_left_bold,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Mensalidades",
          style: GoogleFonts.leagueSpartan(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[400],
          labelStyle:
              GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600),
          dividerColor: isDark ? Colors.white10 : Colors.black12,
          tabs: const [
            Tab(text: "A Pagar"),
            Tab(text: "Histórico"),
          ],
        ),
      ),
      body: Consumer<InvoiceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (provider.error != null) {
            return _buildEmptyState(
              context,
              icon: PhosphorIcons.warning_circle,
              title: "Ops!",
              message:
                  "Tivemos um problema ao carregar as faturas.\n${provider.error}",
            );
          }

          final historyInvoices = provider.studentInvoices.where((i) {
            final s = i.status.toLowerCase();
            return s == 'paid' ||
                s == 'pago' ||
                s == 'canceled' ||
                s == 'cancelado';
          }).toList();
          historyInvoices.sort((a, b) => b.dueDate.compareTo(a.dueDate));

          final pendingInvoices = provider.studentInvoices.where((i) {
            return !historyInvoices.contains(i);
          }).toList();
          pendingInvoices.sort((a, b) => a.dueDate.compareTo(b.dueDate));

          return TabBarView(
            controller: _tabController,
            children: [
              // ABA 1: A PAGAR
              pendingInvoices.isEmpty
                  ? _buildEmptyState(
                      context,
                      icon: PhosphorIcons.check_circle,
                      title: "Tudo em dia!",
                      message:
                          "Você não possui mensalidades pendentes no momento.",
                    )
                  : RefreshIndicator(
                      color: primaryColor,
                      onRefresh: () async {
                        final auth =
                            Provider.of<AuthProvider>(context, listen: false);
                        await provider.fetchInvoicesByStudent(
                            studentId: auth.user!.id, token: auth.token!);
                      },
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                            left: 20.w, right: 20.w, top: 24.h, bottom: 160.h),
                        itemCount: pendingInvoices.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildTotalizerHeader(
                                context, pendingInvoices);
                          }

                          final invoice = pendingInvoices[index - 1];

                          if (index == 1) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 16.h),
                              child: _buildHighlightCard(context,
                                  invoice: invoice, isDark: isDark),
                            );
                          }

                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _buildCompactCard(context,
                                invoice: invoice, isDark: isDark),
                          );
                        },
                      ),
                    ),

              // ABA 2: HISTÓRICO
              historyInvoices.isEmpty
                  ? _buildEmptyState(
                      context,
                      icon: PhosphorIcons.receipt,
                      title: "Nenhum histórico",
                      message: "Os registros de pagamentos aparecerão aqui.",
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                          left: 20.w, right: 20.w, top: 20.h, bottom: 160.h),
                      itemCount: historyInvoices.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _buildCompactCard(
                            context,
                            invoice: historyInvoices[index],
                            isDark: isDark,
                            isHistory: true,
                          ),
                        );
                      },
                    ),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGET: TOTALIZADOR ---
  Widget _buildTotalizerHeader(BuildContext context, List<Invoice> invoices) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double total = invoices
        .where((i) => !i.isCompensationHold)
        .fold(0.0, (sum, item) => sum + (item.value / 100));

    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total em aberto",
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            formatCurrency.format(total),
            style: GoogleFonts.leagueSpartan(
              fontSize: 36.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: CARD DE DESTAQUE (PRÓXIMA A VENCER) ---
  Widget _buildHighlightCard(BuildContext context,
      {required Invoice invoice, required bool isDark}) {
    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final valueBRL = formatCurrency.format(invoice.value / 100);
    final dueInfo = _getDueTextAndColor(invoice);

    final cleanTitle = _formatInvoiceTitle(invoice, short: false);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: dueInfo.color.withOpacity(isDark ? 0.3 : 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: dueInfo.color.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: dueInfo.color.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    dueInfo.text,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: dueInfo.color,
                    ),
                  ),
                ),
                Icon(PhosphorIcons.calendar_blank,
                    color: isDark ? Colors.grey[500] : Colors.grey[400]),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              cleanTitle,
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              valueBRL,
              style: GoogleFonts.leagueSpartan(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showPaymentOptions(context, invoice),
                icon: Icon(PhosphorIcons.wallet, size: 20.sp),
                label: Text(
                  "Pagar agora",
                  style: GoogleFonts.inter(
                      fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A859),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: CARD COMPACTO (LISTA) ---
  Widget _buildCompactCard(BuildContext context,
      {required Invoice invoice,
      required bool isDark,
      bool isHistory = false}) {
    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final valueBRL = formatCurrency.format(invoice.value / 100);
    final dueDateStr = DateFormat('dd/MM/yy', 'pt_BR').format(invoice.dueDate);

    final cleanTitle = _formatInvoiceTitle(invoice, short: true);

    final statusInfo = _getStatusInfo(invoice, isHistory);

    return InkWell(
      onTap: isHistory || invoice.isCompensationHold
          ? null
          : () => _showPaymentOptions(context, invoice),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : const Color(0xFFF5F7F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHistory ? PhosphorIcons.receipt : PhosphorIcons.file_text,
                color: isDark ? Colors.grey[400] : Colors.black54,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      statusInfo.text,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: statusInfo.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  valueBRL,
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  "Venc: $dueDateStr",
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPERS LÓGICOS ---

  String _formatInvoiceTitle(Invoice invoice, {bool short = false}) {
    final desc = invoice.description.toLowerCase();

    if (desc.contains('mensalidade')) {
      final monthStr = DateFormat('MMMM', 'pt_BR').format(invoice.dueDate);
      final monthCapitalized =
          "${monthStr[0].toUpperCase()}${monthStr.substring(1)}";
      return short ? monthCapitalized : "Mensalidade de $monthCapitalized";
    }

    final studentName = invoice.student?.fullName ?? "";
    if (studentName.isNotEmpty) {
      return invoice.description
          .replaceAll(" - $studentName", "")
          .replaceAll("- $studentName", "")
          .trim();
    }

    return invoice.description;
  }

  _StatusData _getDueTextAndColor(Invoice invoice) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
        invoice.dueDate.year, invoice.dueDate.month, invoice.dueDate.day);
    final diff = due.difference(today).inDays;

    final s = invoice.status.toLowerCase();
    if (s == 'overdue' || s == 'vencido' || diff < 0) {
      return _StatusData(
          "Vencido há ${diff.abs()} dias", const Color(0xFFE53935));
    }

    if (diff == 0) return _StatusData("Vence hoje", const Color(0xFFF57C00));
    if (diff == 1) return _StatusData("Vence amanhã", const Color(0xFFF57C00));
    if (diff <= 5) return _StatusData("Vence em $diff dias", Colors.orange);

    return _StatusData("Vence em $diff dias", const Color(0xFF00A859));
  }

  _StatusData _getStatusInfo(Invoice invoice, bool isHistory) {
    final s = invoice.status.toLowerCase();

    if (invoice.isCompensationHold && !isHistory) {
      return _StatusData("Em Processamento", Colors.blueAccent);
    }
    if (s == 'paid' || s == 'pago') {
      return _StatusData("Pago", const Color(0xFF00A859));
    }
    if (s == 'canceled' || s == 'cancelado') {
      return _StatusData("Cancelado", Colors.grey);
    }
    if (s == 'overdue' || s == 'vencido') {
      return _StatusData("Vencido", const Color(0xFFE53935));
    }
    return _StatusData("Pendente", Colors.orange);
  }

  // ===========================================================================
  // [A MÁGICA]: CONVERSOR OFFLINE DE CÓDIGO DE BARRAS (44) PARA LINHA DIGITÁVEL (47)
  // Baseado na fórmula FEBRABAN de Módulo 10. Não precisa de API nem de Backend!
  // ===========================================================================
  String? _convertToDigitableLine(String rawBarcode) {
    final barcode = rawBarcode.replaceAll(RegExp(r'[^0-9]'), '');
    if (barcode.length != 44) return null; // Prevenção de segurança

    int mod10(String block) {
      int sum = 0;
      bool multiplyBy2 = true;
      for (int i = block.length - 1; i >= 0; i--) {
        int digit = int.parse(block[i]);
        int mult = digit * (multiplyBy2 ? 2 : 1);
        sum += (mult > 9) ? (mult ~/ 10) + (mult % 10) : mult;
        multiplyBy2 = !multiplyBy2;
      }
      int remainder = sum % 10;
      int dv = 10 - remainder;
      return dv == 10 ? 0 : dv;
    }

    // Estrutura do Código de Barras FEBRABAN:
    // Banco(3) Moeda(1) DV(1) FatorData(4) Valor(10) CampoLivre(25)

    // Campo 1: Banco(3) + Moeda(1) + CampoLivre(Pos 1..5) + DV1
    String bankAndCurr = barcode.substring(0, 4);
    String free1 = barcode.substring(19, 24);
    String field1Base = bankAndCurr + free1;
    String field1 = field1Base + mod10(field1Base).toString();

    // Campo 2: CampoLivre(Pos 6..15) + DV2
    String free2 = barcode.substring(24, 34);
    String field2 = free2 + mod10(free2).toString();

    // Campo 3: CampoLivre(Pos 16..25) + DV3
    String free3 = barcode.substring(34, 44);
    String field3 = free3 + mod10(free3).toString();

    // Campo 4: DV Geral do Código de Barras
    String dv = barcode.substring(4, 5);

    // Campo 5: FatorData(4) + Valor(10)
    String factorAndValue = barcode.substring(5, 19);

    return "$field1$field2$field3$dv$factorAndValue";
  }
  // ===========================================================================

  void _showPaymentOptions(BuildContext context, Invoice invoice) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                left: 24.w, right: 24.w, bottom: 24.h, top: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10.r)),
                ),
                SizedBox(height: 24.h),
                Text(
                  "Como deseja pagar?",
                  style: GoogleFonts.leagueSpartan(
                      fontSize: 22.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Escolha a melhor opção para a ${_formatInvoiceTitle(invoice, short: false).toLowerCase()}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                SizedBox(height: 30.h),

                // BOTÃO PIX
                if (invoice.pixCode != null)
                  _buildPaymentTile(
                    context: ctx,
                    icon: PhosphorIcons.qr_code,
                    title: "Pagar com Pix",
                    subtitle: "Copia e Cola. Aprovação na hora.",
                    iconColor: const Color(0xFF00A859),
                    isDark: isDark,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: invoice.pixCode!));
                      Navigator.pop(ctx);
                      _showToast(context, "Código Pix copiado!");
                    },
                  ),

                if (invoice.pixCode != null &&
                    (invoice.boletoBarcode != null ||
                        invoice.boletoUrl != null))
                  SizedBox(height: 12.h),

                // BOTÃO BOLETO
                if (invoice.boletoBarcode != null)
                  _buildPaymentTile(
                    context: ctx,
                    icon: PhosphorIcons.barcode,
                    title: "Copiar Código de Barras",
                    subtitle: "Para colar no app do seu banco.",
                    iconColor: Colors.blueAccent,
                    isDark: isDark,
                    onTap: () {
                      final rawBarcode = invoice.boletoBarcode ?? '';
                      final cleanBarcode =
                          rawBarcode.replaceAll(RegExp(r'[^0-9]'), '');

                      // 1. Se já for 47 dígitos, copia direto
                      if (cleanBarcode.length == 47) {
                        Clipboard.setData(ClipboardData(text: cleanBarcode));
                        Navigator.pop(ctx);
                        _showToast(context, "Linha digitável copiada!");
                      }
                      // 2. Se for 44 dígitos (faturas antigas), MÁGICA OFFLINE!
                      else if (cleanBarcode.length == 44) {
                        final magicDigitable =
                            _convertToDigitableLine(cleanBarcode);
                        if (magicDigitable != null &&
                            magicDigitable.length == 47) {
                          Clipboard.setData(
                              ClipboardData(text: magicDigitable));
                          Navigator.pop(ctx);
                          _showToast(
                              context, "Linha digitável (47 dígitos) copiada!");
                        } else {
                          // Fallback ultra-seguro caso a fórmula falhe
                          Clipboard.setData(ClipboardData(text: cleanBarcode));
                          Navigator.pop(ctx);
                          _showToast(context, "Código original copiado.");
                        }
                      } else {
                        Clipboard.setData(ClipboardData(text: cleanBarcode));
                        Navigator.pop(ctx);
                        _showToast(context, "Código copiado.");
                      }
                    },
                  ),

                if (invoice.boletoUrl != null || invoice.boletoBarcode != null)
                  SizedBox(height: 12.h),

                // BOTÃO PDF
                if (invoice.boletoUrl != null || invoice.boletoBarcode != null)
                  _buildPaymentTile(
                    context: ctx,
                    icon: PhosphorIcons.download,
                    title: "Baixar Boleto PDF",
                    subtitle: "Para salvar ou imprimir.",
                    iconColor: Colors.orangeAccent,
                    isDark: isDark,
                    onTap: () async {
                      Navigator.pop(ctx);

                      if (invoice.boletoUrl != null &&
                          invoice.boletoUrl!.isNotEmpty) {
                        final url = Uri.parse(invoice.boletoUrl!);
                        try {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        } catch (e) {
                          _showToast(
                              context, "Não foi possível abrir o boleto.");
                        }
                      } else {
                        final auth =
                            Provider.of<AuthProvider>(context, listen: false);
                        final provider = Provider.of<InvoiceProvider>(context,
                            listen: false);
                        await provider.generateBatchPdf(
                            invoiceIds: [invoice.id], token: auth.token!);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? Colors.black12 : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87)),
                  SizedBox(height: 2.h),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
            ),
            Icon(PhosphorIcons.caret_right,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                size: 20.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context,
      {required IconData icon,
      required String title,
      required String message}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.grey[800] : Colors.blue[50]),
              child: Icon(icon, size: 60.sp, color: Colors.blueAccent),
            ),
            SizedBox(height: 24.h),
            Text(title,
                style: GoogleFonts.leagueSpartan(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            SizedBox(height: 8.h),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF00A859),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }
}

class _StatusData {
  final String text;
  final Color color;
  _StatusData(this.text, this.color);
}
