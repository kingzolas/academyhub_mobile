import 'package:flutter/material.dart';

class DashboardData {
  final DashboardCounts counts;
  final DashboardFinancial financial;
  final DashboardHistory history; // <--- NOVO: A história do ano
  final List<DashboardDailyChart> dailyChart;
  final List<DashboardBirthday> birthdays;
  final List<DashboardClassData> classData;

  DashboardData({
    required this.counts,
    required this.financial,
    required this.history,
    required this.dailyChart,
    required this.birthdays,
    required this.classData,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      counts: DashboardCounts.fromJson(json['counts'] ?? {}),
      financial: DashboardFinancial.fromJson(json['financial'] ?? {}),
      history: DashboardHistory.fromJson(json['history'] ?? {}),
      dailyChart: (json['dailyChart'] as List?)
              ?.map((e) => DashboardDailyChart.fromJson(e))
              .toList() ??
          [],
      birthdays: (json['birthdays'] as List?)
              ?.map((e) => DashboardBirthday.fromJson(e))
              .toList() ??
          [],
      classData: (json['classData'] as List?)
              ?.map((e) => DashboardClassData.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DashboardCounts {
  final int students;
  final int teachers;
  final int classes;
  final int subjects;

  DashboardCounts({
    this.students = 0,
    this.teachers = 0,
    this.classes = 0,
    this.subjects = 0,
  });

  factory DashboardCounts.fromJson(Map<String, dynamic> json) {
    return DashboardCounts(
      students: json['students'] ?? 0,
      teachers: json['teachers'] ?? 0,
      classes: json['classes'] ?? 0,
      subjects: json['subjects'] ?? 0,
    );
  }
}

class DashboardFinancial {
  final double saldoDia;
  final double saldoMes;
  final double totalAVencer; // Cash Flow Futuro
  final double totalVencido; // Risco
  final int inadimplenciaAlunos;
  final String inadimplenciaTaxa;
  final double despesaMes;
  final double despesaPendente;
  final double saldoLiquido;
  final PaymentMethods metodos; // Segmentação Cora vs MP

  DashboardFinancial({
    this.saldoDia = 0.0,
    this.saldoMes = 0.0,
    this.totalAVencer = 0.0,
    this.totalVencido = 0.0,
    this.inadimplenciaAlunos = 0,
    this.inadimplenciaTaxa = "0",
    this.despesaMes = 0.0,
    this.despesaPendente = 0.0,
    this.saldoLiquido = 0.0,
    required this.metodos,
  });

  factory DashboardFinancial.fromJson(Map<String, dynamic> json) {
    return DashboardFinancial(
      saldoDia: (json['saldoDia'] ?? 0).toDouble(),
      saldoMes: (json['saldoMes'] ?? 0).toDouble(),
      totalAVencer: (json['totalAVencer'] ?? 0).toDouble(),
      totalVencido: (json['totalVencido'] ?? 0).toDouble(),
      inadimplenciaAlunos: json['inadimplenciaAlunos'] ?? 0,
      inadimplenciaTaxa: json['inadimplenciaTaxa']?.toString() ?? "0",
      despesaMes: (json['despesaMes'] ?? 0).toDouble(),
      despesaPendente: (json['despesaPendente'] ?? 0).toDouble(),
      saldoLiquido: (json['saldoLiquido'] ?? 0).toDouble(),
      metodos: PaymentMethods.fromJson(json['metodos'] ?? {}),
    );
  }
}

class PaymentMethods {
  final MethodMetric boleto; // Cora
  final MethodMetric pix; // MP

  PaymentMethods({required this.boleto, required this.pix});

  factory PaymentMethods.fromJson(Map<String, dynamic> json) {
    return PaymentMethods(
      boleto: MethodMetric.fromJson(json['boleto'] ?? {}),
      pix: MethodMetric.fromJson(json['pix'] ?? {}),
    );
  }
}

class MethodMetric {
  final double recebido;
  final double aReceber;
  final double atrasado;

  MethodMetric({this.recebido = 0.0, this.aReceber = 0.0, this.atrasado = 0.0});

  factory MethodMetric.fromJson(Map<String, dynamic> json) {
    return MethodMetric(
      recebido: (json['recebido'] ?? 0).toDouble(),
      aReceber: (json['aReceber'] ?? 0).toDouble(),
      atrasado: (json['atrasado'] ?? 0).toDouble(),
    );
  }
}

class DashboardHistory {
  final int year;
  final List<MonthlyPerformance> performance;

  DashboardHistory({required this.year, required this.performance});

  factory DashboardHistory.fromJson(Map<String, dynamic> json) {
    return DashboardHistory(
      year: json['year'] ?? DateTime.now().year,
      performance: (json['performance'] as List?)
              ?.map((e) => MonthlyPerformance.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class MonthlyPerformance {
  final int month;
  final String monthName;
  final int studentCount;
  final MonthlyFinancial financial;

  MonthlyPerformance({
    required this.month,
    required this.monthName,
    required this.studentCount,
    required this.financial,
  });

  factory MonthlyPerformance.fromJson(Map<String, dynamic> json) {
    return MonthlyPerformance(
      month: json['month'] ?? 0,
      monthName: json['monthName'] ?? '',
      studentCount: json['studentCount'] ?? 0,
      financial: MonthlyFinancial.fromJson(json['financial'] ?? {}),
    );
  }
}

class MonthlyFinancial {
  final double expected;
  final double paid;
  final double overdue;
  final double collectionRate;

  MonthlyFinancial(
      {this.expected = 0.0,
      this.paid = 0.0,
      this.overdue = 0.0,
      this.collectionRate = 0.0});

  factory MonthlyFinancial.fromJson(Map<String, dynamic> json) {
    return MonthlyFinancial(
      expected: (json['expected'] ?? 0).toDouble(),
      paid: (json['paid'] ?? 0).toDouble(),
      overdue: (json['overdue'] ?? 0).toDouble(),
      collectionRate: (json['collectionRate'] ?? 0).toDouble(),
    );
  }
}

// Mantidos iguais
class DashboardDailyChart {
  final int day;
  final double value;
  DashboardDailyChart({required this.day, required this.value});
  factory DashboardDailyChart.fromJson(Map<String, dynamic> json) {
    return DashboardDailyChart(
      day: json['day'] ?? 0,
      value: (json['value'] ?? 0).toDouble(),
    );
  }
}

class DashboardBirthday {
  final String fullName;
  final String? birthDate;
  final String? profilePicture;
  DashboardBirthday(
      {required this.fullName, this.birthDate, this.profilePicture});
  factory DashboardBirthday.fromJson(Map<String, dynamic> json) {
    return DashboardBirthday(
      fullName: json['fullName'] ?? 'Desconhecido',
      birthDate: json['birthDate'],
      profilePicture: json['profilePicture'],
    );
  }
}

class DashboardClassData {
  final String className;
  final int studentCount;
  final String percentage;
  DashboardClassData(
      {required this.className,
      required this.studentCount,
      required this.percentage});
  factory DashboardClassData.fromJson(Map<String, dynamic> json) {
    return DashboardClassData(
      className: json['className'] ?? 'Turma',
      studentCount: json['studentCount'] ?? 0,
      percentage: json['percentage']?.toString() ?? "0",
    );
  }
}
