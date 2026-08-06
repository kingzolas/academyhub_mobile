class PublicRegistrationClassModel {
  final String id;
  final String name;
  final String? educationLevel;
  final String? grade;
  final String? shift;
  final String? startTime;
  final String? endTime;
  final double? monthlyFee;
  final String availabilityStatus;

  const PublicRegistrationClassModel({
    required this.id,
    required this.name,
    required this.availabilityStatus,
    this.educationLevel,
    this.grade,
    this.shift,
    this.startTime,
    this.endTime,
    this.monthlyFee,
  });

  bool get isAvailable =>
      availabilityStatus == 'available' || availabilityStatus == 'few_slots';

  String get availabilityLabel {
    switch (availabilityStatus) {
      case 'available':
        return 'Disponível';
      case 'few_slots':
        return 'Poucas vagas';
      case 'unavailable':
        return 'Indisponível';
      default:
        return 'Consultar escola';
    }
  }

  factory PublicRegistrationClassModel.fromJson(Map<String, dynamic> json) {
    return PublicRegistrationClassModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Turma',
      educationLevel: json['educationLevel']?.toString(),
      grade: json['grade']?.toString(),
      shift: json['shift']?.toString(),
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      monthlyFee: _parseMoney(json['monthlyFee']),
      availabilityStatus:
          json['availabilityStatus']?.toString() ?? 'unavailable',
    );
  }

  static double? _parseMoney(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class PublicRegistrationSchoolContext {
  final String id;
  final String name;
  final String? logoUrl;

  const PublicRegistrationSchoolContext({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'AH';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory PublicRegistrationSchoolContext.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
    String? resolvedLogoUrl,
  }) {
    final school = json['school'] is Map<String, dynamic>
        ? json['school'] as Map<String, dynamic>
        : json;

    return PublicRegistrationSchoolContext(
      id: school['id']?.toString() ?? fallbackId,
      name: school['name']?.toString() ?? 'Escola',
      logoUrl: resolvedLogoUrl ?? school['logoUrl']?.toString(),
    );
  }
}
