import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/whatsapp_provider.dart';

class WhatsappConnectionDialog extends StatefulWidget {
  const WhatsappConnectionDialog({super.key});

  @override
  State<WhatsappConnectionDialog> createState() =>
      _WhatsappConnectionDialogState();
}

class _WhatsappConnectionDialogState extends State<WhatsappConnectionDialog> {
  @override
  void initState() {
    super.initState();
    // Ao abrir o dialog, verifica o status imediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        Provider.of<WhatsappProvider>(context, listen: false)
            .checkStatus(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wpProvider = Provider.of<WhatsappProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: Colors.white,
      child: Container(
        width: 400.w,
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.whatsapp_logo_fill,
                        color: Colors.green, size: 28.sp),
                    SizedBox(width: 10.w),
                    Text(
                      'Conexão WhatsApp',
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            SizedBox(height: 20.h),

            // Corpo Baseado no Estado
            _buildContent(wpProvider, authProvider.token!),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(WhatsappProvider provider, String token) {
    switch (provider.state) {
      case WhatsappConnectionState.loading:
        return SizedBox(
          height: 200.h,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.black),
          ),
        );

      case WhatsappConnectionState.connected:
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.check_circle_fill,
                  color: Colors.green, size: 64.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              'Conectado com Sucesso!',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'As cobranças automáticas estão ativas.',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => provider.logout(token),
                icon: const Icon(PhosphorIcons.sign_out, color: Colors.red),
                label: Text('Desconectar',
                    style: GoogleFonts.inter(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
          ],
        );

      case WhatsappConnectionState.pairing:
        return Column(
          children: [
            Text(
              'Escaneie o QR Code com seu WhatsApp',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16.h),
            if (provider.qrCodeBase64 != null)
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Image.memory(
                  const Base64Decoder().convert(
                    provider.qrCodeBase64!
                        .replaceFirst('data:image/png;base64,', ''),
                  ),
                  width: 220.w,
                  height: 220.w,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) =>
                      const Text('Erro ao exibir QR'),
                ),
              ),
            SizedBox(height: 16.h),
            Text(
              'Aguardando leitura...',
              style:
                  GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 5.h),
            const LinearProgressIndicator(
                color: Colors.black, backgroundColor: Colors.black12),
          ],
        );

      case WhatsappConnectionState.error:
        return Column(
          children: [
            Icon(PhosphorIcons.warning_circle_fill,
                color: Colors.red, size: 50.sp),
            SizedBox(height: 10.h),
            Text(
              'Erro na conexão',
              style: GoogleFonts.inter(
                  fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () => provider.checkStatus(token),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: Text('Tentar Novamente',
                  style: GoogleFonts.inter(color: Colors.white)),
            )
          ],
        );

      case WhatsappConnectionState.disconnected:
      default:
        return Column(
          children: [
            Icon(PhosphorIcons.phone_disconnect,
                color: Colors.grey, size: 60.sp),
            SizedBox(height: 16.h),
            Text(
              'WhatsApp Desconectado',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Conecte para enviar faturas e lembretes.',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => provider.generateQrCode(token),
                icon: const Icon(PhosphorIcons.qr_code, color: Colors.white),
                label: Text(
                  'Conectar Agora',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                ),
              ),
            ),
          ],
        );
    }
  }
}
