import 'dart:typed_data';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/academic_record_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/model/school_model.dart';
import 'package:academyhub_mobile/model/tutor_model.dart';
import 'package:academyhub_mobile/widgets/transcript_pdf_generator.dart';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

class PdfGeneratorService {
  // --- HELPERS DE GÊNERO ---
  bool _isFemale(Student student) {
    return student.gender != null &&
        student.gender.toLowerCase().startsWith('f');
  }

  String _g(Student s, String maleText, String femaleText) {
    return _isFemale(s) ? femaleText : maleText;
  }

  // --- Lógica inteligente para carregar o Logo ---
  Future<pw.ImageProvider> _resolveLogo(SchoolModel school) async {
    // 1. Bytes da memória (prioridade alta)
    if (school.logoBytes != null && school.logoBytes!.isNotEmpty) {
      return pw.MemoryImage(school.logoBytes!);
    }
    // 2. Download URL
    if (school.logoUrl != null && school.logoUrl!.isNotEmpty) {
      // Tenta usar a URL direta se disponível, ou monta a URL da API
      String downloadUrl = school.logoUrl!.startsWith('http')
          ? school.logoUrl!
          : '${ApiConfig.apiUrl}/schools/${school.id}/logo';

      try {
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print("Erro logo PDF: $e");
      }
    }
    // 3. Fallback Asset (último recurso)
    try {
      final byteData = await rootBundle.load('assets/logo_sossego.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      return pw.MemoryImage(Uint8List(0));
    }
  }

  // --- WIDGET DO SELO/MARCA D'ÁGUA (ESTILO CARIMBO OFICIAL) ---
  pw.Widget _buildProtocolStamp(SchoolModel school, pw.Font font) {
    if (school.authorizationProtocol == null ||
        school.authorizationProtocol!.isEmpty) {
      return pw.Container();
    }

    // O texto será convertido para maiúsculas para manter o padrão jurídico
    final protocolText = school.authorizationProtocol!.toUpperCase();

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors
            .white, // Fundo branco para destacar sobre linhas se houver
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // Ícone simulando um selo de verificação/escudo
          pw.Container(
              width: 14,
              height: 14,
              decoration: const pw.BoxDecoration(
                  color: PdfColors.grey400, shape: pw.BoxShape.circle),
              child: pw.Center(
                  child: pw.Text("✓",
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 8)))),
          pw.SizedBox(width: 8),
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'ATO DE AUTORIZAÇÃO',
                  style: pw.TextStyle(
                    font: font, // Usa a fonte Bold passada
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
              ])
        ],
      ),
    );
  }

  // --- 1. Declaração de Matrícula ---
  Future<Uint8List> generateEnrollmentConfirmation(
    Student student,
    SchoolModel school,
  ) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 30),
                  pw.Center(
                      child: pw.Text('DECLARAÇÃO DE MATRÍCULA',
                          style: pw.TextStyle(font: boldFont, fontSize: 16))),
                  pw.SizedBox(height: 30),
                  _buildEnrollmentBodyText(student, boldFont, baseFont),
                  pw.SizedBox(height: 20),
                  _buildAdditionalInfo(student, baseFont),
                  pw.Spacer(),
                  _buildFooter(baseFont),
                ],
              ),
              // Marca d'água no canto inferior direito
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

  // --- 2. Declaração para Imposto de Renda ---
  Future<Uint8List> generateIncomeTaxPdf(
    Student student,
    Tutor responsibleTutor,
    double totalAmount,
    String periodDescription,
    SchoolModel school,
  ) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    String amountFormatted = formatCurrency.format(totalAmount);
    String amountInWords = _numberToWordsPtBr(totalAmount);
    final peloAlunoText = _g(student, "pelo aluno", "pela aluna");

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 30),
                  pw.Center(
                      child: pw.Text('DECLARAÇÃO PARA FINS DE IMPOSTO DE RENDA',
                          style: pw.TextStyle(font: boldFont, fontSize: 14),
                          textAlign: pw.TextAlign.center)),
                  pw.SizedBox(height: 30),
                  pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 12, height: 1.5),
                      children: [
                        const pw.TextSpan(
                            text:
                                'Declaramos para os devidos fins de imposto de renda que recebemos de '),
                        pw.TextSpan(
                            text: responsibleTutor.fullName,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(
                            text:
                                ', portador(a) do CPF: ${_displayText(responsibleTutor.cpf, defaultValue: 'Não informado')}, responsável $peloAlunoText '),
                        pw.TextSpan(
                            text: student.fullName,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(
                            text:
                                ', o valor de ${amountInWords.toLowerCase()} ($amountFormatted) referente a $periodDescription de serviços educacionais prestados.'),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  _buildFooter(baseFont),
                ],
              ),
              // Marca d'água
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

  // --- 3. Declaração Cursando ---
  Future<Uint8List> generateEnrollmentStatusPdf(
    Student student,
    String currentGrade,
    String nextYear,
    SchoolModel school,
  ) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final String schoolName = school.name;
    final String cnpj = school.cnpj ?? "CNPJ não informado";
    final String address = _formatSchoolAddressInline(school);

    String tutorNames = student.tutors.isNotEmpty
        ? student.tutors
            .map((t) => t.tutorInfo.fullName.toUpperCase())
            .join(' E ')
        : '_____________________';

    final String fullName = student.fullName.toUpperCase();
    final String nationality = student.nationality;
    final String genderText = _isFemale(student) ? "Feminino" : "Masculino";
    final String birthDate = _formatDate(student.birthDate);
    final String currentYear = DateTime.now().year.toString();

    final oAluno = _g(student, "o aluno", "a aluna");
    final nascido = _g(student, "nascido", "nascida");
    final filho = _g(student, "filho", "filha");
    final matriculado = _g(student, "matriculado", "matriculada");

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 40),
                  pw.Center(
                      child: pw.Text('DECLARAÇÃO',
                          style: pw.TextStyle(font: boldFont, fontSize: 16))),
                  pw.SizedBox(height: 40),
                  pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 12, height: 1.6),
                      children: [
                        const pw.TextSpan(text: 'A '),
                        pw.TextSpan(
                            text: schoolName,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(
                            text:
                                ', devidamente inscrita no CNPJ $cnpj, situada na $address, declara para fins de direito e a quem mais possa interessar que $oAluno '),
                        pw.TextSpan(
                            text: fullName,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(
                            text:
                                ', $nationality, do sexo $genderText, $nascido aos '),
                        pw.TextSpan(
                            text: birthDate,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(text: ', $filho de '),
                        pw.TextSpan(
                            text: tutorNames,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(
                            text:
                                ', está regularmente $matriculado nesta Unidade de Ensino, no ano letivo de '),
                        pw.TextSpan(
                            text: currentYear,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(text: ', cursando o '),
                        pw.TextSpan(
                            text: currentGrade,
                            style: pw.TextStyle(font: boldFont)),
                        const pw.TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text('Por ser verdade assino a presente declaração.',
                      style: pw.TextStyle(font: baseFont, fontSize: 12)),
                  pw.Spacer(),
                  _buildFooterWithSignatureLine(baseFont, schoolName),
                ],
              ),
              // Marca d'água
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

  // --- 4. Declaração Nada Consta ---
  Future<Uint8List> generateNothingPendingPdf(
    Student student,
    String currentGrade,
    SchoolModel school,
  ) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    String tutorNames = student.tutors.isNotEmpty
        ? student.tutors.map((t) => t.tutorInfo.fullName).join(' e ')
        : '(Nome dos Responsáveis não informado)';

    final oAluno = _g(student, "o aluno", "a aluna");
    final filho = _g(student, "filho", "filha");
    final matriculado = _g(student, "matriculado", "matriculada");

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 30),
                  pw.Center(
                      child: pw.Text('DECLARAÇÃO DE NADA CONSTA',
                          style: pw.TextStyle(font: boldFont, fontSize: 16))),
                  pw.SizedBox(height: 30),
                  pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 12, height: 1.5),
                      children: [
                        pw.TextSpan(
                            text:
                                'Declaramos para os devidos fins que $oAluno '),
                        pw.TextSpan(
                            text: student.fullName,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(text: ', $filho de '),
                        pw.TextSpan(
                            text: tutorNames,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(text: ', regularmente $matriculado no '),
                        pw.TextSpan(
                            text: currentGrade,
                            style: pw.TextStyle(font: boldFont)),
                        const pw.TextSpan(
                            text:
                                ' neste estabelecimento de ensino, não possui pendências financeiras ou documentais junto à secretaria até a presente data.'),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  _buildFooter(baseFont),
                ],
              ),
              // Marca d'água
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

  // --- 5. Declaração de Transferência ---
  Future<Uint8List> generateTransferDeclaration(
    Student student,
    String currentGrade,
    String academicYear,
    SchoolModel school,
  ) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    String tutorNames;
    if (student.tutors.isEmpty) {
      tutorNames = "_____________________";
    } else {
      tutorNames = student.tutors
          .map((t) => t.tutorInfo.fullName.toUpperCase())
          .join(' E ');
    }

    String birthDate = _formatDate(student.birthDate);
    final nascido = _g(student, "nascido", "nascida");
    final filho = _g(student, "filho", "filha");
    final matriculado = _g(student, "matriculado", "matriculada");

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 40),
                  pw.Center(
                      child: pw.Text('DECLARAÇÃO DE TRANSFERÊNCIA',
                          style: pw.TextStyle(font: boldFont, fontSize: 16))),
                  pw.SizedBox(height: 40),
                  pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 12, height: 1.6),
                      children: [
                        const pw.TextSpan(
                            text: 'Declaramos para os devidos fins que '),
                        pw.TextSpan(
                            text: student.fullName.toUpperCase(),
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(text: ', $nascido em $birthDate, '),
                        pw.TextSpan(text: '$filho de '),
                        pw.TextSpan(
                            text: tutorNames,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(text: ', '),
                        pw.TextSpan(
                            text: 'está $matriculado',
                            style: pw.TextStyle(font: boldFont)),
                        const pw.TextSpan(
                            text: ' neste Estabelecimento de Ensino, no '),
                        pw.TextSpan(
                            text: currentGrade,
                            style: pw.TextStyle(font: boldFont)),
                        pw.TextSpan(text: ', no ano letivo de $academicYear.'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text('Situação do aluno: Cursando',
                      style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.Spacer(),
                  _buildTransferFooterBox(baseFont, boldFont, school),
                ],
              ),
              // Marca d'água
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

  // --- 6. Histórico Escolar ---
  Future<Uint8List> generateSchoolTranscript(
    Student student,
    List<AcademicRecord> history,
    SchoolModel school,
  ) async {
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    final italicFont = pw.Font.helveticaOblique();
    final formattedAddress = _formatSchoolAddress(school);

    final generator = TranscriptPdfGenerator(
      student: student,
      history: history,
      baseFont: baseFont,
      boldFont: boldFont,
      italicFont: italicFont,
      schoolName: school.name,
      schoolAddress: formattedAddress,
      schoolCnpj: school.cnpj ?? 'CNPJ não informado',
      // Passamos o protocolo, caso o TranscriptPdfGenerator suporte.
      // Se não suportar, você deve adicionar esse campo lá também.
      schoolAuthorizationProtocol: school.authorizationProtocol,
    );
    return await generator.generate();
  }

  // --- 7. RECIBO DE PAGAMENTO ---
  Future<Uint8List> generatePaymentReceipt({
    required Student student,
    required Tutor payerTutor,
    required double amount,
    required String referenceText,
    required String receiptNumber,
    required String gradeName,
    required String academicYear,
    required SchoolModel school,
  }) async {
    final logo = await _resolveLogo(school);
    final pdf = pw.Document();
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    String amountFormatted = formatCurrency.format(amount);
    String amountInWords = _numberToWordsPtBr(amount);
    final doAluno = _g(student, "DO ALUNO", "DA ALUNA");

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(boldFont, baseFont, logo, school),
                  pw.SizedBox(height: 40),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'RECIBO Nº $receiptNumber',
                      style: pw.TextStyle(font: boldFont, fontSize: 16),
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.RichText(
                      textAlign: pw.TextAlign.justify,
                      text: pw.TextSpan(
                        style: pw.TextStyle(
                            font: baseFont, fontSize: 12, height: 1.8),
                        children: [
                          const pw.TextSpan(
                              text: 'DECLARAMOS QUE RECEBEMOS DO SR (A): '),
                          pw.TextSpan(
                            text: payerTutor.fullName.toUpperCase(),
                            style: pw.TextStyle(font: boldFont),
                          ),
                          const pw.TextSpan(text: ' A IMPORTÂNCIA DE '),
                          pw.TextSpan(
                            text:
                                '$amountFormatted (${amountInWords.toUpperCase()})',
                            style: pw.TextStyle(font: boldFont),
                          ),
                          const pw.TextSpan(
                              text: ' COMO PAGAMENTO REFERENTE A: '),
                          pw.TextSpan(
                            text: referenceText.toUpperCase(),
                            style: pw.TextStyle(font: boldFont),
                          ),
                          pw.TextSpan(text: ' $doAluno '),
                          pw.TextSpan(
                            text: student.fullName.toUpperCase(),
                            style: pw.TextStyle(font: boldFont),
                          ),
                          const pw.TextSpan(
                              text:
                                  ' QUE ESTÁ DEVIDAMENTE MATRICULADO NESTA INSTITUIÇÃO DE ENSINO NA TURMA DO '),
                          pw.TextSpan(
                            text: gradeName.toUpperCase(),
                            style: pw.TextStyle(font: boldFont),
                          ),
                          const pw.TextSpan(text: ' NO ANO LETIVO DE '),
                          pw.TextSpan(
                            text: academicYear,
                            style: pw.TextStyle(font: boldFont),
                          ),
                          const pw.TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                  pw.Spacer(),
                  _buildFooter(baseFont),
                ],
              ),
              // Marca d'água
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

  // --- Widgets Auxiliares e Utilitários ---

  pw.Widget _buildHeader(pw.Font boldFont, pw.Font baseFont,
      pw.ImageProvider logo, SchoolModel school) {
    final addressString = _formatSchoolAddress(school);
    final cnpjString = school.cnpj ?? 'Não informado';
    final phoneString = school.contactPhone ?? 'Não informado';

    // REMOVIDO: O Protocolo foi movido para o selo/marca d'água no rodapé
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
        ]);
  }

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

  pw.Widget _buildEnrollmentBodyText(
      Student student, pw.Font boldFont, pw.Font baseFont) {
    String birthDate = _formatDate(student.birthDate);
    String tutorNames = student.tutors.isNotEmpty
        ? student.tutors.map((t) => t.tutorInfo.fullName).join(' e ')
        : '(Nome do Responsável não informado)';
    final oAluno = _g(student, "o aluno", "a aluna");
    final nascido = _g(student, "nascido", "nascida");
    final filho = _g(student, "filho", "filha");
    final matriculado = _g(student, "matriculado", "matriculada");

    return pw.RichText(
      textAlign: pw.TextAlign.justify,
      text: pw.TextSpan(
        style: pw.TextStyle(font: baseFont, fontSize: 12, height: 1.5),
        children: [
          pw.TextSpan(text: 'Declaramos, para os devidos fins, que $oAluno '),
          pw.TextSpan(
              text: student.fullName, style: pw.TextStyle(font: boldFont)),
          pw.TextSpan(text: ', $nascido em $birthDate, $filho de '),
          pw.TextSpan(text: tutorNames, style: pw.TextStyle(font: boldFont)),
          pw.TextSpan(
              text:
                  ', encontra-se regularmente $matriculado nesta instituição de ensino no presente ano letivo.'),
        ],
      ),
    );
  }

  pw.Widget _buildAdditionalInfo(Student student, pw.Font baseFont) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Matrícula: ${student.id.substring(0, 8).toUpperCase()}',
              style: pw.TextStyle(font: baseFont, fontSize: 10)),
        ]);
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

  pw.Widget _buildFooterWithSignatureLine(pw.Font baseFont, String schoolName) {
    String today =
        DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR').format(DateTime.now());
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${_getLocationString()}, $today.',
              style: pw.TextStyle(font: baseFont, fontSize: 12)),
        ),
        pw.SizedBox(height: 60),
        pw.Container(width: 350, child: pw.Divider(thickness: 1)),
        pw.Text(schoolName, style: pw.TextStyle(font: baseFont, fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildTransferFooterBox(
      pw.Font baseFont, pw.Font boldFont, SchoolModel school) {
    String today =
        DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR').format(DateTime.now());

    String cityState = "Parauapebas/PA";
    if (school.address != null) {
      cityState = "${school.address!.city}/${school.address!.state}";
    }

    return pw.Column(
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('$cityState, $today.',
              style: pw.TextStyle(font: baseFont, fontSize: 12)),
        ),
        pw.SizedBox(height: 60),
        pw.Container(width: 350, child: pw.Divider(thickness: 1)),
        pw.Text(school.name, style: pw.TextStyle(font: baseFont, fontSize: 12)),
        pw.SizedBox(height: 40),
        pw.Align(
            alignment: pw.Alignment.bottomRight,
            child: pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(school.name,
                        style: pw.TextStyle(font: boldFont, fontSize: 10),
                        textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 4),
                    pw.Text(school.cnpj ?? 'CNPJ N/A',
                        style: pw.TextStyle(font: boldFont, fontSize: 12)),
                    pw.SizedBox(height: 4),
                    // Nota: O protocolo é exibido na Stack global, mas aqui fica o box de assinatura
                    pw.Text("Direção Escolar / Secretaria",
                        style: pw.TextStyle(font: boldFont, fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text(_formatSchoolAddressShort(school),
                        style: pw.TextStyle(font: baseFont, fontSize: 8),
                        textAlign: pw.TextAlign.center),
                  ],
                )))
      ],
    );
  }

  String _formatSchoolAddressShort(SchoolModel school) {
    if (school.address == null) return '';
    return '${school.address!.street}, ${school.address!.number}, ${school.address!.district}\n${school.address!.city} / ${school.address!.state}';
  }

  String _getLocationString() {
    return "Parauapebas/PA";
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _displayText(String? text, {String defaultValue = 'N/A'}) {
    return (text == null || text.isEmpty) ? defaultValue : text;
  }

  String _numberToWordsPtBr(double number) {
    final parteInteira = number.toInt();
    final parteDecimal = ((number - parteInteira) * 100).round();
    String extensoInteiro = _integerToWordsPtBr(parteInteira);
    String extensoDecimal = _integerToWordsPtBr(parteDecimal);
    String resultado = extensoInteiro;
    if (parteInteira == 1) {
      resultado += ' real';
    } else if (parteInteira > 1 || (parteInteira == 0 && parteDecimal == 0)) {
      resultado += ' reais';
    }
    if (parteDecimal > 0) {
      if (parteInteira > 0) resultado += ' e ';
      resultado += extensoDecimal;
      resultado += (parteDecimal == 1) ? ' centavo' : ' centavos';
    }
    return resultado.isNotEmpty
        ? resultado[0].toUpperCase() + resultado.substring(1)
        : "Zero reais";
  }

  String _integerToWordsPtBr(int n) {
    if (n < 0) return 'menos ${_integerToWordsPtBr(-n)}';
    if (n == 0) return 'zero';
    final unidades = [
      '',
      'um',
      'dois',
      'três',
      'quatro',
      'cinco',
      'seis',
      'sete',
      'oito',
      'nove'
    ];
    final dezVinte = [
      'dez',
      'onze',
      'doze',
      'treze',
      'catorze',
      'quinze',
      'dezesseis',
      'dezessete',
      'dezoito',
      'dezenove'
    ];
    final dezenas = [
      '',
      '',
      'vinte',
      'trinta',
      'quarenta',
      'cinquenta',
      'sessenta',
      'setenta',
      'oitenta',
      'noventa'
    ];
    final centenas = [
      '',
      'cento',
      'duzentos',
      'trezentos',
      'quatrocentos',
      'quinhentos',
      'seiscentos',
      'setecentos',
      'oitocentos',
      'novecentos'
    ];
    List<String> parts = [];
    bool needsAnd = false;
    if (n >= 1000000) {
      int milhao = n ~/ 1000000;
      parts.add(
          milhao == 1 ? 'um milhão' : '${_integerToWordsPtBr(milhao)} milhões');
      n %= 1000000;
      needsAnd = (n > 0);
    }
    if (n >= 1000) {
      int mil = n ~/ 1000;
      if (parts.isNotEmpty && mil > 0) parts.add('e');
      if (mil != 1)
        parts.add('${_integerToWordsPtBr(mil)} mil');
      else
        parts.add('mil');
      n %= 1000;
      needsAnd = (n > 0 && n < 100 && (n % 10 == 0 || n < 20));
    }
    if (n >= 100) {
      int cem = n ~/ 100;
      if (parts.isNotEmpty && n % 100 != 0) parts.add('e');
      parts.add(n == 100 ? 'cem' : centenas[cem]);
      n %= 100;
      needsAnd = (n > 0);
    }
    if (n > 0) {
      if (parts.isNotEmpty &&
          (needsAnd || n < 10 || n % 10 != 0 || parts.last == 'cem'))
        parts.add('e');
      if (n >= 20) {
        int dez = n ~/ 10;
        parts.add(dezenas[dez]);
        n %= 10;
        if (n > 0) {
          parts.add('e');
          parts.add(unidades[n]);
        }
      } else if (n >= 10) {
        parts.add(dezVinte[n - 10]);
      } else {
        parts.add(unidades[n]);
      }
    }
    return parts.where((p) => p.isNotEmpty).join(' ').replaceAll('  ', ' ');
  }
}
