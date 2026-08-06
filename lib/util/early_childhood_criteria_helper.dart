import 'package:academyhub_mobile/model/report_card_model.dart';

class EarlyChildhoodCriteriaHelper {
  static const statusAutonomy = 'autonomy';
  static const statusSupport = 'support';
  static const statusDeveloping = 'developing';
  static const statusNotWorked = 'not_worked';

  static const statusLabels = <String, String>{
    statusAutonomy: 'Realiza com autonomia',
    statusSupport: 'Realiza com apoio',
    statusDeveloping: 'Em desenvolvimento',
    statusNotWorked: 'Não trabalhado no bimestre',
  };

  static const compactStatusLabels = <String, String>{
    statusAutonomy: 'Autonomia',
    statusSupport: 'Com apoio',
    statusDeveloping: 'Em desenvolvimento',
    statusNotWorked: 'Não trabalhado',
  };

  static List<DevelopmentalSubjectAssessmentModel> assessmentsForReportCard(
    ReportCardModel reportCard,
  ) {
    final bySubject = {
      for (final assessment in reportCard.developmentalAssessments)
        assessment.developmentalKey: assessment
    };

    return reportCard.subjects.map((subject) {
      final existing = bySubject[subject.developmentalKey];
      if (existing != null && existing.criteria.isNotEmpty) {
        return existing.normalizedWithSubject(subject);
      }

      return DevelopmentalSubjectAssessmentModel(
        subjectId: subject.subjectId,
        areaId: subject.areaId,
        subjectName: subject.subjectNameSnapshot,
        teacherName: subject.teacherNameSnapshot,
        criteria: criteriaForSubject(subject.subjectNameSnapshot)
            .map(
              (criterion) => DevelopmentalCriterionAssessmentModel(
                criterionId: criterion.id,
                description: criterion.description,
                status: '',
                observation: '',
              ),
            )
            .toList(),
        generalObservation: subject.observation,
      );
    }).toList();
  }

  static DevelopmentalSubjectAssessmentModel assessmentForSubject(
    ReportCardModel reportCard,
    ReportCardSubjectModel subject,
  ) {
    return assessmentsForReportCard(reportCard).firstWhere(
      (assessment) => assessment.developmentalKey == subject.developmentalKey,
      orElse: () => DevelopmentalSubjectAssessmentModel(
        subjectId: subject.subjectId,
        areaId: subject.areaId,
        subjectName: subject.subjectNameSnapshot,
        teacherName: subject.teacherNameSnapshot,
        criteria: criteriaForSubject(subject.subjectNameSnapshot)
            .map(
              (criterion) => DevelopmentalCriterionAssessmentModel(
                criterionId: criterion.id,
                description: criterion.description,
                status: '',
                observation: '',
              ),
            )
            .toList(),
        generalObservation: subject.observation,
      ),
    );
  }

  static ReportCardModel applyAssessment(
    ReportCardModel reportCard,
    DevelopmentalSubjectAssessmentModel updated,
  ) {
    final assessments = assessmentsForReportCard(reportCard);
    final index = assessments
        .indexWhere((item) => item.developmentalKey == updated.developmentalKey);
    if (index >= 0) {
      assessments[index] = updated;
    } else {
      assessments.add(updated);
    }

    final subjects = reportCard.subjects.map((subject) {
      if (subject.developmentalKey != updated.developmentalKey) return subject;
      return subject.copyWith(
        observation: updated.generalObservation,
        status: updated.completionStatus,
      );
    }).toList();

    return reportCard.copyWith(
      evaluationMode: 'developmental',
      developmentalAssessments: assessments,
      subjects: subjects,
    );
  }

  static int filledCriteriaCount(ReportCardModel reportCard) {
    return assessmentsForReportCard(reportCard)
        .fold<int>(0, (sum, item) => sum + item.filledCriteriaCount);
  }

  static int totalCriteriaCount(ReportCardModel reportCard) {
    return assessmentsForReportCard(reportCard)
        .fold<int>(0, (sum, item) => sum + item.totalCriteriaCount);
  }

  static int completedAreasCount(ReportCardModel reportCard) {
    return assessmentsForReportCard(reportCard)
        .where((item) => item.isComplete)
        .length;
  }

  static int pendingAreasCount(ReportCardModel reportCard) {
    return assessmentsForReportCard(reportCard)
        .where((item) => !item.isComplete)
        .length;
  }

  static bool hasPendingCriteria(ReportCardModel reportCard) {
    return assessmentsForReportCard(reportCard).any((item) => !item.isComplete);
  }

  static List<EarlyChildhoodCriterion> criteriaForSubject(String subjectName) {
    final key = _normalize(subjectName);
    if (key.contains('matemat')) return _math;
    if (key.contains('natureza') || key.contains('sociedade')) {
      return _natureAndSociety;
    }
    if (key.contains('arte') || key.contains('musica')) return _art;
    if (key.contains('relig') || key.contains('valor')) return _values;
    return _language;
  }

  static String statusLabel(String status) {
    return statusLabels[status] ?? statusLabels[_normalizeStatus(status)] ?? '';
  }

  static String compactStatusLabel(String status) {
    return compactStatusLabels[status] ??
        compactStatusLabels[_normalizeStatus(status)] ??
        '';
  }

  static String _normalizeStatus(String status) {
    final value = _normalize(status);
    if (value.contains('autonomia')) return statusAutonomy;
    if (value.contains('apoio')) return statusSupport;
    if (value.contains('desenvolvimento')) return statusDeveloping;
    if (value.contains('nao trabalhado')) return statusNotWorked;
    return status;
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
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const _language = [
    EarlyChildhoodCriterion(
      'language_oral_expression',
      'Expressa ideias, sentimentos e necessidades oralmente.',
    ),
    EarlyChildhoodCriterion(
      'language_conversation_stories',
      'Participa de rodas de conversa e escuta histórias.',
    ),
    EarlyChildhoodCriterion(
      'language_own_name',
      'Reconhece seu nome em diferentes contextos.',
    ),
    EarlyChildhoodCriterion(
      'language_letters_images',
      'Demonstra interesse por letras, imagens e histórias.',
    ),
  ];

  static const _math = [
    EarlyChildhoodCriterion(
      'math_colors_shapes_quantities',
      'Reconhece cores, formas, tamanhos e quantidades em situações do cotidiano.',
    ),
    EarlyChildhoodCriterion(
      'math_simple_counting',
      'Realiza contagens simples com apoio.',
    ),
    EarlyChildhoodCriterion(
      'math_compare_objects',
      'Compara objetos por tamanho, quantidade ou característica.',
    ),
    EarlyChildhoodCriterion(
      'math_logic_games',
      'Participa de jogos e atividades de raciocínio lógico.',
    ),
  ];

  static const _natureAndSociety = [
    EarlyChildhoodCriterion(
      'nature_environment',
      'Demonstra cuidado com o próprio corpo e pertences.',
    ),
    EarlyChildhoodCriterion(
      'nature_self_care_belongings',
      'Interage com colegas e adultos respeitando combinados.',
    ),
    EarlyChildhoodCriterion(
      'nature_social_interaction',
      'Reconhece elementos do ambiente escolar e familiar.',
    ),
    EarlyChildhoodCriterion(
      'nature_family_environment',
      'Participa de atividades sobre natureza, família e convivência.',
    ),
  ];

  static const _art = [
    EarlyChildhoodCriterion(
      'art_painting_drawing_music',
      'Participa de atividades com pintura, desenho, colagem e música.',
    ),
    EarlyChildhoodCriterion(
      'art_materials_textures',
      'Explora diferentes materiais e texturas.',
    ),
    EarlyChildhoodCriterion(
      'art_fine_motor',
      'Desenvolve coordenação motora fina em atividades manuais.',
    ),
    EarlyChildhoodCriterion(
      'art_creativity',
      'Expressa criatividade em produções artísticas.',
    ),
  ];

  static const _values = [
    EarlyChildhoodCriterion(
      'values_reflection_prayer',
      'Participa de momentos de reflexão, oração ou valores.',
    ),
    EarlyChildhoodCriterion(
      'values_respect_care_sharing',
      'Demonstra atitudes de respeito, cuidado e partilha.',
    ),
    EarlyChildhoodCriterion(
      'values_classroom_agreements',
      'Reconhece combinados de convivência.',
    ),
    EarlyChildhoodCriterion(
      'values_positive_interaction',
      'Interage positivamente com colegas e professores.',
    ),
  ];
}

class EarlyChildhoodCriterion {
  final String id;
  final String description;

  const EarlyChildhoodCriterion(this.id, this.description);
}
