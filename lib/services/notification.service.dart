import 'dart:convert';

import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/main.dart';
import 'package:academyhub_mobile/popup/new_registration_popup.dart';
import 'package:academyhub_mobile/popup/new_user_popup.dart';
import 'package:academyhub_mobile/popup/payment_received_popup.dart';
import 'package:academyhub_mobile/popup/pop_up_new_student.dart'; // Certifique-se que o nome do arquivo está correto
import 'package:academyhub_mobile/widgets/approval_success_popup.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  late final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;

  void init(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldMessengerKey = key;
  }

  // --- [FUNÇÃO AJUSTADA PARA A CORUJA] ---
  void showNewStudentNotification({
    required String studentName,
    required String creatorName,
  }) {
    final context = _scaffoldMessengerKey.currentContext;
    if (context == null) return;

    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();

    // Largura total aproximada do novo widget (Card + Coruja)
    // Card (417) + Coruja (95) - Sobreposição (12) = 500
    final double totalWidgetWidth = 500.w;

    final snackBar = SnackBar(
      content: NewStudentPopup(
        studentName: studentName,
        creatorName: creatorName,
      ),
      // [CRUCIAL] Remove o fundo cinza e a sombra quadrada
      backgroundColor: Colors.transparent,
      elevation: 0,

      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      padding: EdgeInsets.zero,

      // Ajuste de margem para alinhar à direita corretamente com a nova largura
      margin: EdgeInsets.only(
          bottom: 30.h,
          right: 30.w,
          // Atualizamos aqui de 417 para 500 para dar espaço à coruja
          left: MediaQuery.of(context).size.width - totalWidgetWidth - 30.w),
    );

    _scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }

  void showApprovalSuccessNotification(String studentName) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => ApprovalSuccessPopup(
        studentName: studentName,
        onAnimationFinished: () => overlayEntry.remove(),
      ),
    );

    overlayState.insert(overlayEntry);
  }

  void showRegistrationRequestNotification({
    required String candidateName,
    required String typeLabel,
  }) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => NewRegistrationPopup(
        candidateName: candidateName,
        typeLabel: typeLabel,
        onAnimationFinished: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  void showNewUserNotification({
    required String userName,
    required String userRole,
  }) {
    final context = _scaffoldMessengerKey.currentContext;
    if (context == null) return;

    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: NewUserPopup(
        userName: userName,
        userRole: userRole,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      padding: EdgeInsets.zero,
      margin: EdgeInsets.only(
          bottom: 30.h,
          right: 30.w,
          left: MediaQuery.of(context).size.width - 417.w - 30.w),
    );

    _scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }

  void showPaymentReceivedNotification({
    required String title,
    required String description,
  }) {
    final context = _scaffoldMessengerKey.currentContext;
    if (context == null) {
      debugPrint("NotificationService: Scaffold context is not available.");
      return;
    }

    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: PaymentReceivedPopup(
        title: title,
        description: description,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 10),
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        top: 30.h,
        right: 30.w,
        left: MediaQuery.of(context).size.width - 417.w - 30.w,
      ),
    );

    _scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }

  Future<Map<String, dynamic>> getStats({required String token}) async {
    // Ajuste a URL conforme sua estrutura (ex: /automation/stats ou /notifications/stats)
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/notifications/stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Falha ao buscar estatísticas');
    }
  }

  Future<Map<String, dynamic>> getForecast(
      {required String token, String? date}) async {
    String url = '${ApiConfig.baseUrl}/notifications/forecast';
    if (date != null) url += '?date=$date';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Falha ao buscar previsão');
    }
  }
}
