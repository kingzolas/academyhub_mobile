import 'dart:convert';

class ExamImage {
  String? url;
  String layout; // 'NONE', 'SMALL_INLINE', 'MEDIUM_CENTER', 'LARGE_FULL'

  ExamImage({this.url, this.layout = 'NONE'});

  factory ExamImage.fromJson(Map<String, dynamic> json) {
    return ExamImage(
      url: json['url'],
      layout: json['layout'] ?? 'NONE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'layout': layout,
    };
  }
}

class ExamQuestion {
  String type; // 'OBJECTIVE', 'DISSERTATIVE'
  String text;
  ExamImage? image;
  List<String>? options;

  // 👇 [NOVO] Adicionado o gabarito da questão
  String? correctAnswer;

  int linesToLeave;
  double weight;

  ExamQuestion({
    required this.type,
    required this.text,
    this.image,
    this.options,
    this.correctAnswer, // Inicializa a variável
    this.linesToLeave = 5,
    this.weight = 1.0,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      type: json['type'] ?? 'DISSERTATIVE',
      text: json['text'] ?? '',
      image: json['image'] != null ? ExamImage.fromJson(json['image']) : null,
      options:
          json['options'] != null ? List<String>.from(json['options']) : [],

      // 👇 Lê o gabarito vindo da API
      correctAnswer: json['correctAnswer'],

      linesToLeave: json['linesToLeave'] ?? 5,
      weight: (json['weight'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'image': image?.toJson(),
      'options': options,

      // 👇 Envia o gabarito preenchido pelo professor para a API
      'correctAnswer': correctAnswer,

      'linesToLeave': linesToLeave,
      'weight': weight,
    };
  }
}

class ExamModel {
  String? id;
  String classId;
  String subjectId;
  String teacherId;

  String title;
  DateTime applicationDate;
  double totalValue;

  // 👇 [NOVO] Identifica se a prova usará Cartão Resposta ou Lançamento Direto
  String correctionType;

  List<ExamQuestion> questions;
  String status;

  // Campos preenchidos quando fazemos GET (populate do mongoose)
  String? className;
  String? subjectName;
  String? teacherName;

  ExamModel({
    this.id,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.title,
    required this.applicationDate,
    required this.totalValue,
    this.correctionType =
        'DIRECT_GRADE', // Padrão é o lançamento direto para evitar quebrar código antigo
    required this.questions,
    this.status = 'DRAFT',
    this.className,
    this.subjectName,
    this.teacherName,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    String extractId(dynamic field) {
      if (field is Map) return field['_id'] ?? '';
      return field?.toString() ?? '';
    }

    String extractName(dynamic field) {
      if (field is Map) return field['name'] ?? '';
      return '';
    }

    return ExamModel(
      id: json['_id'],
      classId: extractId(json['class_id']),
      subjectId: extractId(json['subject_id']),
      teacherId: extractId(json['teacher_id']),
      title: json['title'] ?? '',
      applicationDate: json['applicationDate'] != null
          ? DateTime.parse(json['applicationDate'])
          : DateTime.now(),
      totalValue: (json['totalValue'] ?? 0).toDouble(),

      // 👇 Lê o tipo de correção da API
      correctionType: json['correctionType'] ?? 'DIRECT_GRADE',

      status: json['status'] ?? 'DRAFT',
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((q) => ExamQuestion.fromJson(q))
              .toList()
          : [],
      className: extractName(json['class_id']),
      subjectName: extractName(json['subject_id']),
      teacherName: extractName(json['teacher_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'title': title,
      'applicationDate': applicationDate.toIso8601String(),
      'totalValue': totalValue,

      // 👇 Envia o tipo de correção para a API
      'correctionType': correctionType,

      'questions': questions.map((q) => q.toJson()).toList(),
      'status': status,
    };
  }
}

// --- MODELS AUXILIARES PARA A GERAÇÃO DO PDF ---

class ExamSheetResponse {
  String message;
  Map<String, dynamic> examDetails;
  List<Map<String, dynamic>> sheets;

  ExamSheetResponse({
    required this.message,
    required this.examDetails,
    required this.sheets,
  });

  factory ExamSheetResponse.fromJson(Map<String, dynamic> json) {
    return ExamSheetResponse(
      message: json['message'] ?? '',
      examDetails: json['examDetails'] ?? {},
      sheets: json['sheets'] != null
          ? List<Map<String, dynamic>>.from(json['sheets'])
          : [],
    );
  }
}
