class Address {
  final String street;
  final String neighborhood;
  final String? number;
  final String? block;
  final String? lot;
  final String? zipCode; // Alinhado com o Backend
  final String city;
  final String state;

  Address({
    required this.street,
    required this.neighborhood,
    this.number,
    this.block,
    this.lot,
    this.zipCode,
    required this.city,
    required this.state,
  });

  Address copyWith({
    String? street,
    String? neighborhood,
    String? number,
    String? block,
    String? lot,
    String? zipCode,
    String? city,
    String? state,
  }) {
    return Address(
      street: street ?? this.street,
      neighborhood: neighborhood ?? this.neighborhood,
      number: number ?? this.number,
      block: block ?? this.block,
      lot: lot ?? this.lot,
      zipCode: zipCode ?? this.zipCode,
      city: city ?? this.city,
      state: state ?? this.state,
    );
  }

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        street: json["street"] ?? '',
        neighborhood: json["neighborhood"] ?? json["district"] ?? '',
        number: json["number"],
        block: json["block"],
        lot: json["lot"],
        zipCode: json["cep"] ??
            json["zipCode"], // Tenta zipCode primeiro, depois cep
        city: json["city"] ?? '',
        state: json["state"] ?? '',
      );

  Map<String, dynamic> toJson() => {
        "street": street,
        "neighborhood": neighborhood,
        "number": number,
        "block": block,
        "lot": lot,
        "zipCode": zipCode,
        "city": city,
        "state": state,
      };
}
