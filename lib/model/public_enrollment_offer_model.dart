class PublicEnrollmentOfferModel {
  final String id;
  final String name;
  final String type;
  final String? description;
  final String? startTime;
  final String? endTime;
  final double? monthlyFee;
  final String pricingMode;
  final String permanenceClassMode;

  const PublicEnrollmentOfferModel({
    required this.id,
    required this.name,
    required this.type,
    required this.pricingMode,
    required this.permanenceClassMode,
    this.description,
    this.startTime,
    this.endTime,
    this.monthlyFee,
  });

  bool get isFullTime => type == 'full_time';

  bool get isTotalPricing => pricingMode == 'total';

  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Regime de permanência' : trimmed;
  }

  factory PublicEnrollmentOfferModel.fromJson(Map<String, dynamic> json) {
    return PublicEnrollmentOfferModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Regime de permanência',
      type: json['type']?.toString() ?? 'other',
      description: json['description']?.toString(),
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      monthlyFee: _parseMoney(json['monthlyFee']),
      pricingMode: json['pricingMode']?.toString() ?? 'total',
      permanenceClassMode: json['permanenceClassMode']?.toString() ?? 'none',
    );
  }

  static double? _parseMoney(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
