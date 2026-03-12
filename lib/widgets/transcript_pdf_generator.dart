// lib/widgets/transcript_pdf_generator.dart

import 'dart:typed_data';

import 'package:academyhub_mobile/model/academic_record_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Uma classe dedicada exclusivamente a gerar o PDF do Histórico Escolar.
class TranscriptPdfGenerator {
  final Student student;
  final List<AcademicRecord> history;

  // Fontes do PDF
  final pw.Font baseFont;
  final pw.Font boldFont;
  final pw.Font italicFont;

  // Constantes da Escola
  final String schoolName;
  final String schoolAddress;
  final String schoolCnpj;

  // [CORREÇÃO] Novo campo adicionado para receber o protocolo
  final String? schoolAuthorizationProtocol;

  // Lista fixa de séries/anos conforme solicitado.
  final List<String> _fixedGradeLevels = const [
    '1º Ano',
    '2º Ano',
    '3º Ano',
    '4º Ano',
    '5º Ano',
  ];

  // Estilos reutilizáveis
  late final pw.TextStyle _textBold;
  late final pw.TextStyle _textRegular;
  late final pw.TextStyle _textLabel;

  TranscriptPdfGenerator({
    required this.student,
    required this.history,
    required this.baseFont,
    required this.boldFont,
    required this.italicFont,
    required this.schoolName,
    required this.schoolAddress,
    required this.schoolCnpj,
    // [CORREÇÃO] Adicionado ao construtor
    this.schoolAuthorizationProtocol,
  }) {
    // Define os estilos uma vez
    _textBold = pw.TextStyle(font: boldFont, fontSize: 9);
    _textRegular = pw.TextStyle(font: baseFont, fontSize: 9);
    _textLabel =
        pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.grey600);
  }

  /// Ponto de entrada principal. Gera o documento completo.
  Future<Uint8List> generate() async {
    final pdf = pw.Document();

    // Ordena o histórico por ano letivo (mais antigo primeiro)
    history.sort((a, b) => a.schoolYear.compareTo(b.schoolYear));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40.0), // 40pt = 1.41cm
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Título
              pw.Center(
                child: pw.Text('HISTÓRICO ESCOLAR',
                    style: pw.TextStyle(font: boldFont, fontSize: 16)),
              ),
              pw.SizedBox(height: 15),

              // 2. Cabeçalho de Informações da Escola
              _buildTranscriptHeader(),
              pw.SizedBox(height: 10),

              // 3. Informações do Aluno
              _buildStudentInfo(),
              pw.SizedBox(height: 20),

              // 4. Tabela de Notas
              _buildGradesTable(),
              pw.SizedBox(height: 20),

              // 5. Tabela de Histórico
              _buildSchoolHistoryTable(),

              // Espaçador para empurrar o rodapé para baixo
              pw.Spacer(),

              // 6. Rodapé
              _buildTranscriptFooter(),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  // --- Helpers de Layout ---

  /// Cria um bloco de informação (Label + Value)
  pw.Widget _buildInfoBlock(String label, String value,
      {pw.Font? valueFont, int flex = 1}) {
    return pw.Expanded(
        flex: flex,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(label.toUpperCase(), style: _textLabel),
            pw.Text(value,
                style: pw.TextStyle(
                    font: valueFont ?? _textRegular.font, fontSize: 9)),
          ],
        ));
  }

  /// Bloco de informações da Escola
  pw.Widget _buildTranscriptHeader() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoBlock('Estabelecimento', schoolName,
                  valueFont: boldFont, flex: 3),
              _buildInfoBlock('CNPJ', schoolCnpj, flex: 2),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoBlock('Endereço', schoolAddress, flex: 3),
              _buildInfoBlock('Cidade / UF', 'Parauapebas / PA', flex: 2),
            ],
          ),
          // [NOVO] Exibição do Ato Autorizativo no cabeçalho do histórico
          if (schoolAuthorizationProtocol != null &&
              schoolAuthorizationProtocol!.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoBlock(
                    'Ato de Autorização', schoolAuthorizationProtocol!,
                    valueFont: boldFont, flex: 5),
              ],
            ),
          ]
        ],
      ),
    );
  }

  /// Bloco de informações do Aluno
  pw.Widget _buildStudentInfo() {
    String filiacao = student.tutors.isNotEmpty
        ? student.tutors
            .map((tutorLink) => tutorLink.tutorInfo.fullName)
            .join('  |  ')
        : 'Não informado';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoBlock('Aluno(a)', student.fullName,
                  valueFont: boldFont, flex: 3),
              _buildInfoBlock('Data de Nasc.', _formatDate(student.birthDate),
                  flex: 2),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoBlock('Naturalidade', _displayText(student.nationality),
                  flex: 3),
              _buildInfoBlock('UF', _displayText(student.address.state),
                  flex: 1),
              _buildInfoBlock('Sexo', _displayText(student.gender), flex: 1),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoBlock('Filiação', filiacao, flex: 1),
            ],
          ),
        ],
      ),
    );
  }

  // --- TABELA DE NOTAS ---
  pw.Widget _buildGradesTable() {
    final List<pw.Widget> headers = [
      _buildTableCell('Componentes\nCurriculares',
          font: boldFont, alignment: pw.Alignment.centerLeft),
      ..._fixedGradeLevels.map((level) => _buildTableCell(level,
          font: boldFont, alignment: pw.Alignment.center)),
    ];

    // Coleta Matérias
    final Set<String> subjectNames = {};
    for (var record in history) {
      for (var grade in record.grades) {
        subjectNames.add(grade.subjectName);
      }
    }
    final List<String> sortedSubjects = subjectNames.toList()..sort();

    // Monta Linhas
    final List<pw.TableRow> dataRows = [];
    for (var subject in sortedSubjects) {
      final List<pw.Widget> rowCells = [
        _buildTableCell(subject,
            font: boldFont, alignment: pw.Alignment.centerLeft)
      ];

      for (var level in _fixedGradeLevels) {
        final record = history.firstWhereOrNull((h) => h.gradeLevel == level);
        String gradeValue = '';

        if (record != null) {
          final grade =
              record.grades.firstWhereOrNull((g) => g.subjectName == subject);
          if (grade != null) {
            gradeValue = grade.gradeValue;
          }
        }
        rowCells.add(_buildTableCell(gradeValue,
            font: baseFont, alignment: pw.Alignment.center));
      }
      dataRows.add(pw.TableRow(children: rowCells));
    }

    // Rodapé da Tabela
    final List<pw.Widget> workloadRowCells = [
      _buildTableCell('CARGA HORÁRIA\nANUAL',
          font: boldFont,
          alignment: pw.Alignment.centerLeft,
          color: PdfColors.grey200)
    ];
    final List<pw.Widget> resultRowCells = [
      _buildTableCell('RESULTADO\nFINAL',
          font: boldFont,
          alignment: pw.Alignment.centerLeft,
          color: PdfColors.grey200)
    ];

    for (var level in _fixedGradeLevels) {
      final record = history.firstWhereOrNull((h) => h.gradeLevel == level);

      workloadRowCells.add(_buildTableCell(record?.annualWorkload ?? '',
          font: boldFont,
          alignment: pw.Alignment.center,
          color: PdfColors.grey200));

      resultRowCells.add(_buildTableCell(record?.finalResult ?? '',
          font: boldFont,
          alignment: pw.Alignment.center,
          color: PdfColors.grey200));
    }
    dataRows.add(pw.TableRow(children: workloadRowCells));
    dataRows.add(pw.TableRow(children: resultRowCells));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(children: headers),
        ...dataRows,
      ],
    );
  }

  pw.Widget _buildTableCell(String text,
      {required pw.Font font,
      required pw.Alignment alignment,
      PdfColor? color}) {
    return pw.Container(
      alignment: alignment,
      color: color,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  /// TABELA DE HISTÓRICO (Segunda Tabela)
  pw.Widget _buildSchoolHistoryTable() {
    final List<String> headers = [
      'Série / Ano',
      'Ano',
      'Estabelecimento',
      'Cidade',
      'UF'
    ];

    final List<List<String>> data = [];
    for (var level in _fixedGradeLevels) {
      final record = history.firstWhereOrNull((h) => h.gradeLevel == level);

      if (record != null) {
        data.add([
          record.gradeLevel,
          record.schoolYear.toString(),
          record.schoolName,
          record.city,
          record.state,
        ]);
      } else {
        data.add([
          level,
          '',
          '',
          '',
          '',
        ]);
      }
    }

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
      cellStyle: pw.TextStyle(font: baseFont, fontSize: 9),
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.center,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(3),
      },
    );
  }

  /// RODAPÉ
  pw.Widget _buildTranscriptFooter() {
    String today =
        DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR').format(DateTime.now());

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('OBS: Histórico Transcrito Conforme Recebido',
            style: pw.TextStyle(font: italicFont, fontSize: 9)),
        pw.SizedBox(height: 15),
        pw.Center(
          child: pw.Text('Parauapebas, $today.',
              style: pw.TextStyle(font: baseFont, fontSize: 10)),
        ),
        pw.SizedBox(height: 40),
        pw.Center(
            child: pw.Column(children: [
          pw.Container(
              width: 250,
              child: pw.Divider(thickness: 1, color: PdfColors.black)),
          pw.Text('Assinatura da Secretaria',
              style: pw.TextStyle(font: baseFont, fontSize: 10)),
        ]))
      ],
    );
  }

  // --- Helpers Globais ---

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _displayText(String? text, {String defaultValue = 'N/A'}) {
    return (text == null || text.isEmpty) ? defaultValue : text;
  }
}
