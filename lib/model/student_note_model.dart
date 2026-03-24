// lib/model/student_note_model.dart

enum StudentNoteType { private, attention, warning, unknown }

class NoteCreator {
  final String id;
  final String fullName;
  final String? profilePictureUrl;

  NoteCreator({
    required this.id,
    required this.fullName,
    this.profilePictureUrl,
  });

  factory NoteCreator.fromJson(Map<String, dynamic> json) {
    return NoteCreator(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      fullName: json['fullName'] ?? 'Usuário Desconhecido',
      profilePictureUrl: json['profilePictureUrl'],
    );
  }
}

class StudentNoteModel {
  final String id;
  final String schoolId;
  final String studentId;
  final NoteCreator? createdBy;
  final StudentNoteType type;
  final String title;
  final String description;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentNoteModel({
    required this.id,
    required this.schoolId,
    required this.studentId,
    this.createdBy,
    required this.type,
    required this.title,
    required this.description,
    required this.isResolved,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentNoteModel.fromJson(Map<String, dynamic> json) {
    return StudentNoteModel(
      id: (json['_id'] ?? '').toString(),
      schoolId: (json['schoolId'] ?? '').toString(),
      // studentId pode vir como string ou objeto populado
      studentId: json['studentId'] is Map
          ? (json['studentId']['_id'] ?? '').toString()
          : (json['studentId'] ?? '').toString(),
      createdBy: json['createdBy'] != null && json['createdBy'] is Map
          ? NoteCreator.fromJson(json['createdBy'])
          : null,
      type: _parseType(json['type']),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isResolved: json['isResolved'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': _typeToString(type),
      'title': title,
      'description': description,
      'isResolved': isResolved,
    };
  }

  static StudentNoteType _parseType(dynamic value) {
    final str = (value ?? '').toString().toUpperCase();
    switch (str) {
      case 'PRIVATE':
        return StudentNoteType.private;
      case 'ATTENTION':
        return StudentNoteType.attention;
      case 'WARNING':
        return StudentNoteType.warning;
      default:
        return StudentNoteType.unknown;
    }
  }

  static String _typeToString(StudentNoteType type) {
    switch (type) {
      case StudentNoteType.private:
        return 'PRIVATE';
      case StudentNoteType.attention:
        return 'ATTENTION';
      case StudentNoteType.warning:
        return 'WARNING';
      default:
        return 'PRIVATE';
    }
  }
}
