import 'dart:convert';

import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/report_card_model.dart';

enum ReportCardEvaluationMode { numeric, developmental }

class ReportCardEvaluationModeHelper {
  static ReportCardEvaluationMode resolve({
    required ReportCardModel? reportCard,
    ClassModel? classModel,
    String? className,
  }) {
    final explicit = _normalize(reportCard?.evaluationMode ?? '');
    if (explicit == 'developmental' || explicit == 'infantil') {
      return ReportCardEvaluationMode.developmental;
    }
    if (explicit == 'numeric' || explicit == 'numerico') {
      return ReportCardEvaluationMode.numeric;
    }

    final gradingType = _normalize(reportCard?.gradingType ?? '');
    if (gradingType == 'developmental' || gradingType == 'infantil') {
      return ReportCardEvaluationMode.developmental;
    }
    if (gradingType == 'numeric' || gradingType == 'numerico') {
      return ReportCardEvaluationMode.numeric;
    }

    if (isEarlyChildhoodClass(
      className: className ?? classModel?.name ?? '',
      level: classModel?.level,
      grade: classModel?.grade,
      metadata: classModel?.scheduleSettings,
    )) {
      return ReportCardEvaluationMode.developmental;
    }

    return ReportCardEvaluationMode.numeric;
  }

  static bool isDevelopmental({
    required ReportCardModel? reportCard,
    ClassModel? classModel,
    String? className,
  }) {
    return resolve(
          reportCard: reportCard,
          classModel: classModel,
          className: className,
        ) ==
        ReportCardEvaluationMode.developmental;
  }

  static bool isEarlyChildhoodClass({
    required String className,
    String? level,
    String? grade,
    Map<String, dynamic>? metadata,
  }) {
    final reliableCandidates = <String>[
      level ?? '',
      grade ?? '',
      _metadataValue(metadata, 'stage'),
      _metadataValue(metadata, 'segment'),
      _metadataValue(metadata, 'educationLevel'),
      _metadataValue(metadata, 'education_level'),
      _metadataValue(metadata, 'series'),
      _metadataValue(metadata, 'classType'),
      _metadataValue(metadata, 'class_type'),
      _metadataValue(metadata, 'evaluationMode'),
      _metadataValue(metadata, 'evaluation_mode'),
    ].map(_normalize).where((value) => value.isNotEmpty).join(' ');

    if (metadata?['ensinoInfantil'] == true ||
        metadata?['earlyChildhood'] == true) {
      return true;
    }

    if (reliableCandidates.isNotEmpty) {
      return _matchesEarlyChildhood(reliableCandidates);
    }

    return _matchesEarlyChildhood(_normalize(className));
  }

  static bool _matchesEarlyChildhood(String value) {
    return value.contains('ensino infantil') ||
        value.contains('educacao infantil') ||
        value.contains('infantil') ||
        value.contains('maternal') ||
        RegExp(r'(^|\s)i periodo(\s|$)').hasMatch(value) ||
        RegExp(r'(^|\s)ii periodo(\s|$)').hasMatch(value) ||
        RegExp(r'(^|\s)1 periodo(\s|$)').hasMatch(value) ||
        RegExp(r'(^|\s)2 periodo(\s|$)').hasMatch(value) ||
        value.contains('primeiro periodo') ||
        value.contains('segundo periodo');
  }

  static String _metadataValue(Map<String, dynamic>? metadata, String key) {
    final value = metadata?[key];
    if (value == null) return '';
    if (value is String) return value;
    return jsonEncode(value);
  }

  static String _normalize(String value) {
    const withAccent = 'áàãâäéèêëíìîïóòõôöúùûüçºª';
    const withoutAccent = 'aaaaaeeeeiiiiooooouuuucao';
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = withAccent.indexOf(char);
      buffer.write(index >= 0 ? withoutAccent[index] : char);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'(?<=\d)[oa]\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
