import 'package:academyhub_mobile/model/registration_request_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/registration_request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RequestDetailsDialog extends StatefulWidget {
  final RegistrationRequest request;
  final Function() onApprove;
  final Function() onReject;

  const RequestDetailsDialog({
    Key? key,
    required this.request,
    required this.onApprove,
    required this.onReject,
  }) : super(key: key);

  @override
  State<RequestDetailsDialog> createState() => _RequestDetailsDialogState();
}

class _RequestDetailsDialogState extends State<RequestDetailsDialog>
    with SingleTickerProviderStateMixin {
  final RegistrationRequestService _service = RegistrationRequestService();
  bool _isProcessing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token!;
      await _service.approveRequest(token, widget.request.id);
      widget.onApprove();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isProcessing = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token!;
      await _service.rejectRequest(
          token, widget.request.id, "Rejeitado pelo gestor");
      widget.onReject();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cores adaptadas
    final cardColor = theme.cardColor;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);

    return Dialog(
      // [UX Mobile] Margens laterais pequenas para aproveitar a largura
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: cardColor,
      child: Container(
        width: double.infinity,
        // [UX Mobile] Altura máxima de 85% da tela para não cobrir tudo
        constraints: BoxConstraints(maxHeight: 0.85.sh, maxWidth: 500.w),
        child: Column(
          children: [
            // --- HEADER ---
            _buildHeader(isDark, textPrimary, textSecondary),

            // --- TABS ---
            Container(
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color:
                              isDark ? Colors.grey[800]! : Colors.grey[200]!))),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF00A859),
                unselectedLabelColor: textSecondary,
                indicatorColor: const Color(0xFF00A859),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 12.sp),
                tabs: const [
                  Tab(text: "Dados"),
                  Tab(text: "Saúde"),
                  Tab(text: "Contato"),
                ],
              ),
            ),

            // --- CONTEÚDO DAS ABAS ---
            Expanded(
              child: Container(
                color: bgColor,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabPersonal(isDark),
                    _buildTabHealth(isDark),
                    _buildTabContact(isDark),
                  ],
                ),
              ),
            ),

            // --- FOOTER (BOTÕES) ---
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // --- WIDGETS ESTRUTURAIS ---
  // ---------------------------------------------------------------------------

  Widget _buildHeader(bool isDark, Color textPrimary, Color? textSecondary) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 10.w, 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                      color: const Color(0xFF00A859).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(PhosphorIcons.student_bold,
                      color: const Color(0xFF00A859), size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Solicitação",
                          style: GoogleFonts.sairaCondensed(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: textPrimary)),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(widget.request.createdAt),
                        style: GoogleFonts.inter(
                            fontSize: 12.sp, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
            top: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : _reject,
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r))),
              child: const Text("Rejeitar"),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _approve,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A859),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                  elevation: 0),
              child: _isProcessing
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("Aprovar"),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // --- CONTEÚDO DAS ABAS ---
  // ---------------------------------------------------------------------------

  Widget _buildTabPersonal(bool isDark) {
    final sData = widget.request.studentData;
    final tData = widget.request.tutorData;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // CARD ALUNO
          _buildInfoCard("Dados do Aluno", PhosphorIcons.student, isDark, [
            _infoRow("Nome Completo", sData['fullName'], isDark),
            _infoRow("Data Nasc.", _formatDate(sData['birthDate']), isDark),
            _infoRow("CPF", sData['cpf'], isDark),
            _infoRow("RG", sData['rg'], isDark),
            _infoRow("Gênero", sData['gender'], isDark),
            _infoRow("Nacionalidade", sData['nationality'], isDark),
          ]),

          SizedBox(height: 16.h),

          // CARD RESPONSÁVEL
          _buildInfoCard(
              tData != null ? "Responsável Financeiro" : "Responsável",
              PhosphorIcons.currency_dollar,
              isDark,
              tData != null
                  ? [
                      _infoRow("Nome", tData['fullName'], isDark),
                      _infoRow("Parentesco", tData['relationship'], isDark),
                      _infoRow("CPF", tData['cpf'], isDark),
                      _infoRow("Email", tData['email'], isDark),
                      _infoRow("Telefone", tData['phoneNumber'], isDark),
                    ]
                  : [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Text(
                            "O próprio aluno é o responsável financeiro.",
                            style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic)),
                      )
                    ]),
        ],
      ),
    );
  }

  Widget _buildTabHealth(bool isDark) {
    final hData = widget.request.studentData['healthInfo'] ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildHealthBadge("Problema de Saúde", hData['hasHealthProblem'],
              hData['healthProblemDetails'], isDark),
          _buildHealthBadge("Uso de Medicamento", hData['takesMedication'],
              hData['medicationDetails'], isDark),
          _buildHealthBadge(
              "Alergias", hData['hasAllergy'], hData['allergyDetails'], isDark),
          _buildHealthBadge("Deficiência", hData['hasDisability'],
              hData['disabilityDetails'], isDark),
          SizedBox(height: 16.h),
          _buildInfoCard(
              "Cuidados Especiais", PhosphorIcons.first_aid, isDark, [
            _infoRow("Em caso de Febre",
                hData['feverMedication'] ?? 'Não informado', isDark),
            Divider(color: isDark ? Colors.grey[700] : Colors.grey[200]),
            _infoRow("Restrições Alimentares",
                hData['foodObservations'] ?? 'Nenhuma', isDark),
          ]),
        ],
      ),
    );
  }

  Widget _buildTabContact(bool isDark) {
    final sData = widget.request.studentData;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildInfoCard("Endereço", PhosphorIcons.map_pin, isDark, [
            _infoRow("Rua", sData['address']?['street'], isDark),
            _infoRow("Número", sData['address']?['number'], isDark),
            _infoRow("Bairro", sData['address']?['neighborhood'], isDark),
            _infoRow(
                "Cidade/UF",
                "${sData['address']?['city']} - ${sData['address']?['state']}",
                isDark),
            _infoRow("CEP", sData['address']?['zipCode'], isDark),
          ]),
          SizedBox(height: 16.h),
          _buildInfoCard("Contato Direto", PhosphorIcons.phone, isDark, [
            _infoRow("Celular Aluno", sData['phoneNumber'], isDark),
            _infoRow("Email Aluno", sData['email'], isDark),
          ]),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // --- COMPONENTES VISUAIS ---
  // ---------------------------------------------------------------------------

  Widget _buildInfoCard(
      String title, IconData icon, bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00A859), size: 18.sp),
              SizedBox(width: 8.w),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          Divider(
              height: 24.h,
              color: isDark ? Colors.grey[800] : Colors.grey[200]),
          ...children
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value?.toString() ?? '---',
                style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(
      String label, bool? hasCondition, String? details, bool isDark) {
    bool isActive = hasCondition == true;
    if (!isActive)
      return const SizedBox.shrink(); // Só mostra se tiver condição

    Color activeColor = Colors.redAccent;
    Color bg = isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: activeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: activeColor, size: 20.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                        fontSize: 13.sp)),
              ),
              Text("SIM",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: activeColor,
                      fontSize: 12.sp)),
            ],
          ),
          if (details != null && details.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(details,
                  style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.black87,
                      fontSize: 12.sp)),
            )
          ]
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr.toString();
    }
  }
}
