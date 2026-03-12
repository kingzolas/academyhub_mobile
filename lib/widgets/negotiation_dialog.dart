import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:academyhub_mobile/model/negotiation_model.dart';
import 'package:academyhub_mobile/providers/financial_automation_provider.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

class NegotiationPopup extends StatefulWidget {
  final String token;
  final String studentId;
  final List<Invoice> invoicesToNegotiate;
  final VoidCallback onSaveSuccess;

  const NegotiationPopup({
    Key? key,
    required this.token,
    required this.studentId,
    required this.invoicesToNegotiate,
    required this.onSaveSuccess,
  }) : super(key: key);

  @override
  _NegotiationPopupState createState() => _NegotiationPopupState();
}

class _NegotiationPopupState extends State<NegotiationPopup> {
  late Map<String, bool> _selectedInvoices;

  // Valores matemáticos (em Centavos para precisão)
  double _originalDebtCents = 0.0;
  double _finalDebtCents = 0.0;

  // Controladores
  bool _allowPixDiscount = false;
  final _pixDiscountController = TextEditingController(text: '0');
  String _pixDiscountType = 'percentage';

  bool _allowInstallments = true;
  final _maxInstallmentsController = TextEditingController(text: '12');
  String _interestPayer = 'student';

  final _formatter = intl.NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // URL Base Dinâmica
  String get _appBaseUrl {
    if (kIsWeb) {
      return "${Uri.base.origin}/pagar";
    } else {
      return "http://localhost:3000/pagar"; // Ajuste para seu IP/Domínio real
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedInvoices = {
      for (var invoice in widget.invoicesToNegotiate) invoice.id: true
    };
    _pixDiscountController.addListener(_calculateTotals);
    _calculateTotals();
  }

  @override
  void dispose() {
    _pixDiscountController.dispose();
    _maxInstallmentsController.dispose();
    super.dispose();
  }

  // Lógica Central de Cálculo
  void _calculateTotals() {
    double totalSelected = 0.0;

    for (var invoice in widget.invoicesToNegotiate) {
      if (_selectedInvoices[invoice.id] == true) {
        totalSelected += (invoice.value);
      }
    }

    double finalValue = totalSelected;

    if (_allowPixDiscount) {
      final discountInput =
          double.tryParse(_pixDiscountController.text.replaceAll(',', '.')) ??
              0.0;

      if (_pixDiscountType == 'percentage') {
        final discountAmount = totalSelected * (discountInput / 100);
        finalValue = totalSelected - discountAmount;
      } else {
        final discountCents = discountInput * 100;
        finalValue = totalSelected - discountCents;
      }
    }

    if (finalValue < 0) finalValue = 0;

    setState(() {
      _originalDebtCents = totalSelected;
      _finalDebtCents = finalValue;
    });
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    final provider = Provider.of<NegotiationProvider>(context, listen: false);

    final String pixText = _pixDiscountController.text.replaceAll(',', '.');
    final double pixDiscountValue = double.tryParse(pixText) ?? 0.0;
    final int maxInstallments =
        int.tryParse(_maxInstallmentsController.text) ?? 1;

    final List<Invoice> selectedInvoices = widget.invoicesToNegotiate
        .where((inv) => _selectedInvoices[inv.id] == true)
        .toList();

    if (selectedInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Selecione ao menos uma fatura.',
                style: GoogleFonts.inter()),
            backgroundColor: Colors.red),
      );
      return;
    }

    final rules = NegotiationRules(
      allowPixDiscount: _allowPixDiscount,
      pixDiscountValue: pixDiscountValue,
      pixDiscountType: _pixDiscountType,
      allowInstallments: _allowInstallments,
      maxInstallments: maxInstallments,
      interestPayer: _interestPayer,
    );

    final String? negotiationToken = await provider.createAndSendNegotiation(
      token: widget.token,
      studentId: widget.studentId,
      selectedInvoices: selectedInvoices,
      rules: rules,
    );

    if (negotiationToken != null && mounted) {
      final fullLink = "$_appBaseUrl/$negotiationToken";
      widget.onSaveSuccess();
      _showShareDialog(fullLink);
    }
  }

  void _showShareDialog(String link) {
    // Tema do Dialog de Compartilhamento
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : const Color(0xff777F85);
    final containerBg = isDark ? Colors.grey[800] : Colors.grey[100];
    final containerBorder = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        title: Row(
          children: [
            Icon(PhosphorIcons.check_circle_fill,
                color: Colors.green, size: 32.sp),
            SizedBox(width: 10.w),
            Text("Link Gerado!",
                style: GoogleFonts.sairaCondensed(
                    fontWeight: FontWeight.w800,
                    fontSize: 24.sp,
                    color: textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Envie o link abaixo para o responsável realizar o pagamento:",
                style: GoogleFonts.inter(color: subTextColor, fontSize: 14.sp)),
            SizedBox(height: 15.h),
            Container(
              padding: EdgeInsets.all(15.w),
              decoration: BoxDecoration(
                color: containerBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: containerBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(link,
                        style: GoogleFonts.sourceCodePro(
                            fontSize: 14.sp, color: const Color(0xFF007AFF)),
                        maxLines: 1),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.copy,
                        size: 20.sp,
                        color:
                            isDark ? Colors.grey[400] : Colors.grey.shade700),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Copiado!")));
                    },
                  )
                ],
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(PhosphorIcons.whatsapp_logo, size: 20.sp),
                label: const Text("Copiar Mensagem Pronta"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                  textStyle: GoogleFonts.inter(
                      fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final msg = "Olá! Segue link para regularização: $link";
                  Clipboard.setData(ClipboardData(text: msg));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Mensagem copiada!")));
                },
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text("Concluir",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Captura de Tema
    final provider = Provider.of<NegotiationProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cores principais
    final dialogBg = theme.cardColor;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.black87;
    final sectionTitleColor = isDark ? Colors.blue[200] : Colors.blue[800];

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900.w, maxHeight: 800.h),
        child: Column(
          children: [
            // --- TITLE BAR ---
            _buildTitleBar(textPrimary, isDark),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryHeader(isDark),
                    SizedBox(height: 30.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 5,
                            child: _buildInvoiceList(textPrimary, isDark)),
                        SizedBox(width: 30.w),
                        Expanded(
                            flex: 4,
                            child: _buildControls(textPrimary, isDark)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            _buildBottomBar(provider.isLoading, provider.error, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(Color textColor, bool isDark) {
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nova Negociação',
                  style: GoogleFonts.sairaCondensed(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      fontSize: 32.sp)),
              Text("Selecione as faturas e defina as regras",
                  style: GoogleFonts.ubuntu(
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xff777F85),
                      fontSize: 14.sp)),
            ],
          ),
          IconButton(
              icon: const Icon(PhosphorIcons.x),
              onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(bool isDark) {
    final studentName =
        widget.invoicesToNegotiate.first.student?.fullName ?? 'Aluno';

    // Cores do Header Resumo
    final blueBg = isDark
        ? Colors.blue.withOpacity(0.15)
        : Colors.blueAccent.withOpacity(0.1);
    final blueBorder = isDark
        ? Colors.blue.withOpacity(0.3)
        : Colors.blueAccent.withOpacity(0.3);
    final blueIcon = isDark ? Colors.blue[300] : Colors.blueAccent;
    final blueText = isDark ? Colors.blue[200] : Colors.blueAccent.shade700;

    final orangeBg = isDark
        ? Colors.orange.withOpacity(0.15)
        : Colors.orange.withOpacity(0.1);
    final orangeBorder = isDark
        ? Colors.orange.withOpacity(0.3)
        : Colors.orange.withOpacity(0.3);
    final orangeIcon = isDark ? Colors.orange[300] : Colors.orange;
    final orangeText = isDark ? Colors.orange[200] : Colors.orange.shade800;
    final orangeValue = isDark ? Colors.orange[100] : Colors.orange.shade900;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: blueBg,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: blueBorder),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.student_fill, color: blueIcon, size: 32.sp),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ALUNO(A)",
                          style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: blueText)),
                      Text(studentName,
                          style: GoogleFonts.sairaCondensed(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w800,
                              color: blueText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 20.w),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: orangeBg,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: orangeBorder),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.money_fill, color: orangeIcon, size: 32.sp),
                SizedBox(width: 15.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TOTAL SELECIONADO",
                        style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: orangeText)),
                    Text(_formatter.format(_originalDebtCents / 100.0),
                        style: GoogleFonts.sairaCondensed(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                            color: orangeValue)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceList(Color textColor, bool isDark) {
    final listBg = isDark ? Colors.black26 : const Color(0xFFFAFAFA);
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("1. Selecione as Faturas",
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: textColor)),
        SizedBox(height: 15.h),
        Container(
          height: 350.h,
          decoration: BoxDecoration(
              color: listBg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(10.r)),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            itemCount: widget.invoicesToNegotiate.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.grey[800] : Colors.grey.shade200),
            itemBuilder: (context, index) {
              final invoice = widget.invoicesToNegotiate[index];
              final isSelected = _selectedInvoices[invoice.id] ?? false;
              final isOverdue = invoice.status == 'pending' &&
                  invoice.dueDate.isBefore(DateTime.now());

              // Cores do Item
              final itemTitleColor = isDark ? Colors.white : Colors.black87;
              final itemSubColor =
                  isDark ? Colors.grey[400] : Colors.grey.shade600;
              final badgeBg = isDark ? Colors.grey[800] : Colors.grey.shade200;

              return CheckboxListTile(
                activeColor: Colors.blueAccent,
                checkColor: Colors.white,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 15.w, vertical: 5.h),
                title: Text(invoice.description,
                    style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: itemTitleColor)),
                subtitle: Row(
                  children: [
                    Text(
                      "Venc: ${intl.DateFormat('dd/MM/yyyy').format(invoice.dueDate)}",
                      style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: isOverdue ? Colors.red : itemSubColor,
                          fontWeight:
                              isOverdue ? FontWeight.bold : FontWeight.normal),
                    ),
                    if (isOverdue) ...[
                      SizedBox(width: 5.w),
                      Icon(PhosphorIcons.warning_circle_fill,
                          size: 14.sp, color: Colors.red)
                    ]
                  ],
                ),
                secondary: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(_formatter.format((invoice.value ?? 0) / 100.0),
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                          color: itemTitleColor)),
                ),
                value: isSelected,
                onChanged: (val) {
                  setState(() => _selectedInvoices[invoice.id] = val!);
                  _calculateTotals();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControls(Color textColor, bool isDark) {
    final containerBg = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("2. Condições de Pagamento",
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: textColor)),
        SizedBox(height: 15.h),
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: borderColor)),
          child: Column(
            children: [
              // Toggle Desconto PIX
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Desconto no PIX?",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: textColor)),
                  Switch(
                      value: _allowPixDiscount,
                      onChanged: (v) {
                        setState(() => _allowPixDiscount = v);
                        _calculateTotals();
                      },
                      activeColor: Colors.green.shade600),
                ],
              ),
              if (_allowPixDiscount) ...[
                SizedBox(height: 15.h),
                Row(children: [
                  Expanded(
                      flex: 2,
                      child: _buildTextField(
                          controller: _pixDiscountController,
                          label: "Valor",
                          icon: PhosphorIcons.tag,
                          isNumber: true,
                          isDark: isDark)),
                  SizedBox(width: 10.w),
                  Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                          value: _pixDiscountType,
                          dropdownColor: containerBg,
                          decoration: InputDecoration(
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 10.w),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: BorderSide(color: borderColor)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: BorderSide(color: borderColor)),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'percentage',
                                child: Text('%',
                                    style: TextStyle(color: textColor))),
                            DropdownMenuItem(
                                value: 'fixed',
                                child: Text('R\$',
                                    style: TextStyle(color: textColor)))
                          ],
                          onChanged: (v) {
                            setState(() => _pixDiscountType = v!);
                            _calculateTotals();
                          })),
                ]),
              ],
              Divider(height: 30.h, color: borderColor),
              // Toggle Parcelamento
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Permitir Parcelamento?",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: textColor)),
                  Switch(
                      value: _allowInstallments,
                      onChanged: (v) => setState(() => _allowInstallments = v),
                      activeColor: const Color(0xFF007AFF)),
                ],
              ),
              if (_allowInstallments) ...[
                SizedBox(height: 15.h),
                _buildTextField(
                    controller: _maxInstallmentsController,
                    label: "Máx. Parcelas",
                    icon: PhosphorIcons.credit_card,
                    isNumber: true,
                    isDark: isDark),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isLoading, String? error, bool isDark) {
    final barBg = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final valueColor = isDark ? Colors.greenAccent : Colors.green.shade700;
    final crossedColor = isDark ? Colors.redAccent : Colors.red.shade300;

    return Container(
      padding: EdgeInsets.all(30.w),
      decoration: BoxDecoration(
          color: barBg,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.r)),
          border: Border(top: BorderSide(color: borderColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("VALOR FINAL DO LINK",
                  style: GoogleFonts.inter(
                      color: labelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp)),
              Row(
                children: [
                  Text(_formatter.format(_finalDebtCents / 100.0),
                      style: GoogleFonts.sairaCondensed(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.w800,
                          color: valueColor)),
                  if (_originalDebtCents != _finalDebtCents) ...[
                    SizedBox(width: 15.w),
                    Text(_formatter.format(_originalDebtCents / 100.0),
                        style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: crossedColor,
                            color: crossedColor)),
                  ]
                ],
              ),
              if (error != null)
                Text(error,
                    style:
                        GoogleFonts.inter(color: Colors.red, fontSize: 12.sp)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
                textStyle: GoogleFonts.inter(
                    fontSize: 16.sp, fontWeight: FontWeight.bold)),
            icon: isLoading
                ? Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 10),
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(PhosphorIcons.paper_plane_tilt_fill),
            label: const Text("GERAR LINK DE PAGAMENTO"),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool isNumber = false,
      required bool isDark}) {
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[700];
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;

    return TextFormField(
      controller: controller,
      onChanged: (_) => _calculateTotals(),
      style: GoogleFonts.inter(
          fontSize: 14.sp, fontWeight: FontWeight.w500, color: textColor),
      decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: labelColor),
          prefixIcon: Icon(icon, size: 20.sp, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
          ),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h)),
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : [],
    );
  }
}
