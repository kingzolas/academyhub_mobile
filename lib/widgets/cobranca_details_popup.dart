import 'dart:convert';

import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/invoice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

typedef OnCancelInvoiceCallback = void Function(String invoiceId);

class CobrancaDetailsPopup extends StatelessWidget {
  final Invoice invoice;
  final OnCancelInvoiceCallback? onCancel;

  const CobrancaDetailsPopup({
    super.key,
    required this.invoice,
    this.onCancel,
  });

  bool get _canBeCanceled {
    final status = invoice.status.toLowerCase().trim();
    return status == 'pending' || status == 'overdue';
  }

  Future<void> _launchBoleto(BuildContext context) async {
    if (invoice.boletoUrl == null) return;

    final Uri url = Uri.parse(invoice.boletoUrl!);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Não foi possível abrir o boleto.")),
        );
      }
    }
  }

  Future<void> _showCoraDebug(BuildContext context) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sessão expirada. Faça login novamente.")),
      );
      return;
    }

    // ✅ Campo esperado no model (conforme seu backend): externalId
    final externalId = invoice.externalId;
    if (externalId == null || externalId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Esta cobrança não possui externalId.")),
      );
      return;
    }

    // Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
        content: SizedBox(
          width: 420.w,
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  "Consultando a Cora (debug)...",
                  style: GoogleFonts.inter(fontSize: 14.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await InvoiceService().debugCoraInvoice(
        externalId: externalId,
        token: token,
      );

      if (context.mounted) Navigator.of(context).pop(); // fecha loading

      final pretty = const JsonEncoder.withIndent('  ').convert(result);

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFE3E6D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.magnifying_glass_bold,
                    color: Colors.white, size: 22.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    "Debug Cora",
                    style: GoogleFonts.sairaCondensed(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "Copiar JSON",
                  icon: const Icon(PhosphorIcons.copy_simple_bold,
                      color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pretty));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("JSON copiado!")),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 520.w,
            child: SingleChildScrollView(
              child: SelectableText(
                pretty,
                style: GoogleFonts.robotoMono(fontSize: 12.sp),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop(); // fecha loading

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao consultar Cora: $e")),
      );
    }
  }

  Widget _buildQrImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return _buildErrorContainer();
    }

    try {
      String cleanString = base64String;
      if (cleanString.contains(',')) {
        cleanString = cleanString.split(',').last;
      }
      cleanString = cleanString.replaceAll(RegExp(r'\s+'), '');

      int remainder = cleanString.length % 4;
      if (remainder > 0) {
        cleanString =
            cleanString.padRight(cleanString.length + (4 - remainder), '=');
      }

      final bytes = base64Decode(cleanString);

      return Image.memory(
        bytes,
        width: 200.w,
        height: 200.h,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorContainer(),
      );
    } catch (e) {
      return _buildErrorContainer();
    }
  }

  Widget _buildErrorContainer() {
    return Container(
      width: 200.w,
      height: 200.h,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.warning_circle, size: 32.sp, color: Colors.grey),
          SizedBox(height: 8.h),
          const Text('QR Code indisponível', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
        title: Row(
          children: [
            Icon(PhosphorIcons.warning_circle_bold, color: Colors.red.shade700),
            SizedBox(width: 10.w),
            const Text('Atenção'),
          ],
        ),
        content: const Text(
            'Deseja realmente cancelar esta fatura? Essa ação é irreversível.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Voltar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              if (onCancel != null) onCancel!(invoice.id);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Sim, Cancelar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter =
        intl.NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final valorEmReais = (invoice.value / 100.0);
    final status = invoice.status.toLowerCase().trim();
    final gateway = invoice.gateway?.toLowerCase() ?? '';

    // --- LÓGICA DE DECISÃO DE UI (CORRIGIDA) ---

    // É Pix se: O Gateway for explicitamente MP OU tiver QR Code (e estiver pendente)
    final bool isPix =
        (gateway == 'mercadopago' || invoice.pixQrBase64 != null) &&
            status == 'pending';

    // É Boleto se: NÃO for Pix E (Gateway for Cora OU tiver código de barras) (e estiver pendente)
    // O Mercado Pago também manda boletoUrl (ticket), por isso a checagem !isPix é vital.
    final bool isBoleto = !isPix &&
        (gateway == 'cora' ||
            invoice.boletoBarcode != null ||
            invoice.boletoUrl != null) &&
        status == 'pending';

    // Cores e Ícones
    Color headerColor = Colors.blueAccent.shade700;
    IconData headerIcon = PhosphorIcons.money;
    String headerTitle = "Detalhes da Cobrança";

    if (gateway == 'cora') {
      headerColor = const Color(0xFFFE3E6D);
      headerIcon = PhosphorIcons.barcode;
      headerTitle = "Boleto Cora";
    } else if (gateway == 'mercadopago') {
      headerColor = const Color(0xFF009EE3);
      headerIcon = PhosphorIcons.qr_code;
      headerTitle = "Pix Mercado Pago";
    }

    final bool showCoraDebug = gateway == 'cora' &&
        (invoice.externalId != null && invoice.externalId!.trim().isNotEmpty);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      backgroundColor: Colors.white,
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.symmetric(horizontal: 25.w)
          .copyWith(top: 10.h, bottom: 20.h),

      // CABEÇALHO
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: headerColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(headerIcon, color: Colors.white, size: 26.sp),
                SizedBox(width: 12.w),
                Text(
                  headerTitle,
                  style: GoogleFonts.sairaCondensed(
                      fontWeight: FontWeight.bold,
                      fontSize: 22.sp,
                      color: Colors.white),
                ),
              ],
            ),
            Row(
              children: [
                if (showCoraDebug)
                  IconButton(
                    tooltip: "Debug Cora",
                    icon: Icon(
                      PhosphorIcons.magnifying_glass_bold,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                    onPressed: () => _showCoraDebug(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),

      content: SizedBox(
        width: 450.w,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 15.h),
              Text(
                invoice.student?.fullName ?? 'Aluno não vinculado',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 18.sp),
              ),
              Text(
                'Tutor: ${invoice.tutor?.fullName ?? 'N/A'}',
                style: GoogleFonts.inter(
                    fontSize: 14.sp, color: Colors.grey.shade700),
              ),
              Divider(height: 20.h),
              _buildInfoRow('Valor:', formatter.format(valorEmReais)),
              _buildInfoRow('Vencimento:',
                  intl.DateFormat('dd/MM/yyyy').format(invoice.dueDate)),
              _buildInfoRow('Descrição:', invoice.description),

              // --- STATUS E PAGAMENTO ---

              if (status == 'paid') ...[
                Divider(height: 30.h),
                _buildStatusMessage('Esta fatura já foi paga.',
                    Colors.green.shade700, PhosphorIcons.check_circle_fill),
              ] else if (status == 'canceled') ...[
                Divider(height: 30.h),
                _buildStatusMessage('Esta fatura está cancelada.', Colors.grey,
                    PhosphorIcons.prohibit),
              ] else if (isPix) ...[
                // --- UI PIX (MERCADO PAGO) ---
                Divider(height: 30.h),
                Center(
                  child: Text('Escaneie o QR Code',
                      style: GoogleFonts.sairaCondensed(
                          fontWeight: FontWeight.bold, fontSize: 20.sp)),
                ),
                SizedBox(height: 15.h),

                // Imagem QR (Usando o novo campo genérico pixQrBase64)
                Center(child: _buildQrImage(invoice.pixQrBase64)),

                SizedBox(height: 15.h),

                // Copia e Cola (Usando o novo campo genérico pixCode)
                if (invoice.pixCode != null)
                  _buildCopyField(context, "Pix Copia e Cola", invoice.pixCode!,
                      PhosphorIcons.copy_simple),
              ] else if (isBoleto) ...[
                // --- UI BOLETO (CORA) ---
                Divider(height: 30.h),
                Center(
                  child: Text('Pagamento via Boleto',
                      style: GoogleFonts.sairaCondensed(
                          fontWeight: FontWeight.bold, fontSize: 20.sp)),
                ),
                SizedBox(height: 20.h),

                // Botão Visualizar PDF
                if (invoice.boletoUrl != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchBoleto(context),
                      icon: const Icon(PhosphorIcons.file_pdf,
                          color: Colors.white),
                      label: const Text("Visualizar Boleto (PDF)",
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerColor,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r)),
                      ),
                    ),
                  ),

                SizedBox(height: 15.h),

                // Linha Digitável
                if (invoice.boletoBarcode != null)
                  _buildCopyField(context, "Linha Digitável",
                      invoice.boletoBarcode!, PhosphorIcons.barcode),
              ]
            ],
          ),
        ),
      ),

      actions: [
        if (_canBeCanceled && onCancel != null)
          Padding(
            padding: EdgeInsets.only(right: 15.w, bottom: 10.h),
            child: TextButton.icon(
              icon: Icon(PhosphorIcons.trash_bold,
                  color: Colors.red.shade700, size: 20.sp),
              label: Text('Cancelar Fatura',
                  style: GoogleFonts.inter(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp)),
              onPressed: () => _showConfirmationDialog(context),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusMessage(String msg, Color color, IconData icon) {
    return Center(
      child: Column(
        children: [
          Icon(icon, size: 40.sp, color: color),
          SizedBox(height: 10.h),
          Text(msg,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, fontSize: 16.sp, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 5.h),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 15.sp, color: Colors.black87),
          children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyField(
      BuildContext context, String label, String value, IconData icon) {
    return TextField(
      controller: TextEditingController(text: value),
      readOnly: true,
      maxLines: 2,
      style: GoogleFonts.inter(fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: const Icon(PhosphorIcons.copy_simple_bold),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copiado!')),
            );
          },
        ),
      ),
    );
  }
}
