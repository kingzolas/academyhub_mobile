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
  int linesToLeave;
  double weight;

  ExamQuestion({
    required this.type,
    required this.text,
    this.image,
    this.options,
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
      'linesToLeave': linesToLeave,
      'weight': weight,
    };
  }
}

class ExamModel {
  String? id;
  String classId;
  String subjectId;

  String teacherId; // <--- CORRIGIDO: Agora é teacherId

  String title;
  DateTime applicationDate;
  double totalValue;
  List<ExamQuestion> questions;
  String status;

  // Campos preenchidos quando fazemos GET (populate do mongoose)
  String? className;
  String? subjectName;

  String? teacherName; // <--- CORRIGIDO

  ExamModel({
    this.id,
    required this.classId,
    required this.subjectId,
    required this.teacherId, // <--- OBRIGATÓRIO AGORA
    required this.title,
    required this.applicationDate,
    required this.totalValue,
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

      teacherId:
          extractId(json['teacher_id']), // <--- LÊ DO BACKEND COMO teacher_id

      title: json['title'] ?? '',
      applicationDate: json['applicationDate'] != null
          ? DateTime.parse(json['applicationDate'])
          : DateTime.now(),
      totalValue: (json['totalValue'] ?? 0).toDouble(),
      status: json['status'] ?? 'DRAFT',
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((q) => ExamQuestion.fromJson(q))
              .toList()
          : [],
      className: extractName(json['class_id']),
      subjectName: extractName(json['subject_id']),

      teacherName: extractName(json['teacher_id']), // <--- NOME DO PROFESSOR
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'subject_id': subjectId,

      'teacher_id': teacherId, // <--- ENVIA PARA A API COMO teacher_id

      'title': title,
      'applicationDate': applicationDate.toIso8601String(),
      'totalValue': totalValue,
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
