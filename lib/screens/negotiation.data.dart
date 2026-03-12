import 'dart:convert';
import 'package:academyhub_mobile/providers/negotiation_payment_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // IMPORTANTE

// --- PALETA DE CORES DA CORUJA academyhub_mobile ---
class AcademyColors {
  static const Color blackBody = Color(0xFF1E1E24); // Preto da coruja
  static const Color blueEye = Color(0xFF00AEEF); // Azul dos olhos
  static const Color greenArrow = Color(0xFF8CC63F); // Verde das setas
  static const Color background = Color(0xFFF4F6F8); // Fundo cinza claro
}

// --- MODELOS ---
class SimpleInvoiceData {
  final String description;
  final double value;
  final String date;

  SimpleInvoiceData(
      {required this.description, required this.value, required this.date});

  factory SimpleInvoiceData.fromJson(Map<String, dynamic> json) {
    double rawVal = (json['value'] as num?)?.toDouble() ?? 0.0;
    double valueInReais = rawVal / 100.0;

    return SimpleInvoiceData(
      description: json['description'] ?? 'Mensalidade',
      value: valueInReais,
      date: json['dueDate'] ?? '',
    );
  }
}

class NegotiationData {
  final String studentName;
  final double totalDebt;
  final Map<String, dynamic> rules;
  final List<SimpleInvoiceData> invoices;

  NegotiationData({
    required this.studentName,
    required this.totalDebt,
    required this.rules,
    required this.invoices,
  });

  factory NegotiationData.fromJson(Map<String, dynamic> json) {
    var invoicesList = <SimpleInvoiceData>[];
    if (json['invoices'] != null && json['invoices'] is List) {
      invoicesList = (json['invoices'] as List)
          .map((i) => SimpleInvoiceData.fromJson(i))
          .toList();
    }

    double rawTotal = (json['totalDebt'] as num?)?.toDouble() ?? 0.0;
    double totalInReais = rawTotal / 100.0;

    return NegotiationData(
      studentName: json['studentName'] ?? 'Aluno',
      totalDebt: totalInReais,
      rules: json['rules'] ?? {},
      invoices: invoicesList,
    );
  }
}

class NegotiationPaymentScreen extends StatefulWidget {
  final String negotiationToken;

  const NegotiationPaymentScreen({Key? key, required this.negotiationToken})
      : super(key: key);

  @override
  _NegotiationPaymentScreenState createState() =>
      _NegotiationPaymentScreenState();
}

class _NegotiationPaymentScreenState extends State<NegotiationPaymentScreen> {
  int _step = 0;
  bool _isLoading = false;
  String? _errorMessage;

  NegotiationData? _data;
  Map<String, dynamic>? _pixData;
  int _selectedInstallments = 1;

  final _cpfController = TextEditingController();
  final _cpfFormatter = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  final _cardNumberController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardCpfController = TextEditingController();

  final _cardFormatter = MaskTextInputFormatter(
      mask: '#### #### #### ####', filter: {"#": RegExp(r'[0-9]')});
  final _expiryFormatter =
      MaskTextInputFormatter(mask: '##/##', filter: {"#": RegExp(r'[0-9]')});

  final String _mpPublicKey = "TEST-00000000-0000-0000-0000-000000000000";

  String get _baseUrl {
    if (kDebugMode) {
      return "http://localhost:3000";
    }
    return "https://school-management-api-76ef.onrender.com";
  }

  // --- LÓGICA DE API ---
  Future<void> _validateAccess() async {
    final cpf = _cpfController.text.replaceAll(RegExp(r'\D'), '');
    if (cpf.length < 11) {
      setState(() => _errorMessage = "CPF inválido.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(
          '$_baseUrl/api/negotiations/public/validate/${widget.negotiationToken}');

      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'cpf': cpf}));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          _data = NegotiationData.fromJson(jsonResponse['data']);
          _step = 1;
          _isLoading = false;
          _cardCpfController.text = _cpfController.text;
        });
      } else {
        throw Exception(
            json.decode(response.body)['message'] ?? 'Erro ao validar.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _generatePix() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final url = Uri.parse(
          '$_baseUrl/api/negotiations/public/pay/${widget.negotiationToken}');

      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'method': 'pix'}));

      if (response.statusCode == 200) {
        setState(() {
          _pixData = json.decode(response.body)['paymentData'];
          _step = 2;
          _isLoading = false;
        });
      } else {
        throw Exception(json.decode(response.body)['message']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<String> _tokenizeCard(String cpfOwner) async {
    final url = Uri.parse(
        'https://api.mercadopago.com/v1/card_tokens?public_key=$_mpPublicKey');
    final splitDate = _cardExpiryController.text.split('/');
    if (splitDate.length < 2) throw Exception("Data inválida");

    final body = json.encode({
      "cardNumber": _cardNumberController.text.replaceAll(' ', ''),
      "cardholder": {
        "name": _cardNameController.text,
        "identification": {
          "type": "CPF",
          "number": cpfOwner.replaceAll(RegExp(r'\D'), '')
        }
      },
      "expirationMonth": int.tryParse(splitDate[0]) ?? 0,
      "expirationYear": int.tryParse("20${splitDate[1]}") ?? 0,
      "securityCode": _cardCvvController.text
    });

    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'}, body: body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body)['id'];
    } else {
      throw Exception("Dados do cartão inválidos.");
    }
  }

  Future<void> _payWithCard() async {
    if (_cardNumberController.text.length < 16) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cardToken = await _tokenizeCard(_cardCpfController.text);

      final url = Uri.parse(
          '$_baseUrl/api/negotiations/public/pay/${widget.negotiationToken}');

      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'method': 'credit_card',
            'cardData': {
              'token': cardToken,
              'issuerId': '1',
              'paymentMethodId': 'master',
              'installments': _selectedInstallments
            }
          }));

      if (response.statusCode == 200) {
        setState(() {
          _step = 4;
          _isLoading = false;
        });
      } else {
        throw Exception(json.decode(response.body)['message']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // --- CÁLCULOS ---
  double get _discountedPixValue {
    if (_data == null) return 0.0;
    double total = _data!.totalDebt;

    if (_data!.rules['allowPixDiscount'] == true) {
      final val = (_data!.rules['pixDiscountValue'] as num?)?.toDouble() ?? 0.0;
      final type = _data!.rules['pixDiscountType'] ?? 'percentage';

      if (type == 'percentage') {
        return total - (total * (val / 100));
      } else {
        return total - val;
      }
    }
    return total;
  }

  double get _savingsAmount => _data!.totalDebt - _discountedPixValue;

  // --- UI REFORMULADA ---

  @override
  Widget build(BuildContext context) {
    // Garante responsividade inicializando o ScreenUtil
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Design base mobile (iPhone X)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // Detecta se é uma tela grande (PC/Tablet)
        final bool isPc = MediaQuery.of(context).size.width > 800;

        return Scaffold(
          // Se for PC, usa um fundo um pouco mais escuro para destacar o "papel" central
          backgroundColor:
              isPc ? const Color(0xFFE0E5EC) : AcademyColors.background,
          body: Column(
            children: [
              // HEADER (AGORA BRANCO PARA A CORUJA APARECER)
              Container(
                width: double.infinity,
                color:
                    Colors.white, // Fundo branco para contraste da logo preta
                padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
                decoration: BoxDecoration(boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // LOGO
                      SvgPicture.asset(
                        'lib/assets/logo_academyhub_mobileCoruja.svg',
                        height: isPc ? 60.h : 50.h, // Ajuste leve para PC
                      ),
                      SizedBox(height: 15.h),
                      if (_step > 0)
                        Text(
                          "Central Financeira",
                          style: GoogleFonts.sairaCondensed(
                              color:
                                  AcademyColors.blackBody, // Texto escuro agora
                              fontSize: 24.sp, // .sp para responsividade
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0),
                        ),
                    ],
                  ),
                ),
              ),

              // BARRA DE VOLTAR
              if (_step > 0 && _step < 4)
                Container(
                  width: double.infinity,
                  color: AcademyColors
                      .background, // Contraste leve com o header branco
                  child: Align(
                    alignment: isPc ? Alignment.center : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 600.w),
                      child: TextButton.icon(
                        onPressed: () => setState(() => _step = _step - 1),
                        icon: Icon(PhosphorIcons.arrow_left,
                            size: 20.sp, color: Colors.grey),
                        label: Text("Voltar",
                            style: GoogleFonts.inter(
                                color: Colors.grey, fontSize: 14.sp)),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20.w, vertical: 15.h)),
                      ),
                    ),
                  ),
                ),

              // CONTEÚDO PRINCIPAL
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20.w),
                    child: ConstrainedBox(
                      // Se for PC, aumenta um pouco o limite, mas mantém focado
                      constraints: BoxConstraints(maxWidth: isPc ? 500 : 1.sw),
                      child: _isLoading
                          ? _buildLoading()
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: isPc
                                  ? Card(
                                      // Envolve em Card no PC para visual "Popup"
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20.r)),
                                      child: Padding(
                                        padding: EdgeInsets.all(30.w),
                                        child: _buildCurrentStep(),
                                      ),
                                    )
                                  : _buildCurrentStep() // Mobile segue fluxo normal
                              ),
                    ),
                  ),
                ),
              ),

              // FOOTER
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIcons.lock_key_fill,
                        size: 16.sp, color: Colors.grey),
                    SizedBox(width: 5.w),
                    Text("Ambiente Seguro",
                        style: GoogleFonts.inter(
                            color: Colors.grey, fontSize: 12.sp)),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AcademyColors.greenArrow),
        SizedBox(height: 20.h),
        Text("Processando informações...",
            style: GoogleFonts.inter(
                color: AcademyColors.blackBody,
                fontWeight: FontWeight.w500,
                fontSize: 14.sp)),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildValidationStep();
      case 1:
        return _buildDetailsStep();
      case 2:
        return _buildPixStep();
      case 3:
        return _buildCardStep();
      case 4:
        return _buildSuccessStep();
      default:
        return Container();
    }
  }

  Widget _buildValidationStep() {
    // Se estiver no PC (dentro do Card), removemos a sombra interna para não duplicar
    // Se estiver no Mobile, mantemos o container branco com sombra
    bool isPc = MediaQuery.of(context).size.width > 800;

    return Container(
      padding: isPc ? EdgeInsets.zero : EdgeInsets.all(30.w),
      decoration: isPc
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 5))
                ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Acesso Restrito",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: AcademyColors.blackBody)),
          SizedBox(height: 10.h),
          Text(
              "Por favor, confirme o CPF do responsável para visualizar os débitos.",
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(color: Colors.grey[600], fontSize: 14.sp)),
          SizedBox(height: 30.h),
          TextField(
            controller: _cpfController,
            inputFormatters: [_cpfFormatter],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0),
            decoration: InputDecoration(
              hintText: '000.000.000-00',
              filled: true,
              fillColor: AcademyColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.r),
                  borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(vertical: 16.h),
            ),
          ),
          if (_errorMessage != null)
            Padding(
                padding: EdgeInsets.only(top: 15.h),
                child: Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.inter(color: Colors.red, fontSize: 13.sp))),
          SizedBox(height: 30.h),
          ElevatedButton(
              onPressed: _validateAccess,
              style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.all(18.w),
                  backgroundColor: AcademyColors.greenArrow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.r)),
                  elevation: 2),
              child: Text("ACESSAR PAINEL",
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp)))
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final maxInstallments = _data!.rules['maxInstallments'] ?? 1;
    final hasDiscount =
        _data!.rules['allowPixDiscount'] == true && _savingsAmount > 0;

    bool isPc = MediaQuery.of(context).size.width > 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CARD DE VALOR TOTAL
        Container(
          padding: EdgeInsets.all(25.w),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              // Sombra apenas se for mobile, pois no PC já está dentro de um card
              boxShadow: isPc
                  ? []
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 15)
                    ],
              border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            children: [
              Text("Valor Total Pendente",
                  style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              SizedBox(height: 5.h),
              if (hasDiscount)
                Text(currency.format(_data!.totalDebt),
                    style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.red[300],
                        fontWeight: FontWeight.w500)),
              Text(
                currency.format(
                    hasDiscount ? _discountedPixValue : _data!.totalDebt),
                style: GoogleFonts.sairaCondensed(
                    fontSize: 42.sp,
                    fontWeight: FontWeight.w800,
                    color: AcademyColors.blueEye),
              ),
              if (hasDiscount)
                Container(
                  margin: EdgeInsets.only(top: 10.h),
                  padding:
                      EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
                  decoration: BoxDecoration(
                      color: AcademyColors.greenArrow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30.r)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.trend_down_fill,
                          size: 16.sp, color: AcademyColors.greenArrow),
                      SizedBox(width: 5.w),
                      Text(
                        "Economia de ${currency.format(_savingsAmount)} no PIX",
                        style: GoogleFonts.inter(
                            color: AcademyColors.greenArrow,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: 20.h),

        // DADOS DO ALUNO
        Row(
          children: [
            Icon(PhosphorIcons.student,
                color: AcademyColors.blackBody, size: 24.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Estudante",
                      style: GoogleFonts.inter(
                          fontSize: 12.sp, color: Colors.grey)),
                  Text(_data!.studentName,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 16.sp)),
                ],
              ),
            )
          ],
        ),

        SizedBox(height: 20.h),

        // ACORDEÃO DE DETALHES
        ClipRRect(
          borderRadius: BorderRadius.circular(15.r),
          child: ExpansionTile(
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            shape: const Border(),
            leading: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                  color: AcademyColors.blueEye.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r)),
              child: Icon(PhosphorIcons.receipt,
                  color: AcademyColors.blueEye, size: 20.sp),
            ),
            title: Text("Ver detalhes das faturas",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 14.sp)),
            children: [
              Container(
                padding: EdgeInsets.all(20.w),
                color: Colors.grey[50],
                child: Column(
                  children: _data!.invoices.isNotEmpty
                      ? _data!.invoices
                          .map((inv) => Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                          "${inv.description} (${_formatDate(inv.date)})",
                                          style: GoogleFonts.inter(
                                              color: Colors.grey[700],
                                              fontSize: 13.sp)),
                                    ),
                                    Text(currency.format(inv.value),
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: AcademyColors.blackBody,
                                            fontSize: 13.sp)),
                                  ],
                                ),
                              ))
                          .toList()
                      : [
                          Text("Detalhes indisponíveis",
                              style: GoogleFonts.inter(fontSize: 13.sp))
                        ],
                ),
              )
            ],
          ),
        ),

        SizedBox(height: 30.h),

        Text("Como deseja pagar?",
            style: GoogleFonts.sairaCondensed(
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
                color: AcademyColors.blackBody)),
        SizedBox(height: 15.h),

        _paymentMethodCard(
            icon: PhosphorIcons.qr_code_fill,
            color: AcademyColors.greenArrow,
            title: "PIX (Instantâneo)",
            subtitle:
                "Pague ${currency.format(_discountedPixValue)} com desconto.",
            badge: hasDiscount ? "Recomendado" : null,
            onTap: _generatePix),

        SizedBox(height: 15.h),

        if (_data!.rules['allowInstallments'] == true)
          _paymentMethodCard(
              icon: PhosphorIcons.credit_card_fill,
              color: AcademyColors.blueEye,
              title: "Cartão de Crédito",
              subtitle:
                  "Em até ${maxInstallments}x de ${currency.format(_data!.totalDebt / maxInstallments)}",
              onTap: () => setState(() => _step = 3)),
      ],
    );
  }

  Widget _buildPixStep() {
    return Column(
      children: [
        Text("Escaneie o QR Code",
            style: GoogleFonts.sairaCondensed(
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
                color: AcademyColors.blackBody)),
        SizedBox(height: 10.h),
        Text("Abra o aplicativo do seu banco e escolha a opção pagar com PIX.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14.sp)),
        SizedBox(height: 30.h),
        if (_pixData != null)
          Container(
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
            child: Image.memory(base64Decode(_pixData!['qrCodeBase64']),
                width: 220.w, height: 220.w),
          ),
        SizedBox(height: 30.h),
        if (_pixData != null)
          ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _pixData!['copyPaste']));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text("Código PIX copiado!"),
                  backgroundColor: AcademyColors.greenArrow,
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: Icon(PhosphorIcons.copy, size: 20.sp),
              label:
                  Text("Copiar Código PIX", style: TextStyle(fontSize: 16.sp)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AcademyColors.greenArrow,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 30.w, vertical: 15.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.r)))),
        SizedBox(height: 20.h),
        TextButton(
          onPressed: () => setState(() => _step = 4),
          child: Text("Já realizei o pagamento",
              style: GoogleFonts.inter(
                  color: AcademyColors.blueEye,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp)),
        )
      ],
    );
  }

  Widget _buildCardStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Pagamento com Cartão",
            style: GoogleFonts.sairaCondensed(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: AcademyColors.blackBody)),
        SizedBox(height: 20.h),
        Container(
          padding: EdgeInsets.all(25.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _input("Número do Cartão", _cardNumberController, _cardFormatter,
                  type: TextInputType.number, icon: PhosphorIcons.credit_card),
              SizedBox(height: 15.h),
              _input("Nome impresso no cartão", _cardNameController, null,
                  icon: PhosphorIcons.user),
              SizedBox(height: 15.h),
              Row(children: [
                Expanded(
                    child: _input("Validade (MM/AA)", _cardExpiryController,
                        _expiryFormatter,
                        type: TextInputType.number)),
                SizedBox(width: 15.w),
                Expanded(
                    child: _input("CVV", _cardCvvController,
                        MaskTextInputFormatter(mask: '####'),
                        type: TextInputType.number)),
              ]),
              SizedBox(height: 15.h),
              _input("CPF do Titular", _cardCpfController, _cpfFormatter,
                  type: TextInputType.number,
                  icon: PhosphorIcons.identification_card),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        DropdownButtonFormField<int>(
          value: _selectedInstallments,
          decoration: InputDecoration(
              labelText: "Parcelamento",
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(PhosphorIcons.list_numbers, size: 20.sp),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none)),
          items: List.generate(
              _data!.rules['maxInstallments'] ?? 1,
              (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text("${i + 1}x Sem Juros",
                      style: GoogleFonts.inter(fontSize: 14.sp)))),
          onChanged: (v) => setState(() => _selectedInstallments = v!),
        ),
        SizedBox(height: 30.h),
        ElevatedButton(
          onPressed: _payWithCard,
          style: ElevatedButton.styleFrom(
              padding: EdgeInsets.all(20.w),
              backgroundColor: AcademyColors.blueEye,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.r)),
              elevation: 3),
          child: Text("CONFIRMAR PAGAMENTO",
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp)),
        )
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: EdgeInsets.all(30.w),
        decoration: BoxDecoration(
            color: AcademyColors.greenArrow.withOpacity(0.1),
            shape: BoxShape.circle),
        child: Icon(PhosphorIcons.check_circle_fill,
            size: 80.sp, color: AcademyColors.greenArrow),
      ),
      SizedBox(height: 30.h),
      Text("Pagamento Confirmado!",
          style: GoogleFonts.sairaCondensed(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: AcademyColors.blackBody)),
      SizedBox(height: 15.h),
      Text(
          "Obrigado por manter as mensalidades em dia.\nVocê receberá o comprovante por e-mail.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              color: Colors.grey[600], height: 1.5, fontSize: 14.sp))
    ]);
  }

  Widget _paymentMethodCard(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      String? badge,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(
                color: badge != null
                    ? color.withOpacity(0.5)
                    : Colors.transparent),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 15.w),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          color: AcademyColors.blackBody)),
                  if (badge != null) ...[
                    SizedBox(width: 8.w),
                    Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4.r)),
                        child: Text(badge,
                            style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)))
                  ]
                ]),
                SizedBox(height: 4.h),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        color: Colors.grey[600], fontSize: 13.sp))
              ])),
          Icon(PhosphorIcons.caret_right, color: Colors.grey, size: 20.sp)
        ]),
      ),
    );
  }

  Widget _input(
      String label, TextEditingController ctrl, TextInputFormatter? fmt,
      {TextInputType type = TextInputType.text, IconData? icon}) {
    return TextFormField(
        controller: ctrl,
        inputFormatters: fmt != null ? [fmt] : [],
        keyboardType: type,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16.sp),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(fontSize: 14.sp),
            prefixIcon: icon != null
                ? Icon(icon, size: 20.sp, color: Colors.grey)
                : null,
            filled: true,
            fillColor: AcademyColors.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none)));
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yy').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}
