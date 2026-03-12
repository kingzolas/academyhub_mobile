import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/invoice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:url_launcher/url_launcher.dart';

class DebtorsListSheet extends StatefulWidget {
  const DebtorsListSheet({super.key});

  @override
  State<DebtorsListSheet> createState() => _DebtorsListSheetState();
}

class _DebtorsListSheetState extends State<DebtorsListSheet> {
  final InvoiceService _invoiceService = InvoiceService();
  bool _isLoading = true;
  List<Invoice> _overdueInvoices = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOverdueData();
    });
  }

  Future<void> _fetchOverdueData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    try {
      // 1. Busca todas as faturas pendentes
      final allPending = await _invoiceService.getAllInvoices(
        token: auth.token!,
        status: 'pending',
      );

      // 2. Filtra localmente apenas as vencidas (Data < Hoje)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final overdue = allPending.where((inv) {
        // Normaliza a data da fatura para comparar apenas dia/mês/ano se necessário
        final invDate =
            DateTime(inv.dueDate.year, inv.dueDate.month, inv.dueDate.day);
        return invDate.isBefore(today);
      }).toList();

      // 3. Ordena pelas mais antigas (maior prioridade de cobrança)
      overdue.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      if (mounted) {
        setState(() {
          _overdueInvoices = overdue;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erro ao carregar inadimplência.";
          _isLoading = false;
        });
      }
      print("Erro DebtorsList: $e");
    }
  }

  void _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Telefone não cadastrado"),
          backgroundColor: Colors.red));
      return;
    }

    // Limpa o número
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse(
        "https://wa.me/55$cleanPhone?text=Olá, gostaríamos de falar sobre sua mensalidade pendente.");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print("Não foi possível abrir o WhatsApp: $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cores do Design System
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      height: 0.75.sh,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.symmetric(vertical: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r)),
          ),

          // Título
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Alunos em Atraso",
                        style: GoogleFonts.sairaCondensed(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    if (!_isLoading)
                      Text("${_overdueInvoices.length} faturas vencidas",
                          style: GoogleFonts.inter(
                              fontSize: 12.sp, color: textSecondary)),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(PhosphorIcons.warning_octagon,
                      color: Colors.redAccent, size: 24.sp),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.withOpacity(0.1)),

          // Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child:
                            Text(_error!, style: TextStyle(color: Colors.red)))
                    : _overdueInvoices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(PhosphorIcons.check_circle,
                                    size: 64.sp, color: Colors.green),
                                SizedBox(height: 10.h),
                                Text("Nenhuma inadimplência!",
                                    style: TextStyle(color: textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(20.w),
                            itemCount: _overdueInvoices.length,
                            itemBuilder: (context, index) {
                              final invoice = _overdueInvoices[index];

                              // CÁLCULO DE DIAS DE ATRASO
                              final daysLate = DateTime.now()
                                  .difference(invoice.dueDate)
                                  .inDays;

                              // CORREÇÃO 1: NOME DO ALUNO
                              // Verifique no seu InvoiceModel qual é o campo correto.
                              // Pode ser invoice.studentName ou invoice.student?.fullName
                              final studentName = invoice.student?.fullName ??
                                  "Nome Indisponível";

                              // CORREÇÃO 2: VALOR EM REAIS (DIVISÃO POR 100)
                              // Se o valor vem em centavos (ex: 43000), dividimos por 100
                              final valueInReais = invoice.value / 100.0;

                              return Container(
                                margin: EdgeInsets.only(bottom: 12.h),
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border(
                                        left: BorderSide(
                                            color: Colors.red, width: 4.w))),
                                child: Row(
                                  children: [
                                    // Avatar (Inicial)
                                    CircleAvatar(
                                      backgroundColor:
                                          Colors.red.withOpacity(0.1),
                                      child: Text(
                                          studentName.isNotEmpty
                                              ? studentName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    SizedBox(width: 12.w),

                                    // Dados Centrais
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(studentName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: textPrimary,
                                                  fontSize: 14.sp)),
                                          Text(
                                              "Venceu há $daysLate dias (${DateFormat('dd/MM').format(invoice.dueDate)})",
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12.sp)),
                                        ],
                                      ),
                                    ),

                                    // Valor e Ação
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                            NumberFormat.simpleCurrency(
                                                    locale: 'pt_BR')
                                                .format(
                                                    valueInReais), // Usando o valor corrigido
                                            style: GoogleFonts.sairaCondensed(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16.sp,
                                                color: textPrimary)),
                                        SizedBox(height: 6.h),

                                        // Botão de Cobrança
                                        InkWell(
                                          onTap: () {
                                            // Passar o telefone do aluno se disponível no model
                                            // _openWhatsApp(invoice.studentPhone);
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                                color: Colors.green
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4.r)),
                                            child: Row(
                                              children: [
                                                Icon(
                                                    PhosphorIcons.whatsapp_logo,
                                                    color: Colors.green,
                                                    size: 14.sp),
                                                SizedBox(width: 4.w),
                                                Text("Cobrar",
                                                    style: TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 10.sp,
                                                        fontWeight:
                                                            FontWeight.bold))
                                              ],
                                            ),
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
