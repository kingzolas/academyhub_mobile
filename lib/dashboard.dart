import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Providers e Services
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/invoice_provider.dart';
import 'package:academyhub_mobile/services/update_service.dart';
import 'package:academyhub_mobile/services/websocket.dart';
import 'package:academyhub_mobile/popup/update_popup.dart';

// Views
import 'package:academyhub_mobile/screens/dashboard/staff_dashboard_view.dart';
import 'package:academyhub_mobile/screens/dashboard/student_dashboard_view.dart';
import 'package:academyhub_mobile/screens/dashboard/professor_main_screen.dart'; // <--- IMPORT ATUALIZADO

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  OverlayEntry? _updateOverlayEntry;
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _checkForUpdates();
      _initWebSocketConnection();
      _listenToSocketEvents();
    });
  }

  void _initWebSocketConnection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null && user.schoolId.isNotEmpty) {
      _webSocketService.connect(user.schoolId);
    }
  }

  void _listenToSocketEvents() {
    if (!mounted) return;
    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _socketSubscription?.cancel();
    _socketSubscription = _webSocketService.stream.listen((message) {
      if (message['type'] == null) return;
      try {
        if (authProvider.isStudent) return;

        if (message['type'] == 'NEW_INVOICE' ||
            message['type'] == 'invoice:created') {
          if (message['payload'] != null) {
            invoiceProvider.handleInvoiceCreated(message['payload']);
          }
        }
      } catch (e) {
        debugPrint("Erro WebSocket: $e");
      }
    });
  }

  // Future<void> _checkForUpdates() async {
  //   final updateService = UpdateService();
  //   try {
  //     final updateRelease = await updateService.checkForUpdate();
  //     if (updateRelease != null && mounted) {
  //       _showUpdatePopup(updateRelease.downloadUrl, updateRelease.version);
  //     }
  //   } catch (e) {
  //     debugPrint("Erro updates: $e");
  //   }
  // }

  void _showUpdatePopup(String downloadUrl, String version) {
    if (_updateOverlayEntry != null) return;
    _updateOverlayEntry = OverlayEntry(
      builder: (context) => UpdateAvailablePopup(
        newVersion: version,
        onDismiss: () {
          _updateOverlayEntry?.remove();
          _updateOverlayEntry = null;
        },
        onUpdate: () {
          _updateOverlayEntry?.remove();
          _updateOverlayEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_updateOverlayEntry!);
  }

  @override
  void dispose() {
    _updateOverlayEntry?.remove();
    _socketSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // 1. É ALUNO?
    if (authProvider.isStudent) {
      return const StudentDashboardView();
    }

    // 2. É PROFESSOR?
    if (authProvider.isProfessor) {
      // CORREÇÃO: Agora chamamos o Wrapper que tem a BottomBar
      return const ProfessorMainScreen();
    }

    // 3. É GESTÃO?
    return StaffDashboardView(webSocketService: _webSocketService);
  }
}
