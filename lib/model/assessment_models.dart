import 'dart:convert';

// ==========================================
// MODELO DA AVALIAÇÃO (PROVA)
// ==========================================

class Assessment {
  final String? id;
  final String title;
  final String? description;
  final String? schoolId;
  final String? classId;
  final String? teacherId;
  final String? subjectId;
  final List<Question> questions;
  final String? difficultyLevel;
  final String? topic;
  final String status; // 'DRAFT', 'PUBLISHED', 'CLOSED'
  final AssessmentSettings settings;
  final DateTime? scheduledFor;
  final DateTime? deadline;
  final DateTime? createdAt;

  Assessment({
    this.id,
    required this.title,
    this.description,
    this.schoolId,
    this.classId,
    this.teacherId,
    this.subjectId,
    required this.questions,
    this.difficultyLevel,
    this.topic,
    this.status = 'DRAFT',
    required this.settings,
    this.scheduledFor,
    this.deadline,
    this.createdAt,
  });

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json['_id']?.toString(),
      title: json['title'] ?? 'Sem Título',
      description: json['description'],
      schoolId: json['school_id'],
      classId: json['class_id'],
      teacherId: json['teacher_id'],
      subjectId: json['subject_id'],
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromJson(q))
              .toList() ??
          [],
      difficultyLevel: json['difficultyLevel'],
      topic: json['topic'],
      status: json['status'] ?? 'DRAFT',
      settings: AssessmentSettings.fromJson(json['settings'] ?? {}),
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.parse(json['scheduledFor'])
          : null,
      deadline:
          json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'title': title,
      'description': description,
      'school_id': schoolId,
      'class_id': classId,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'questions': questions.map((q) => q.toJson()).toList(),
      'difficultyLevel': difficultyLevel,
      'topic': topic,
      'status': status,
      'settings': settings.toJson(),
      'scheduledFor': scheduledFor?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
    };
  }
}

class Question {
  final String? id;
  final String? category;
  final String questionText;
  final List<String> options;
  final int? correctIndex;
  final Explanation? explanation;
  final int points;

  Question({
    this.id,
    this.category,
    required this.questionText,
    required this.options,
    this.correctIndex,
    this.explanation,
    this.points = 1,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['_id'],
      category: json['category'],
      questionText: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correctIndex'],
      explanation: json['explanation'] != null
          ? Explanation.fromJson(json['explanation'])
          : null,
      points: json['points'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'question': questionText,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation?.toJson(),
      'points': points,
    };
  }
}

class Explanation {
  final String correct;
  final List<String> wrongs;

  Explanation({required this.correct, required this.wrongs});

  factory Explanation.fromJson(Map<String, dynamic> json) {
    return Explanation(
      correct: json['correct'] ?? '',
      wrongs: List<String>.from(json['wrongs'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'correct': correct,
        'wrongs': wrongs,
      };
}

class AssessmentSettings {
  final int timeLimitMinutes;
  final bool allowRetry;
  final bool showFeedbackInRealTime;

  AssessmentSettings({
    this.timeLimitMinutes = 0,
    this.allowRetry = false,
    this.showFeedbackInRealTime = true,
  });

  factory AssessmentSettings.fromJson(Map<String, dynamic> json) {
    return AssessmentSettings(
      timeLimitMinutes: json['timeLimitMinutes'] ?? 0,
      allowRetry: json['allowRetry'] ?? false,
      showFeedbackInRealTime: json['showFeedbackInRealTime'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'timeLimitMinutes': timeLimitMinutes,
        'allowRetry': allowRetry,
        'showFeedbackInRealTime': showFeedbackInRealTime,
      };
}

// ==========================================
// MODELO DA TENTATIVA (RESPOSTA DO ALUNO)
// ==========================================

class AssessmentAttempt {
  final String? id;
  final String? assessmentId;
  final String? studentId;
  final String? studentName;
  final String? studentEnrollment;
  final int? score;
  final int? totalQuestions;
  final int? correctCount;
  final List<AnswerDetail> answers;
  final Telemetry telemetry;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  AssessmentAttempt({
    this.id,
    this.assessmentId,
    this.studentId,
    this.studentName,
    this.studentEnrollment,
    this.score,
    this.totalQuestions,
    this.correctCount,
    required this.answers,
    required this.telemetry,
    this.status = 'IN_PROGRESS',
    this.startedAt,
    this.finishedAt,
  });

  factory AssessmentAttempt.fromJson(Map<String, dynamic> json) {
    String? sId;
    String? sName;
    String? sEnrollment;

    if (json['student_id'] is Map) {
      final studentObj = json['student_id'];
      sId = studentObj['_id']?.toString();
      sName = studentObj['fullName'];
      sEnrollment = studentObj['enrollmentNumber'];
    } else {
      sId = json['student_id']?.toString();
    }

    return AssessmentAttempt(
      id: json['_id']?.toString(),
      assessmentId: json['assessment_id']?.toString(),
      studentId: sId,
      studentName: sName,
      studentEnrollment: sEnrollment,
      score: json['score'],
      totalQuestions: json['totalQuestions'],
      correctCount: json['correctCount'],
      answers: (json['answers'] as List<dynamic>?)
              ?.map((a) => AnswerDetail.fromJson(a))
              .toList() ??
          [],
      telemetry: Telemetry.fromJson(json['telemetry'] ?? {}),
      status: json['status'] ?? 'IN_PROGRESS',
      startedAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      finishedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toSubmissionJson() {
    return {
      'answers': answers.map((a) => a.toJson()).toList(),
      'telemetry': telemetry.toJson(),
    };
  }
}

class AnswerDetail {
  final int questionIndex;
  final int selectedOptionIndex;
  final bool? isCorrect;
  final int timeSpentMs;
  final int switchedAppCount;

  AnswerDetail({
    required this.questionIndex,
    required this.selectedOptionIndex,
    this.isCorrect,
    required this.timeSpentMs,
    this.switchedAppCount = 0,
  });

  factory AnswerDetail.fromJson(Map<String, dynamic> json) {
    return AnswerDetail(
      questionIndex: json['questionIndex'],
      selectedOptionIndex: json['selectedOptionIndex'],
      isCorrect: json['isCorrect'],
      timeSpentMs: json['timeSpentMs'] ?? 0,
      switchedAppCount: json['switchedAppCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'questionIndex': questionIndex,
        'selectedOptionIndex': selectedOptionIndex,
        'timeSpentMs': timeSpentMs,
        'switchedAppCount': switchedAppCount,
      };
}

// [ATUALIZADO] Com campos de segurança
class Telemetry {
  final int totalTimeMs;
  final int focusLostCount;
  final int focusLostTimeMs;
  final int screenshotCount; // Novo
  final int resizeCount; // Novo (Split Screen)
  final String deviceInfo;

  Telemetry({
    required this.totalTimeMs,
    this.focusLostCount = 0,
    this.focusLostTimeMs = 0,
    this.screenshotCount = 0,
    this.resizeCount = 0,
    this.deviceInfo = 'Flutter App',
  });

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      totalTimeMs: json['totalTimeMs'] ?? 0,
      focusLostCount: json['focusLostCount'] ?? 0,
      focusLostTimeMs: json['focusLostTimeMs'] ?? 0,
      screenshotCount: json['screenshotCount'] ?? 0,
      resizeCount: json['resizeCount'] ?? 0,
      deviceInfo: json['deviceInfo'] ?? 'Flutter App',
    );
  }

  Map<String, dynamic> toJson() => {
        'totalTimeMs': totalTimeMs,
        'focusLostCount': focusLostCount,
        'focusLostTimeMs': focusLostTimeMs,
        'screenshotCount': screenshotCount,
        'resizeCount': resizeCount,
        'deviceInfo': deviceInfo,
      };
}
