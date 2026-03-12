import 'dart:convert';

import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/model/tutor_model.dart';
import 'package:academyhub_mobile/popup/feedback_popup.dart';
import 'package:academyhub_mobile/providers/invoice_provider.dart';
import 'package:academyhub_mobile/services/student_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

class CreateInvoiceDialog extends StatefulWidget {
  final String token;
  final List<Enrollment> activeEnrollments;
  final VoidCallback onSaveSuccess;

  const CreateInvoiceDialog({
    super.key,
    required this.token,
    required this.activeEnrollments,
    required this.onSaveSuccess,
  });

  @override
  State<CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends State<CreateInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final StudentService _studentService = StudentService();

  // Controllers
  final _descriptionController = TextEditingController();
  final _feeController = TextEditingController();
  final _dueDayController = TextEditingController(text: '10');
  final _searchController = TextEditingController();

  // Estado da Seleção
  String? _selectedClassFilter; // Filtro de Turma
  Enrollment? _selectedEnrollment;
  Student? _fullStudentDetails;
  bool _isStudentLoading = false;

  List<Tutor> _availableOptions = [];
  Tutor? _selectedOption;

  // Estado do Gateway
  String _selectedGateway = 'mercadopago';

  // Controle de Meses
  final Map<int, bool> _selectedMonths = {
    1: false,
    2: false,
    3: false,
    4: false,
    5: false,
    6: false,
    7: false,
    8: false,
    9: false,
    10: false,
    11: false,
    12: false,
  };

  // Cache visual para "Já Faturados"
  final Set<String> _studentsBilledRecently = {};

  @override
  void initState() {
    super.initState();
    // Executa após o build para ter acesso ao Provider com segurança
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _identifyAlreadyBilledStudents();
    });
  }

  /// [UX/Lógica] Identifica alunos com faturas geradas recentemente.
  /// Verifica mês atual e próximo mês para cobrir adiantamentos.
  void _identifyAlreadyBilledStudents() {
    try {
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);
      final allInvoices = invoiceProvider.allInvoices;
      final now = DateTime.now();

      setState(() {
        _studentsBilledRecently.clear();
        for (var inv in allInvoices) {
          // Ignora cancelados
          if (inv.status == 'canceled') continue;

          // Verifica se o vencimento é neste mês ou no próximo
          // Isso cobre o cenário de "Início de ano" onde estamos em Jan gerando Fev
          final isCurrentMonth =
              inv.dueDate.month == now.month && inv.dueDate.year == now.year;

          // Lógica para próximo mês (Ex: Estamos em Jan, boleto é Fev)
          final nextMonthDate = DateTime(now.year, now.month + 1, 1);
          final isNextMonth = inv.dueDate.month == nextMonthDate.month &&
              inv.dueDate.year == nextMonthDate.year;

          if (isCurrentMonth || isNextMonth) {
            if (inv.student != null) {
              _studentsBilledRecently.add(inv.student!.id);
            }
          }
        }
      });
    } catch (e) {
      print("Erro ao verificar faturas existentes: $e");
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _feeController.dispose();
    _dueDayController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE FILTRAGEM E ORDENAÇÃO ---

  List<String> get _uniqueClasses {
    final classes =
        widget.activeEnrollments.map((e) => e.classInfo.name).toSet().toList();
    classes.sort((a, b) => a.compareTo(b));
    return classes;
  }

  List<Enrollment> get _filteredAndSortedEnrollments {
    // 1. Filtro de Turma
    var list = widget.activeEnrollments;
    if (_selectedClassFilter != null && _selectedClassFilter != 'Todas') {
      list =
          list.where((e) => e.classInfo.name == _selectedClassFilter).toList();
    }

    // 2. Ordenação Inteligente
    list.sort((a, b) {
      final aBilled = _studentsBilledRecently.contains(a.student.id);
      final bBilled = _studentsBilledRecently.contains(b.student.id);

      // Quem JÁ tem boleto vai para o final da lista
      if (aBilled && !bBilled) return 1;
      if (!aBilled && bBilled) return -1;

      // Desempate alfabético
      return a.student.fullName.compareTo(b.student.fullName);
    });

    return list;
  }

  void _showOverlayFeedback(
      {required String title, required String message, bool isError = false}) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => FeedbackPopup(
        title: title,
        message: message,
        isError: isError,
        onAnimationFinished: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  void _onEnrollmentChanged(Enrollment? newEnrollment) async {
    setState(() {
      _selectedEnrollment = newEnrollment;
      _selectedOption = null;
      _availableOptions = [];
      _fullStudentDetails = null;
      _selectedMonths.updateAll((key, value) => false);
    });

    if (newEnrollment != null) {
      setState(() => _isStudentLoading = true);

      try {
        final fullStudent = await _studentService.getStudentById(
            newEnrollment.student.id, widget.token);

        List<Tutor> options = [];
        Tutor? defaultOption;

        if (fullStudent.financialResp == 'STUDENT') {
          final studentAsPayer = Tutor(
            id: fullStudent.id,
            fullName: fullStudent.fullName,
            cpf: fullStudent.cpf,
            email: fullStudent.email,
            phoneNumber: fullStudent.phoneNumber!,
            birthDate: fullStudent.birthDate,
            gender: fullStudent.gender,
            nationality: fullStudent.nationality,
            address: fullStudent.address,
            schoolId: fullStudent.schoolId,
          );
          options.add(studentAsPayer);
          defaultOption = studentAsPayer;
        } else {
          options = fullStudent.tutors.map((t) => t.tutorInfo).toList();
          if (fullStudent.financialTutorId != null) {
            try {
              defaultOption = options
                  .firstWhere((t) => t.id == fullStudent.financialTutorId);
            } catch (e) {
              if (options.isNotEmpty) defaultOption = options.first;
            }
          } else if (options.isNotEmpty) {
            defaultOption = options.first;
          }
        }

        setState(() {
          _fullStudentDetails = fullStudent;
          _availableOptions = options;
          _selectedOption = defaultOption;
          _isStudentLoading = false;

          final feeInReais = newEnrollment.agreedFee;
          _feeController.text =
              feeInReais.toStringAsFixed(2).replaceAll('.', ',');

          // Seleção automática do mês com base na data atual
          // Se hoje é dia 20+, sugere o mês seguinte. Se antes, mês atual.
          final now = DateTime.now();
          int targetMonth = now.day > 20 ? now.month + 1 : now.month;
          if (targetMonth > 12) targetMonth = 1; // Virada de ano

          if (_selectedMonths.containsKey(targetMonth)) {
            _selectedMonths[targetMonth] = true;
          }
        });
      } catch (e) {
        setState(() => _isStudentLoading = false);
        _showOverlayFeedback(
            title: "Erro no Carregamento",
            message: "Não foi possível buscar dados do aluno: ${e.toString()}",
            isError: true);
      }
    } else {
      setState(() => _feeController.clear());
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEnrollment == null || _selectedOption == null) {
      _showOverlayFeedback(
          title: "Dados Incompletos",
          message: "Selecione um aluno e o responsável financeiro.",
          isError: true);
      return;
    }

    // Pega os índices dos meses selecionados e ORDENA para garantir que Janeiro venha antes de Fevereiro
    final selectedMonthIndexes = _selectedMonths.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList()
      ..sort(); // Ordenação importante para a lógica de "Primeiro mês envia agora"

    if (selectedMonthIndexes.isEmpty) {
      _showOverlayFeedback(
          title: "Atenção",
          message: "Selecione pelo menos um mês para gerar a cobrança.",
          isError: true);
      return;
    }

    final currentYear = DateTime.now().year;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final dueDay = int.parse(_dueDayController.text);

    for (int month in selectedMonthIndexes) {
      // Ajuste de Ano: Se estamos em Dezembro gerando Janeiro, o ano é nextYear
      int year = currentYear;
      if (now.month == 12 && month == 1) {
        year = currentYear + 1;
      }

      final dueDate = DateTime(year, month, dueDay);
      if (dueDate.isBefore(todayMidnight)) {
        final monthName =
            intl.DateFormat.MMMM('pt_BR').format(DateTime(currentYear, month));
        _showOverlayFeedback(
            title: "Data Inválida",
            message: "O vencimento de $monthName (dia $dueDay) já passou.",
            isError: true);
        return;
      }
    }

    final feeString = _feeController.text.replaceAll(',', '.');
    final feeInReais = double.tryParse(feeString);
    if (feeInReais == null || feeInReais <= 0) {
      _showOverlayFeedback(
          title: "Valor Inválido",
          message: "Verifique o valor da mensalidade.",
          isError: true);
      return;
    }
    final feeInCents = (feeInReais * 100).toInt();

    setState(() => _isLoading = true);

    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final studentId = _selectedEnrollment!.student.id;
    final studentName = _selectedEnrollment!.student.fullName;
    final payerId = _selectedOption!.id;

    List<Future> apiCalls = [];

    // Loop para criar as chamadas de API
    for (int i = 0; i < selectedMonthIndexes.length; i++) {
      final int month = selectedMonthIndexes[i];

      // [REGRA DE NEGÓCIO] A primeira fatura da lista é enviada IMEDIATAMENTE (sendNow: true)
      // As demais (i > 0) seguem a regra padrão (false/null)
      final bool shouldSendNow = (i == 0);

      // Ajuste de Ano para a requisição
      int year = currentYear;
      if (now.month == 12 && month == 1) year = currentYear + 1;

      final monthName =
          intl.DateFormat.MMMM('pt_BR').format(DateTime(year, month));
      final monthNameCap = monthName[0].toUpperCase() + monthName.substring(1);

      final dueDate = DateTime(year, month, dueDay);

      final description = _descriptionController.text.isNotEmpty
          ? '${_descriptionController.text} - $monthNameCap'
          : 'Mensalidade $monthNameCap - $studentName';

      String paymentMethod = 'pix';
      if (_selectedGateway == 'cora') {
        paymentMethod = 'boleto';
      }

      final data = {
        'studentId': studentId,
        'tutorId': payerId,
        'value': feeInCents,
        'dueDate': dueDate.toIso8601String(),
        'description': description,
        'gateway': _selectedGateway,
        'paymentMethod': paymentMethod,
        'sendNow': shouldSendNow, // [NOVO] Parâmetro para o Backend
      };

      apiCalls.add(invoiceProvider.createInvoice(
        data: data,
        token: widget.token,
      ));
    }

    try {
      await Future.wait(apiCalls);
      setState(() => _isLoading = false);
      Navigator.of(context).pop();
      widget.onSaveSuccess();
      _showOverlayFeedback(
          title: "Sucesso!",
          message: "${apiCalls.length} cobrança(s) gerada(s).",
          isError: false);
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = e.toString().replaceAll("Exception:", "").trim();

      // [CORREÇÃO ROBUSTA] Procura pelo JSON dentro da string, ignorando prefixos
      try {
        int startIndex = errorMessage.indexOf('{');
        int endIndex = errorMessage.lastIndexOf('}');

        // Se encontrou chaves de abertura e fechamento válidas
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          String jsonString = errorMessage.substring(startIndex, endIndex + 1);
          final errorJson = jsonDecode(jsonString);

          if (errorJson['message'] != null) {
            errorMessage = errorJson['message'];
          }
        }
      } catch (_) {
        // Se falhar o decode, mantém a mensagem original
      }

      // [MANTÉM AS SUAS VERIFICAÇÕES ANTIGAS COMO FALLBACK]
      if (errorMessage.contains("customer.document.identity") ||
          errorMessage.contains("CPF") ||
          errorMessage.contains("CNPJ")) {
        errorMessage =
            "O CPF do responsável financeiro é inválido ou está incorreto. Por favor, verifique o cadastro.";
      }

      if (errorMessage.contains("<!DOCTYPE html>") ||
          errorMessage.contains("<html>")) {
        errorMessage =
            "Erro interno no servidor ou no banco. Por favor, tente novamente em instantes.";
      }

      if (errorMessage.contains("SocketException") ||
          errorMessage.contains("Connection refused")) {
        errorMessage = "Sem conexão com a internet ou servidor indisponível.";
      }

      _showOverlayFeedback(
          title: "Não foi possível gerar",
          message: errorMessage,
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDark ? Colors.blueAccent : Colors.blue[600];
    final successColor =
        isDark ? Colors.greenAccent.shade700 : Colors.green[600];
    final labelStyle = TextStyle(
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87);
    final dialogBg = theme.cardColor;

    final classList = ['Todas', ..._uniqueClasses];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: dialogBg,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Container(
        width: 900.w,
        height: 780.h,
        padding: EdgeInsets.all(32.w),
        child: Column(
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gerar Nova Cobrança',
                        style: GoogleFonts.sairaCondensed(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black)),
                    Text('Preencha os dados para criar faturas manuais.',
                        style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color:
                                isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      color: isDark ? Colors.grey[400] : Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(
                height: 30.h,
                color: isDark ? Colors.grey[700] : Colors.grey[300]),

            // --- BODY ---
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor))
                  : SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // BLOCO 1: QUEM PAGA?
                            Text("Dados do Pagador",
                                style: labelStyle.copyWith(
                                    fontSize: 18.sp, color: primaryColor)),
                            SizedBox(height: 15.h),

                            // --- FILTRO DE TURMA ---
                            _buildLabelledField(
                              label: "Filtrar por Turma",
                              isDark: isDark,
                              child: _buildSimpleDropdown(
                                hint: 'Selecione a Turma para filtrar',
                                value: _selectedClassFilter,
                                items: classList,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedClassFilter = val;
                                    _selectedEnrollment = null;
                                    _selectedOption = null;
                                  });
                                },
                                isDark: isDark,
                              ),
                            ),
                            SizedBox(height: 15.h),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildLabelledField(
                                    label: "Aluno",
                                    isDark: isDark,
                                    child: _buildDropdownSearch(
                                      hint: 'Selecione o Aluno',
                                      selectedValue: _selectedEnrollment,
                                      items: _filteredAndSortedEnrollments,
                                      // [UX] Passamos o objeto Enrollment inteiro para o builder
                                      // para que ele possa verificar o ID do aluno
                                      itemBuilder: (e) {
                                        // Apenas o nome para o campo de busca textual
                                        return '${e.student.fullName} - ${e.classInfo.name}';
                                      },
                                      onChanged: _onEnrollmentChanged,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 20.w),
                                Expanded(
                                  flex: 2,
                                  child: _buildLabelledField(
                                    label: "Responsável Financeiro",
                                    isDark: isDark,
                                    child: _buildDropdown(
                                      hint: _isStudentLoading
                                          ? 'Buscando...'
                                          : 'Selecione o Responsável',
                                      selectedValue: _selectedOption,
                                      items: _availableOptions,
                                      itemBuilder: (t) {
                                        bool isStudent =
                                            t.id == _fullStudentDetails?.id;
                                        return '${t.fullName} ${isStudent ? "(Aluno)" : ""}';
                                      },
                                      onChanged: (val) =>
                                          setState(() => _selectedOption = val),
                                      isEnabled: _selectedEnrollment != null,
                                      isLoading: _isStudentLoading,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 30.h),

                            // BLOCO 2: DETALHES FINANCEIROS
                            Text("Detalhes da Cobrança",
                                style: labelStyle.copyWith(
                                    fontSize: 18.sp, color: primaryColor)),
                            SizedBox(height: 15.h),

                            // SELEÇÃO DE GATEWAY
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGatewayCard(
                                    id: 'mercadopago',
                                    label: 'Mercado Pago (Pix)',
                                    icon: PhosphorIcons.qr_code,
                                    color: const Color(0xFF009EE3),
                                    isDark: isDark,
                                  ),
                                ),
                                SizedBox(width: 20.w),
                                Expanded(
                                  child: _buildGatewayCard(
                                    id: 'cora',
                                    label: 'Banco Cora (Boleto)',
                                    icon: PhosphorIcons.barcode,
                                    color: const Color(0xFFFE3E6D),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20.h),

                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: _buildLabelledField(
                                    label: "Valor (R\$)",
                                    isDark: isDark,
                                    child: CustomTextFormField(
                                      controller: _feeController,
                                      hintText: '0,00',
                                      prefixIcon: Icon(
                                          PhosphorIcons.currency_dollar,
                                          size: 20,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey),
                                      validator: (val) {
                                        if (val == null || val.isEmpty)
                                          return 'Obrigatório';
                                        return null;
                                      },
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 20.w),
                                Expanded(
                                  flex: 1,
                                  child: _buildLabelledField(
                                    label: "Dia de Vencimento",
                                    isDark: isDark,
                                    child: CustomTextFormField(
                                      controller: _dueDayController,
                                      hintText: '10',
                                      prefixIcon: Icon(PhosphorIcons.calendar,
                                          size: 20,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey),
                                      validator: (val) {
                                        final d = int.tryParse(val ?? '');
                                        if (d == null || d < 1 || d > 31)
                                          return 'Inválido';
                                        return null;
                                      },
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 20.w),
                                Expanded(
                                  flex: 2,
                                  child: _buildLabelledField(
                                    label: "Descrição (Opcional)",
                                    isDark: isDark,
                                    child: CustomTextFormField(
                                      controller: _descriptionController,
                                      hintText: 'Ex: Taxa de Material...',
                                      prefixIcon: Icon(
                                          PhosphorIcons.pencil_simple,
                                          size: 20,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey),
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 30.h),

                            // BLOCO 3: MESES
                            Text("Meses de Referência",
                                style: labelStyle.copyWith(
                                    fontSize: 18.sp, color: primaryColor)),
                            SizedBox(height: 5.h),
                            Text(
                                "Selecione um ou mais meses para gerar as faturas em lote.",
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize: 13.sp)),
                            SizedBox(height: 15.h),
                            _buildMonthSelector(isDark),
                          ],
                        ),
                      ),
                    ),
            ),

            // --- FOOTER ---
            Divider(
                height: 30.h,
                color: isDark ? Colors.grey[700] : Colors.grey[300]),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding:
                        EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h),
                    foregroundColor:
                        isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  child: Text('Cancelar',
                      style: GoogleFonts.inter(
                          fontSize: 16.sp, fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: 16.w),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: const Icon(PhosphorIcons.check, size: 20),
                  label: Text(
                    'Gerar ${_selectedMonths.values.where((v) => v).length} Cobrança(s)',
                    style: GoogleFonts.inter(
                        fontSize: 16.sp, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: successColor,
                    foregroundColor: Colors.white,
                    padding:
                        EdgeInsets.symmetric(horizontal: 32.w, vertical: 18.h),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildGatewayCard({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedGateway == id;
    final bgColor = isSelected
        ? color.withOpacity(0.1)
        : (isDark ? Colors.grey[800] : Colors.grey[50]);
    final borderColor =
        isSelected ? color : (isDark ? Colors.grey[700]! : Colors.grey[300]!);

    return InkWell(
      onTap: () => setState(() => _selectedGateway = id),
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 24.sp),
            SizedBox(width: 10.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 10.w),
              Icon(PhosphorIcons.check_circle_fill, color: color, size: 20.sp),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLabelledField(
      {required String label, required Widget child, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[800])),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }

  Widget _buildMonthSelector(bool isDark) {
    final List<String> months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];

    final containerBg = isDark ? Colors.grey[800] : Colors.grey[50];
    final containerBorder = isDark ? Colors.grey[700]! : Colors.grey[200]!;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: containerBorder)),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 12.h,
        children: List.generate(12, (index) {
          final m = index + 1;

          final isSelected = _selectedMonths[m] ?? false;

          final chipBg = isDark ? Colors.grey[700] : Colors.white;
          final selectedChipBg = isDark ? Colors.blue[900] : Colors.blue[100];
          final selectedText = isDark ? Colors.blue[100] : Colors.blue[900];
          final normalText = isDark ? Colors.grey[300] : Colors.grey[800];
          final chipBorder = isSelected
              ? (isDark ? Colors.blue[800]! : Colors.blue[200]!)
              : (isDark ? Colors.grey[600]! : Colors.grey[300]!);

          return FilterChip(
            label: Text(months[index]),
            selected: isSelected,
            onSelected: (val) => setState(() => _selectedMonths[m] = val),
            selectedColor: selectedChipBg,
            checkmarkColor: isDark ? Colors.blueAccent : Colors.blue[800],
            labelStyle: TextStyle(
                color: isSelected ? selectedText : normalText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            backgroundColor: chipBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
                side: BorderSide(color: chipBorder)),
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          );
        }),
      ),
    );
  }

  // Dropdown Simples (Turma)
  Widget _buildSimpleDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required bool isDark,
  }) {
    final bgColor = isDark ? Colors.grey[800] : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final dropdownBg = Theme.of(context).cardColor;

    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        hint: Text(hint, style: TextStyle(color: hintColor, fontSize: 14.sp)),
        items: items
            .map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item,
                      style: TextStyle(color: textColor, fontSize: 14.sp),
                      overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        value: value,
        onChanged: onChanged,
        buttonStyleData: ButtonStyleData(
          height: 50.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: borderColor),
          ),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          decoration: BoxDecoration(
              color: dropdownBg,
              borderRadius: BorderRadius.circular(8.r),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ]),
        ),
        menuItemStyleData: MenuItemStyleData(height: 40.h),
      ),
    );
  }

  // [CORREÇÃO VISUAL] Dropdown de Aluno com Row e Ícone
  Widget _buildDropdownSearch(
      {required String hint,
      required Enrollment? selectedValue,
      required List<Enrollment> items,
      required String Function(Enrollment) itemBuilder,
      required Function(Enrollment?) onChanged,
      required bool isDark}) {
    final bgColor = isDark ? Colors.grey[800] : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final dropdownBg = Theme.of(context).cardColor;

    return DropdownButtonHideUnderline(
      child: DropdownButton2<Enrollment>(
        isExpanded: true,
        hint: Text(hint, style: TextStyle(color: hintColor, fontSize: 14.sp)),
        items: items.map((item) {
          // Verifica se está na lista de "recentes"
          final isBilled = _studentsBilledRecently.contains(item.student.id);

          final mainColor = isBilled
              ? (isDark
                  ? Colors.grey[500]
                  : Colors.grey[400]) // Cinza se já tem boleto
              : textColor;

          return DropdownMenuItem(
            value: item,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nome do Aluno + Turma
                Flexible(
                  child: Text(
                    '${item.student.fullName} - ${item.classInfo.name}',
                    style: TextStyle(color: mainColor, fontSize: 14.sp),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // [NOVO] Feedback visual claro (Badge)
                if (isBilled)
                  Container(
                    margin: EdgeInsets.only(left: 8.w),
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIcons.check_circle_fill,
                            color: Colors.green, size: 14.sp),
                        SizedBox(width: 4.w),
                        Text(
                          "Gerado",
                          style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 10.sp),
                        )
                      ],
                    ),
                  )
              ],
            ),
          );
        }).toList(),
        value: selectedValue,
        onChanged: onChanged,
        buttonStyleData: ButtonStyleData(
          height: 50.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: borderColor),
          ),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          decoration: BoxDecoration(
              color: dropdownBg,
              borderRadius: BorderRadius.circular(8.r),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ]),
        ),
        menuItemStyleData: MenuItemStyleData(height: 40.h),
        dropdownSearchData: DropdownSearchData(
          searchController: _searchController,
          searchInnerWidgetHeight: 60,
          searchInnerWidget: Padding(
            padding: const EdgeInsets.all(8),
            child: TextFormField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  hintText: 'Pesquisar Aluno...',
                  hintStyle: TextStyle(fontSize: 12, color: hintColor),
                  prefixIcon: Icon(Icons.search, size: 20, color: hintColor),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue))),
            ),
          ),
          searchMatchFn: (item, searchValue) {
            final enrollment = item.value;
            // Busca no nome do aluno
            final name = enrollment?.student.fullName.toLowerCase() ?? '';
            return name.contains(searchValue.toLowerCase());
          },
        ),
        onMenuStateChange: (isOpen) {
          if (!isOpen) _searchController.clear();
        },
      ),
    );
  }

  Widget _buildDropdown(
      {required String hint,
      required Tutor? selectedValue,
      required List<Tutor> items,
      required String Function(Tutor) itemBuilder,
      required Function(Tutor?) onChanged,
      bool isEnabled = true,
      bool isLoading = false,
      required bool isDark}) {
    final bgColor = isEnabled
        ? (isDark ? Colors.grey[800] : Colors.white)
        : (isDark ? Colors.grey[900] : Colors.grey[100]);
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final dropdownBg = Theme.of(context).cardColor;

    return DropdownButtonHideUnderline(
      child: DropdownButton2<Tutor>(
          isExpanded: true,
          hint: Text(isLoading ? "Buscando..." : hint,
              style: TextStyle(
                  color: isLoading ? Colors.blue : hintColor, fontSize: 14.sp)),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(itemBuilder(item),
                        style: TextStyle(color: textColor, fontSize: 14.sp),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          value: selectedValue,
          onChanged: isEnabled && !isLoading ? onChanged : null,
          buttonStyleData: ButtonStyleData(
            height: 50.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: borderColor),
            ),
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
                color: dropdownBg,
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 5))
                ]),
          )),
    );
  }
}

class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final bool isDark;

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.hintText,
    this.validator,
    this.prefixIcon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isDark ? Colors.grey[800] : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[500] : Colors.grey[400];

    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(fontSize: 14.sp, color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: hintColor),
        prefixIcon: prefixIcon,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 1.5)),
        filled: true,
        fillColor: fillColor,
      ),
    );
  }
}
