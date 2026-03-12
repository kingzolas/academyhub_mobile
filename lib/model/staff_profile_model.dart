// lib/model/staff_profile_model.dart
import 'package:academyhub_mobile/model/subject_model.dart';

class StaffProfile {
  final String id;
  final String userId;

  final DateTime admissionDate;
  final String employmentType;
  final String mainRole;
  final String remunerationModel;

  final double? salaryAmount;
  final double? hourlyRate;
  final int? weeklyWorkload;

  final String? academicFormation;
  final List<String> enabledLevels;
  final List<SubjectModel> enabledSubjects;

  // NOVOS
  final String? nationality;
  final String? maritalStatus; // SOLTEIRO, CASADO, ...
  final String? rg; // documents.rg
  final DateTime? terminationDate;

  StaffProfile({
    required this.id,
    required this.userId,
    required this.admissionDate,
    required this.employmentType,
    required this.mainRole,
    required this.remunerationModel,
    this.salaryAmount,
    this.hourlyRate,
    this.weeklyWorkload,
    this.academicFormation,
    required this.enabledLevels,
    required this.enabledSubjects,
    this.nationality,
    this.maritalStatus,
    this.rg,
    this.terminationDate,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    final docs = (json['documents'] is Map<String, dynamic>)
        ? json['documents'] as Map<String, dynamic>
        : null;

    DateTime? tryDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    // ✅ admissionDate defensivo (evita crash se backend mandar null)
    final parsedAdmission = tryDate(json['admissionDate']) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    // ✅ Parse robusto: aceita List<Map> OU List<String>
    final rawSubjects = json['enabledSubjects'];
    final enabledSubjects = <SubjectModel>[];
    if (rawSubjects is List) {
      for (final item in rawSubjects) {
        final s = SubjectModel.fromAny(item);
        if (s.id.isNotEmpty) enabledSubjects.add(s);
      }
    }

    return StaffProfile(
      id: (json['_id'] ?? '').toString(),
      userId: (json['user'] is Map)
          ? (json['user']['_id'] ?? '').toString()
          : (json['user'] ?? '').toString(),
      admissionDate: parsedAdmission,
      employmentType: (json['employmentType'] ?? '').toString(),
      mainRole: (json['mainRole'] ?? '').toString(),
      remunerationModel: (json['remunerationModel'] ?? '').toString(),
      salaryAmount: (json['salaryAmount'] as num?)?.toDouble(),
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble(),
      weeklyWorkload: (json['weeklyWorkload'] as num?)?.toInt(),
      academicFormation: (json['academicFormation'] as String?)?.trim(),
      enabledLevels: List<String>.from(json['enabledLevels'] ?? const []),
      enabledSubjects: enabledSubjects,

      // NOVOS
      nationality: (json['nationality'] as String?)?.trim(),
      maritalStatus: (json['maritalStatus'] as String?)?.trim(),
      rg: (docs?['rg'] as String?)?.trim(),
      terminationDate: tryDate(json['terminationDate']),
    );
  }

  Map<String, dynamic> toJsonForCreate(String userId, List<String> subjectIds) {
    final map = <String, dynamic>{
      'user': userId,
      'admissionDate': admissionDate.toIso8601String(),
      'employmentType': employmentType,
      'mainRole': mainRole,
      'remunerationModel': remunerationModel,
      'salaryAmount': salaryAmount,
      'hourlyRate': hourlyRate,
      'weeklyWorkload': weeklyWorkload,
      'academicFormation': academicFormation,
      'enabledLevels': enabledLevels,
      'enabledSubjects': subjectIds,
      // NOVOS
      'nationality': nationality,
      'maritalStatus': maritalStatus,
      'terminationDate': terminationDate?.toIso8601String(),
      'documents': {
        'rg': rg,
      },
    };

    // remove null/empty
    map.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));

    if (map['documents'] is Map) {
      (map['documents'] as Map).removeWhere(
          (k, v) => v == null || (v is String && v.trim().isEmpty));
      if ((map['documents'] as Map).isEmpty) map.remove('documents');
    }

    return map;
  }
}
