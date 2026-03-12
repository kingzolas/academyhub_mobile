import 'dart:typed_data';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/school_model.dart';
import 'package:academyhub_mobile/model/user_model.dart';
import 'package:academyhub_mobile/model/staff_profile_model.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

/// Service exclusivo para PDFs de Funcionários/Professores.
/// Mantém o PdfGeneratorService (alunos) separado.
class StaffPdfGeneratorService {
  // ===============================
  // ✅ FONTS (UTF-8) — ROBOTO
  // ===============================
  static const String _robotoRegularPath = 'assets/Roboto-Regular.ttf';
  static const String _robotoBoldPath = 'assets/Roboto-Bold.ttf';

  pw.Font? _cachedBaseFont;
  pw.Font? _cachedBoldFont;

  Future<pw.Font> _baseFont() async {
    _cachedBaseFont ??= pw.Font.ttf(await rootBundle.load(_robotoRegularPath));
    return _cachedBaseFont!;
  }

  Future<pw.Font> _boldFont() async {
    _cachedBoldFont ??= pw.Font.ttf(await rootBundle.load(_robotoBoldPath));
    return _cachedBoldFont!;
  }

  // --- Helpers de gênero (baseado no User.gender do seu app) ---
  bool _isFemale(User user) {
    final g = (user.gender ?? '').toLowerCase();
    return g.startsWith('f');
  }

  String _g(User u, String maleText, String femaleText) {
    return _isFemale(u) ? femaleText : maleText;
  }

  // Estado civil flexionado no texto, mas armazenado como enum neutro no banco
  String _maritalStatusLabel(User user, String? status) {
    final s = (status ?? '').trim().toUpperCase();
    if (s.isEmpty) return '';
    final female = _isFemale(user);

    switch (s) {
      case 'SOLTEIRO':
        return female ? 'solteira' : 'solteiro';
      case 'CASADO':
        return female ? 'casada' : 'casado';
      case 'DIVORCIADO':
        return female ? 'divorciada' : 'divorciado';
      case 'VIUVO':
        return female ? 'viúva' : 'viúvo';
      case 'UNIAO_ESTAVEL':
        return 'em união estável';
      default:
        return s.replaceAll('_', ' ').toLowerCase();
    }
  }

  // --- Lógica inteligente para carregar o Logo ---
  Future<pw.ImageProvider> _resolveLogo(SchoolModel school) async {
    if (school.logoBytes != null && school.logoBytes!.isNotEmpty) {
      return pw.MemoryImage(school.logoBytes!);
    }

    if (school.logoUrl != null && school.logoUrl!.isNotEmpty) {
      String downloadUrl = school.logoUrl!.startsWith('http')
          ? school.logoUrl!
          : '${ApiConfig.apiUrl}/schools/${school.id}/logo';

      try {
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {
        // ignore
      }
    }

    try {
      final byteData = await rootBundle.load('assets/logo_sossego.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      return pw.MemoryImage(Uint8List(0));
    }
  }

  // --- Selo/Marca d'água ---
  pw.Widget _buildProtocolStamp(SchoolModel school, pw.Font font) {
    if (school.authorizationProtocol == null ||
        school.authorizationProtocol!.isEmpty) {
      return pw.Container();
    }

    final protocolText = school.authorizationProtocol!.toUpperCase();

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors.white,
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 14,
            height: 14,
            decoration: const pw.BoxDecoration(
                color: PdfColors.grey400, shape: pw.BoxShape.circle),
            child: pw.Center(
              child: pw.Text("✓",
                  style:
                      const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'ATO DE AUTORIZAÇÃO',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 7,
                  color: PdfColors.grey600,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                protocolText,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: PdfColors.black,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ============================================================
  // 1) DECLARAÇÃO FUNCIONAL / VÍNCULO
  // ============================================================
// ============================================================
// 1) DECLARAÇÃO FUNCIONAL / VÍNCULO (REVISADA)
//  - Remove salário/valor hora
//  - Ajusta pronomes/flexões por gênero
// ============================================================
  Future<Uint8List> generateStaffEmploymentDeclaration({
    required User staffUser,
    required StaffProfile staffProfile,
    required SchoolModel school,
    String? declarationTitle,
    bool includeSensitiveIds = false, // LGPD: por padrão, mascarar CPF/RG
  }) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();

    final baseFont = await _baseFont();
    final boldFont = await _boldFont();

    final String schoolName = school.name;
    final String cnpj = school.cnpj ?? "CNPJ não informado";
    final String address = _formatSchoolAddressInline(school);

    final String fullName = (staffUser.fullName ?? '').toUpperCase();

    final String cpfRaw = staffUser.cpf ?? '';
    final String cpf =
        includeSensitiveIds ? _formatCpf(cpfRaw) : _maskCpf(cpfRaw);

    final String rgRaw = (staffProfile.rg ?? '').trim();
    final String rg = includeSensitiveIds ? rgRaw : _maskRg(rgRaw);

    final String birthDate = _formatDate(staffUser.birthDate);

    // Gênero/Pronomes (usando o que já existe no seu app)
    final bool isFemale = _isFemale(staffUser);
    final String art = isFemale ? 'a' : 'o';
    final String artCap = isFemale ? 'A' : 'O';
    final String identificado = isFemale ? 'identificada' : 'identificado';
    final String portador = isFemale ? 'portadora' : 'portador';

    final String admissionDate = _formatDate(staffProfile.admissionDate);
    final String terminationDate = _formatDate(staffProfile.terminationDate);

    final String role = (staffProfile.mainRole).toUpperCase();
    final String employmentType = (staffProfile.employmentType).toUpperCase();
    final String status = (staffUser.status ?? 'Ativo').toUpperCase();

    final title = (declarationTitle?.trim().isNotEmpty == true)
        ? declarationTitle!.trim().toUpperCase()
        : 'DECLARAÇÃO FUNCIONAL';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (_) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 35),

                  pw.Center(
                    child: pw.Text(
                      title,
                      style: pw.TextStyle(font: boldFont, fontSize: 16),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                  pw.SizedBox(height: 30),

                  // Bloco de identificação (sem dados excessivos)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _kv(boldFont, baseFont, 'NOME', fullName),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'CPF',
                            cpf.isEmpty ? 'NÃO INFORMADO' : cpf),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'RG',
                            rg.isEmpty ? 'NÃO INFORMADO' : rg),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'DATA DE NASCIMENTO',
                            birthDate),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'CARGO/FUNÇÃO', role),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'VÍNCULO', employmentType),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'DATA DE ADMISSÃO',
                            admissionDate),
                        if (staffProfile.terminationDate != null) ...[
                          pw.SizedBox(height: 4),
                          _kv(boldFont, baseFont, 'DATA DE SAÍDA',
                              terminationDate),
                        ],
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'SITUAÇÃO', status),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 22),

                  // Texto jurídico principal (com pronomes corretos)
                  pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 12, height: 1.6),
                      children: [
                        pw.TextSpan(
                          text: '$artCap ',
                          style: pw.TextStyle(font: baseFont),
                        ),
                        pw.TextSpan(
                          text: schoolName,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(
                          text:
                              ', devidamente inscrita no CNPJ $cnpj, situada na $address, '
                              'declara para fins de direito e a quem possa interessar que $art ',
                        ),
                        pw.TextSpan(
                          text: fullName,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(text: ', $identificado, '),
                        pw.TextSpan(text: '$portador do CPF '),
                        pw.TextSpan(
                          text: cpf.isEmpty ? 'não informado' : cpf,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(text: ', exerce a função de '),
                        pw.TextSpan(
                          text: role,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(text: ' nesta instituição, sob o vínculo '),
                        pw.TextSpan(
                          text: employmentType,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(text: ', com data de admissão em '),
                        pw.TextSpan(
                          text: admissionDate,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        if (staffProfile.terminationDate != null) ...[
                          pw.TextSpan(text: ', e data de saída em '),
                          pw.TextSpan(
                            text: terminationDate,
                            style: pw.TextStyle(font: boldFont),
                          ),
                        ],
                        pw.TextSpan(text: '. Situação cadastral: '),
                        pw.TextSpan(
                          text: status,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        const pw.TextSpan(text: '.'),
                      ],
                    ),
                  ),

                  pw.Spacer(),
                  _buildFooter(baseFont),
                ],
              ),
              pw.Positioned(
                bottom: 0,
                right: 0,
                child: _buildProtocolStamp(school, boldFont),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // 2) DECLARAÇÃO DE HABILITAÇÃO DOCENTE
  // ============================================================
  Future<Uint8List> generateTeachingQualificationDeclaration({
    required User staffUser,
    required StaffProfile staffProfile,
    required SchoolModel school,
    bool includeSensitiveIds = false,
  }) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();

    final baseFont = await _baseFont();
    final boldFont = await _boldFont();

    final String schoolName = school.name;
    final String cnpj = school.cnpj ?? "CNPJ não informado";
    final String address = _formatSchoolAddressInline(school);

    final String fullName = (staffUser.fullName ?? '').toUpperCase();
    final String cpfRaw = staffUser.cpf ?? '';
    final String cpf =
        includeSensitiveIds ? _formatCpf(cpfRaw) : _maskCpf(cpfRaw);

    final String role = (staffProfile.mainRole).toUpperCase();
    final String admissionDate = _formatDate(staffProfile.admissionDate);

    final levels = staffProfile.enabledLevels;
    final subjects = staffProfile.enabledSubjects;

    final String levelsText = levels.isNotEmpty
        ? levels.map((e) => e.toUpperCase()).join(', ')
        : 'NÃO INFORMADO';

    final String subjectsText = subjects.isNotEmpty
        ? subjects.map((s) => s.name.toUpperCase()).join(', ')
        : 'NÃO INFORMADO';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (_) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 35),
                  pw.Center(
                    child: pw.Text(
                      'DECLARAÇÃO DE HABILITAÇÃO DOCENTE',
                      style: pw.TextStyle(font: boldFont, fontSize: 16),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 28),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _kv(boldFont, baseFont, 'NOME', fullName),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'CPF',
                            cpf.isEmpty ? 'NÃO INFORMADO' : cpf),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'CARGO/FUNÇÃO', role),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'DATA DE ADMISSÃO',
                            admissionDate),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 12, height: 1.6),
                      children: [
                        const pw.TextSpan(text: 'A '),
                        pw.TextSpan(
                          text: schoolName,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(
                          text:
                              ', inscrita no CNPJ $cnpj, situada na $address, declara para fins de comprovação que ',
                        ),
                        pw.TextSpan(
                          text: fullName,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        const pw.TextSpan(
                          text:
                              ', integrante do corpo docente/funcional desta instituição, encontra-se habilitado(a) a atuar nos níveis de ensino e componentes curriculares abaixo relacionados, conforme cadastro interno.',
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('NÍVEIS HABILITADOS',
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 10,
                                color: PdfColors.grey700)),
                        pw.SizedBox(height: 6),
                        pw.Text(levelsText,
                            style: pw.TextStyle(font: baseFont, fontSize: 11)),
                        pw.SizedBox(height: 12),
                        pw.Text('DISCIPLINAS HABILITADAS',
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 10,
                                color: PdfColors.grey700)),
                        pw.SizedBox(height: 6),
                        pw.Text(subjectsText,
                            style: pw.TextStyle(font: baseFont, fontSize: 11)),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  _buildFooter(baseFont),
                ],
              ),
              pw.Positioned(
                bottom: 0,
                right: 0,
                child: _buildProtocolStamp(school, boldFont),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // 3) DECLARAÇÃO DE CARGA HORÁRIA
  // ============================================================
  Future<Uint8List> generateWorkloadDeclaration({
    required User staffUser,
    required StaffProfile staffProfile,
    required SchoolModel school,
    bool includeSensitiveIds = false,
  }) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();

    final baseFont = await _baseFont();
    final boldFont = await _boldFont();

    final String schoolName = school.name;
    final String cnpj = school.cnpj ?? "CNPJ não informado";
    final String address = _formatSchoolAddressInline(school);

    final String fullName = (staffUser.fullName ?? '').toUpperCase();
    final String cpfRaw = staffUser.cpf ?? '';
    final String cpf =
        includeSensitiveIds ? _formatCpf(cpfRaw) : _maskCpf(cpfRaw);

    final String role = (staffProfile.mainRole).toUpperCase();
    final String employmentType = (staffProfile.employmentType).toUpperCase();
    final String admissionDate = _formatDate(staffProfile.admissionDate);

    final int? weekly = staffProfile.weeklyWorkload;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (_) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 35),
                  pw.Center(
                    child: pw.Text(
                      'DECLARAÇÃO DE CARGA HORÁRIA',
                      style: pw.TextStyle(font: boldFont, fontSize: 16),
                    ),
                  ),
                  pw.SizedBox(height: 28),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _kv(boldFont, baseFont, 'NOME', fullName),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'CPF',
                            cpf.isEmpty ? 'NÃO INFORMADO' : cpf),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'CARGO/FUNÇÃO', role),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'VÍNCULO', employmentType),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'DATA DE ADMISSÃO',
                            admissionDate),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 12, height: 1.6),
                      children: [
                        const pw.TextSpan(text: 'A '),
                        pw.TextSpan(
                          text: schoolName,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(
                          text:
                              ', inscrita no CNPJ $cnpj, situada na $address, declara para fins de comprovação que ',
                        ),
                        pw.TextSpan(
                          text: fullName,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(text: ', exerce a função de '),
                        pw.TextSpan(
                          text: role,
                          style: pw.TextStyle(font: boldFont),
                        ),
                        pw.TextSpan(
                            text:
                                ' nesta instituição, com carga horária semanal de '),
                        pw.TextSpan(
                          text: weekly != null ? '${weekly}h' : 'NÃO INFORMADA',
                          style: pw.TextStyle(font: boldFont),
                        ),
                        const pw.TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  _buildFooter(baseFont),
                ],
              ),
              pw.Positioned(
                bottom: 0,
                right: 0,
                child: _buildProtocolStamp(school, boldFont),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // 4) TERMO DE CONFIDENCIALIDADE + LGPD
  // ============================================================
  Future<Uint8List> generateConfidentialityAndLgpdTerm({
    required User staffUser,
    required StaffProfile staffProfile,
    required SchoolModel school,
    bool includeSensitiveIds = false,
  }) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();

    final baseFont = await _baseFont();
    final boldFont = await _boldFont();

    final String schoolName = school.name;
    final String cnpj = school.cnpj ?? "CNPJ não informado";
    final String address = _formatSchoolAddressInline(school);

    final String fullName = (staffUser.fullName ?? '').toUpperCase();
    final String cpfRaw = staffUser.cpf ?? '';
    final String cpf =
        includeSensitiveIds ? _formatCpf(cpfRaw) : _maskCpf(cpfRaw);

    final String role = (staffProfile.mainRole).toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (_) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 28),
                  pw.Center(
                    child: pw.Text(
                      'TERMO DE CONFIDENCIALIDADE E PROTEÇÃO DE DADOS',
                      style: pw.TextStyle(font: boldFont, fontSize: 14),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 22),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _kv(boldFont, baseFont, 'COLABORADOR(A)', fullName),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'CPF',
                            cpf.isEmpty ? 'NÃO INFORMADO' : cpf),
                        pw.SizedBox(height: 4),
                        _kv(boldFont, baseFont, 'CARGO/FUNÇÃO', role),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 11, height: 1.6),
                      children: [
                        const pw.TextSpan(
                          text:
                              'Pelo presente instrumento, o(a) COLABORADOR(A) acima identificado(a) declara ciência e concordância com as regras de confidencialidade e proteção de dados aplicáveis às atividades desempenhadas junto à ',
                        ),
                        pw.TextSpan(
                            text: schoolName.toUpperCase(),
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(
                            text:
                                ', inscrita no CNPJ $cnpj, situada na $address, comprometendo-se a:'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _bullet(baseFont,
                      'Manter sigilo sobre informações internas, acadêmicas e administrativas da instituição.'),
                  _bullet(baseFont,
                      'Acessar e utilizar dados pessoais de alunos, responsáveis e colaboradores somente quando necessário às suas atribuições.'),
                  _bullet(baseFont,
                      'Não compartilhar senhas, credenciais ou documentos contendo dados pessoais com terceiros não autorizados.'),
                  _bullet(baseFont,
                      'Comunicar imediatamente à Direção/Secretaria qualquer incidente, perda, acesso indevido ou vazamento de informações.'),
                  _bullet(baseFont,
                      'Seguir normas internas de segurança da informação e boas práticas de uso de sistemas.'),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Este termo permanece válido durante o vínculo e após seu encerramento, no que couber.',
                    style: pw.TextStyle(font: baseFont, fontSize: 11),
                  ),
                  pw.Spacer(),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Divider(thickness: 1)),
                      pw.SizedBox(width: 10),
                      pw.Expanded(child: pw.Divider(thickness: 1)),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text('Assinatura do(a) Colaborador(a)',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: baseFont, fontSize: 10)),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Text('Assinatura da Instituição',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: baseFont, fontSize: 10)),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  _buildFooter(baseFont),
                ],
              ),
              pw.Positioned(
                bottom: 0,
                right: 0,
                child: _buildProtocolStamp(school, boldFont),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- Helpers visuais ---
  pw.Widget _kv(pw.Font bold, pw.Font base, String k, String v) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 150,
          child: pw.Text('$k:',
              style: pw.TextStyle(
                font: bold,
                fontSize: 10,
                color: PdfColors.grey700,
              )),
        ),
        pw.Expanded(
          child: pw.Text(v, style: pw.TextStyle(font: base, fontSize: 10)),
        ),
      ],
    );
  }

  pw.Widget _bullet(pw.Font baseFont, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(font: baseFont, fontSize: 11)),
          pw.Expanded(
            child: pw.Text(text,
                style: pw.TextStyle(font: baseFont, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildHeader(
    pw.Font boldFont,
    pw.Font baseFont,
    pw.ImageProvider logo,
    SchoolModel school,
  ) {
    final addressString = _formatSchoolAddress(school);
    final cnpjString = school.cnpj ?? 'Não informado';
    final phoneString = school.contactPhone ?? 'Não informado';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(school.name.toUpperCase(),
                  style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 2),
              pw.Text(addressString,
                  style: pw.TextStyle(font: baseFont, fontSize: 9)),
              pw.SizedBox(height: 1),
              pw.Text('CNPJ: $cnpjString',
                  style: pw.TextStyle(font: baseFont, fontSize: 9)),
              pw.SizedBox(height: 1),
              pw.Text('Telefone: $phoneString',
                  style: pw.TextStyle(font: baseFont, fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          width: 60,
          height: 60,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Font baseFont) {
    String today =
        DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR').format(DateTime.now());
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${_getLocationString()}, $today.',
              style: pw.TextStyle(font: baseFont, fontSize: 10)),
        ),
        pw.SizedBox(height: 60),
        pw.Container(width: 250, child: pw.Divider(thickness: 1)),
        pw.Text('Assinatura da Secretaria',
            style: pw.TextStyle(font: baseFont, fontSize: 10)),
      ],
    );
  }

  // --- Utils ---
  String _formatSchoolAddress(SchoolModel school) {
    if (school.address == null) return 'Endereço não informado';
    final addr = school.address!;
    return '${addr.street}, ${addr.number} - ${addr.district}, ${addr.city}/${addr.state}';
  }

  String _formatSchoolAddressInline(SchoolModel school) {
    if (school.address == null) return 'Endereço não informado';
    final addr = school.address!;
    return 'Rua ${addr.street}, nº ${addr.number}, Bairro ${addr.district}, ${addr.city}/${addr.state}';
  }

  String _getLocationString() {
    return "Parauapebas/PA";
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatCpf(String? cpf) {
    if (cpf == null) return '';
    final digits = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 11) return cpf;
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9, 11)}';
  }

  String _maskCpf(String? cpf) {
    final digits = (cpf ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 11) return (cpf ?? '').isEmpty ? '' : '***';
    return '***.***.***-${digits.substring(9, 11)}';
  }

  String _maskRg(String? rg) {
    final d = (rg ?? '').replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    if (d.isEmpty) return '';
    if (d.length <= 3) return '***';
    return '***${d.substring(d.length - 2)}';
  }

  String _formatCurrency(double value) {
    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return formatCurrency.format(value);
  }
}
