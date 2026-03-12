import 'dart:async'; // Para o Debounce

import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:academyhub_mobile/popup/action_status_popup.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/class_provider.dart';
import 'package:academyhub_mobile/providers/financial_automation_provider.dart';
import 'package:academyhub_mobile/providers/invoice_provider.dart';
import 'package:academyhub_mobile/providers/privacy_provider.dart';
import 'package:academyhub_mobile/services/enrollment_service.dart';
import 'package:academyhub_mobile/widgets/cobranca_details_popup.dart';
import 'package:academyhub_mobile/widgets/create_invoice_dialog.dart';
import 'package:academyhub_mobile/widgets/negotiation_dialog.dart';

import 'package:collection/collection.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

class _MonthItem {
  final String key; // "MM/yyyy" ou "ALL"
  final String label; // "Fevereiro/2026" ou "Todos os meses"
  const _MonthItem(this.key, this.label);
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

// --- Definição de Cores do Design System ---
class AppColors {
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryBlack = Color(0xFF121212);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFE53935);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color automationPurple = Color(0xFF9C27B0);

  // Cores Específicas dos Gateways
  static const Color coraPink = Color(0xFFFE3E6D);
  static const Color mpBlue = Color(0xFF009EE3);

  static Color background(bool isDark) =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  static Color surface(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : Colors.white;
  static Color textPrimary(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF2D3748);
  static Color textSecondary(bool isDark) =>
      isDark ? Colors.grey[400]! : const Color(0xFF718096);
  static Color border(bool isDark) =>
      isDark ? Colors.grey[800]! : Colors.grey[300]!;
}

enum ReceivedFilter {
  all,
  pix,
  boleto,
  manual,
  cora,
  mercadopago,
}

extension ReceivedFilterLabel on ReceivedFilter {
  String get label {
    switch (this) {
      case ReceivedFilter.all:
        return "Todos";
      case ReceivedFilter.pix:
        return "Pix";
      case ReceivedFilter.boleto:
        return "Boleto";
      case ReceivedFilter.manual:
        return "Manual";
      case ReceivedFilter.cora:
        return "Cora";
      case ReceivedFilter.mercadopago:
        return "Mercado Pago";
    }
  }
}

class ScreenFinanceiro extends StatefulWidget {
  const ScreenFinanceiro({super.key});

  @override
  State<ScreenFinanceiro> createState() => _ScreenFinanceiroState();
}

class _ScreenFinanceiroState extends State<ScreenFinanceiro>
    with TickerProviderStateMixin {
  // --- SYNC INTELIGENTE ---
  static DateTime? _lastSyncTime;
  final Duration _syncCooldown = const Duration(minutes: 2);
  bool _isSyncing = false;
  bool _isSyncRunning = false;

  // ✅ Chave "Todos os meses"
  static const String _allMonthsKey = 'ALL';
  static const _MonthItem _allMonthsItem =
      _MonthItem(_allMonthsKey, 'Todos os meses');

  bool _showAutomationDashboard = false;
  bool _showCompensationScreen = false; // ✅ novo

  late TabController _tabController;
  final _searchNameController = TextEditingController();
  final _searchTutorController = TextEditingController();
  Timer? _debounce;

  String? _selectedClassId;

  String? _competenceMonthYear; // "MM/yyyy" ou "ALL"
  String? _cashMonthYear; // "MM/yyyy" ou "ALL"
  String? _paidCompetenceFilterKey; // "MM/yyyy" (ou null)

  List<_MonthItem> _monthItems = [];
  List<_MonthItem> get _monthItemsWithAll => [_allMonthsItem, ..._monthItems];

  ReceivedFilter _receivedFilter = ReceivedFilter.all;

  bool _isProviderInitialized = false;
  List<Enrollment> _activeEnrollments = [];

  List<Invoice> _filteredInvoices = [];
  Map<String, List<Invoice>> _groupedInvoices = {};

  Map<String, double> _kpiTotals = {'pending': 0, 'paid': 0, 'canceled': 0};

  Map<String, double> _receivedTimelineTotals = {}; // "MM/yyyy" -> valor (R$)
  Map<String, double> _receivedBreakdownByCompetence = {}; // "MM/yyyy" -> valor
  int _receivedBreakdownCount = 0;

  bool _showFeedback = false;
  bool _isFeedbackError = false;
  String _feedbackTitle = "";
  String _feedbackMessage = "";
  bool _isSendingWhatsapp = false;

  // ============================
  // PRIVACY IDs (namespaced)
  // ============================
  String _id(String raw) => 'finance:$raw';

  String _kpiId(String key) => _id('kpi:$key');
  String _timelineTotalId(String cashKey) =>
      _id('timeline_total:$cashKey:${_receivedFilter.name}');
  String _timelineChipId(String monthKey) =>
      _id('timeline_chip:$monthKey:${_receivedFilter.name}');
  String _breakdownChipId(String compKey, String cashKey) =>
      _id('breakdown:$cashKey:$compKey:${_receivedFilter.name}');
  String _studentTotalId(String studentId) => _id('student_total:$studentId');
  String _invoiceValueId(String invoiceId) => _id('invoice_value:$invoiceId');
  String _batchValueId(String invoiceId) => _id('batch_value:$invoiceId');

  bool get _hasActiveFilters =>
      _searchNameController.text.isNotEmpty ||
      _searchTutorController.text.isNotEmpty ||
      _selectedClassId != null;

  String _formatMonthYear(DateTime d) => intl.DateFormat('MM/yyyy').format(d);

  DateTime _parseMonthYear(String my) {
    final parts = my.split('/');
    return DateTime(int.parse(parts[1]), int.parse(parts[0]), 1);
  }

  String _monthLabelFromKey(String my) {
    if (my == _allMonthsKey) return _allMonthsItem.label;
    final d = _parseMonthYear(my);
    final labelRaw = intl.DateFormat('MMMM/yyyy', 'pt_BR').format(d);
    return _capitalize(labelRaw);
  }

  void _buildFixedLast12Months() {
    final now = DateTime.now();
    final items = <_MonthItem>[];

    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = _formatMonthYear(d);
      final label = _monthLabelFromKey(key);
      items.add(_MonthItem(key, label));
    }

    if (mounted) {
      setState(() {
        _monthItems = items;
        final nowKey = items.first.key;
        _competenceMonthYear ??= nowKey;
        _cashMonthYear ??= nowKey;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _searchNameController.addListener(_onSearchChanged);
    _searchTutorController.addListener(_onSearchChanged);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index != 3 && _paidCompetenceFilterKey != null) {
          _paidCompetenceFilterKey = null;
        }
        _applyLocalFilters();
      }
    });

    final now = DateTime.now();
    final nowMY = _formatMonthYear(now);
    _competenceMonthYear = nowMY;
    _cashMonthYear = nowMY;

    _buildFixedLast12Months();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _applyLocalFilters();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isProviderInitialized) {
      _isProviderInitialized = true;
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      if (invoiceProvider.allInvoices.isNotEmpty) {
        _rebuildMonthFilters(invoiceProvider.allInvoices);
        _applyLocalFilters();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchNameController.dispose();
    _searchTutorController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);

    if (token == null) return;

    if (classProvider.classes.isEmpty) {
      classProvider.fetchClasses(token).catchError((e) {});
    }
    if (_activeEnrollments.isEmpty) {
      EnrollmentService()
          .getEnrollments(token, filter: {'status': 'Ativa'}).then((data) {
        if (mounted) setState(() => _activeEnrollments = data);
      }).catchError((e) {});
    }

    debugPrint("📥 [Data] Baixando lista de faturas (rápido)...");
    await _reloadList(token, invoiceProvider);

    _triggerBackgroundSync(token, invoiceProvider);
  }

  void _triggerBackgroundSync(String token, InvoiceProvider invoiceProvider) {
    final now = DateTime.now();
    final shouldSync =
        _lastSyncTime == null || now.difference(_lastSyncTime!) > _syncCooldown;

    if (!shouldSync) return;
    if (_isSyncRunning) return;

    _isSyncRunning = true;
    if (mounted) {
      setState(() => _isSyncing = true);
    }

    debugPrint("🔄 [Sync] Iniciando sincronização em background...");
    () async {
      try {
        final response = await invoiceProvider.syncPendingInvoices(token);
        if (response != null && response.containsKey('stats')) {
          final stats = response['stats'];
          final updated = stats['updatedCount'] ?? 0;
          debugPrint("✅ [Sync] Finalizado. Itens atualizados: $updated");
        }
        _lastSyncTime = now;

        if (mounted) {
          debugPrint("📥 [Data] Recarregando lista após sync...");
          await _reloadList(token, invoiceProvider);
        }
      } catch (e) {
        debugPrint("⚠️ [Sync] Erro na sincronização: $e");
      } finally {
        _isSyncRunning = false;
        if (mounted) {
          setState(() => _isSyncing = false);
        }
      }
    }();
  }

  Future<void> _reloadList(
      String token, InvoiceProvider invoiceProvider) async {
    await invoiceProvider.fetchAllInvoices(token: token, status: null);

    if (mounted) {
      _rebuildMonthFilters(invoiceProvider.allInvoices);
      _applyLocalFilters();
    }
  }

  void _rebuildMonthFilters(List<Invoice> invoices) {
    if (_monthItems.isEmpty) {
      _buildFixedLast12Months();
    }

    final nowMY = _formatMonthYear(DateTime.now());
    _competenceMonthYear ??= nowMY;
    _cashMonthYear ??= nowMY;

    if (_monthItems.isNotEmpty) {
      final validKeys = <String>{
        _allMonthsKey,
        ..._monthItems.map((m) => m.key)
      };

      if (!validKeys.contains(_competenceMonthYear)) {
        _competenceMonthYear = _monthItems.first.key;
      }
      if (!validKeys.contains(_cashMonthYear)) {
        _cashMonthYear = _monthItems.first.key;
      }

      if (_paidCompetenceFilterKey != null &&
          !_monthItems.any((m) => m.key == _paidCompetenceFilterKey)) {
        _paidCompetenceFilterKey = null;
      }
    }
  }

  String _removeDiacritics(String str) {
    var withDia =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  bool _matchesReceivedFilter(Invoice inv) {
    final pm = (inv.paymentMethod ?? '').toLowerCase();
    final gw = (inv.gateway ?? '').toLowerCase();

    switch (_receivedFilter) {
      case ReceivedFilter.all:
        return true;
      case ReceivedFilter.pix:
        return pm == 'pix';
      case ReceivedFilter.boleto:
        return pm == 'boleto';
      case ReceivedFilter.manual:
        return (gw.isEmpty || gw == 'manual') && pm != 'pix' && pm != 'boleto';
      case ReceivedFilter.cora:
        return gw == 'cora';
      case ReceivedFilter.mercadopago:
        return gw == 'mercadopago';
    }
  }

  void _clearPaidCompetenceFilter() {
    if (_paidCompetenceFilterKey == null) return;
    setState(() => _paidCompetenceFilterKey = null);
    _applyLocalFilters();
  }

  void _applyLocalFilters() {
    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final allInvoices = invoiceProvider.allInvoices;

    final searchNome =
        _removeDiacritics(_searchNameController.text.toLowerCase().trim());
    final searchTutor =
        _removeDiacritics(_searchTutorController.text.toLowerCase().trim());

    Set<String> studentIdsInSelectedClass = {};
    if (_selectedClassId != null) {
      studentIdsInSelectedClass = _activeEnrollments
          .where((e) => e.classInfo.id == _selectedClassId)
          .map((e) => e.student.id)
          .toSet();
    }

    final competenceMY =
        _competenceMonthYear ?? _formatMonthYear(DateTime.now());
    final cashMY = _cashMonthYear ?? _formatMonthYear(DateTime.now());

    final bool competenceAll = competenceMY == _allMonthsKey;
    final bool cashAll = cashMY == _allMonthsKey;

    final filtered = allInvoices.where((invoice) {
      bool statusMatch = true;
      switch (_tabController.index) {
        case 0:
          statusMatch = true;
          break;
        case 1:
          statusMatch = invoice.status == 'pending';
          break;
        case 2:
          statusMatch = _isOverdue(invoice.status, invoice.dueDate);
          break;
        case 3:
          statusMatch = invoice.status == 'paid';
          break;
        case 4:
          statusMatch = invoice.status == 'canceled';
          break;
      }
      if (!statusMatch) return false;

      final studentName =
          _removeDiacritics((invoice.student?.fullName ?? "").toLowerCase());
      final tutorName =
          _removeDiacritics((invoice.tutor?.fullName ?? "").toLowerCase());

      final matchesNome =
          searchNome.isEmpty || studentName.startsWith(searchNome);
      final matchesTutor =
          searchTutor.isEmpty || tutorName.startsWith(searchTutor);

      final matchesClass = _selectedClassId == null ||
          (invoice.student != null &&
              studentIdsInSelectedClass.contains(invoice.student!.id));

      bool matchesMonth = true;

      if (_tabController.index == 3) {
        final paidAt = invoice.effectivePaidAt;
        if (paidAt == null) return false;

        final matchesCash = cashAll ? true : _formatMonthYear(paidAt) == cashMY;
        if (!matchesCash) return false;

        if (_paidCompetenceFilterKey != null) {
          final dueKey = _formatMonthYear(invoice.dueDate);
          if (dueKey != _paidCompetenceFilterKey) return false;
        }

        matchesMonth = true;
      } else {
        matchesMonth = competenceAll
            ? true
            : _formatMonthYear(invoice.dueDate) == competenceMY;
      }

      return matchesNome && matchesTutor && matchesClass && matchesMonth;
    }).toList();

    double pending = 0;
    double paid = 0;
    double canceled = 0;

    final Map<String, double> receivedTimeline = {};
    final Map<String, double> breakdownCompetence = {};
    int breakdownCount = 0;

    for (var inv in allInvoices) {
      if (inv.status == 'paid') {
        final paidAt = inv.effectivePaidAt;
        if (paidAt != null) {
          final paidMY = _formatMonthYear(paidAt);

          if (_matchesReceivedFilter(inv)) {
            receivedTimeline[paidMY] =
                (receivedTimeline[paidMY] ?? 0) + (inv.value / 100.0);
          }

          final paidMatchesCash = cashAll ? true : (paidMY == cashMY);

          if (paidMatchesCash && _matchesReceivedFilter(inv)) {
            paid += inv.value;

            final compKey = _formatMonthYear(inv.dueDate);
            breakdownCompetence[compKey] =
                (breakdownCompetence[compKey] ?? 0) + (inv.value / 100.0);
            breakdownCount++;
          }
        }
      } else if (inv.status == 'canceled') {
        final cancMatches = competenceAll
            ? true
            : (_formatMonthYear(inv.dueDate) == competenceMY);
        if (cancMatches) {
          canceled += inv.value;
        }
      } else {
        final pendMatches = competenceAll
            ? true
            : (_formatMonthYear(inv.dueDate) == competenceMY);
        if (pendMatches) {
          pending += inv.value;
        }
      }
    }

    final breakdownOrderedKeys = breakdownCompetence.keys.toList()
      ..sort((a, b) =>
          (breakdownCompetence[b] ?? 0).compareTo(breakdownCompetence[a] ?? 0));
    final Map<String, double> breakdownSorted = {
      for (final k in breakdownOrderedKeys) k: breakdownCompetence[k] ?? 0
    };

    if (mounted) {
      setState(() {
        _filteredInvoices = filtered;
        _groupedInvoices =
            groupBy(filtered, (inv) => inv.student?.id ?? 'sem-aluno');

        _kpiTotals = {
          'pending': pending / 100.0,
          'paid': paid / 100.0,
          'canceled': canceled / 100.0,
        };

        _receivedTimelineTotals = receivedTimeline;
        _receivedBreakdownByCompetence = breakdownSorted;
        _receivedBreakdownCount = breakdownCount;
      });
    }
  }

  void _clearFilters() {
    _searchNameController.clear();
    _searchTutorController.clear();
    setState(() {
      _selectedClassId = null;
    });
    _applyLocalFilters();
  }

  void _showNovaCobrancaPopup() {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateInvoiceDialog(
        token: token,
        activeEnrollments: _activeEnrollments,
        onSaveSuccess: () {
          _fetchData();
        },
      ),
    );
  }

  void _showCobrancaDetails(Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => CobrancaDetailsPopup(
        invoice: invoice,
        onCancel: (id) async {
          final provider = Provider.of<InvoiceProvider>(context, listen: false);
          final token = Provider.of<AuthProvider>(context, listen: false).token;
          if (await provider.cancelInvoice(invoiceId: id, token: token!)) {
            _applyLocalFilters();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Fatura cancelada"),
                  backgroundColor: AppColors.primaryGreen));
            }
          }
        },
      ),
    );
  }

  void _showNegotiation(BuildContext context, List<Invoice> invoices) {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    final toNegotiate = invoices
        .where((inv) =>
            inv.status == 'pending' || _isOverdue(inv.status, inv.dueDate))
        .toList();

    if (toNegotiate.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Nada para negociar.")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<NegotiationProvider>(context, listen: false),
        child: NegotiationPopup(
          token: token,
          studentId: toNegotiate.first.student!.id,
          invoicesToNegotiate: toNegotiate,
          onSaveSuccess: () {
            Navigator.pop(context);
            _fetchData();
          },
        ),
      ),
    );
  }

  String _getFriendlyErrorMessage(String technicalError) {
    final lowerError = technicalError.toLowerCase();
    if (lowerError.contains("exists:false") ||
        lowerError.contains("status code 400") ||
        lowerError.contains("bad request")) {
      return "O número cadastrado não possui WhatsApp ou é inválido.";
    }
    if (lowerError.contains("timeout") || lowerError.contains("conexão")) {
      return "Tempo limite excedido. Tente novamente mais tarde.";
    }
    if (lowerError.contains("unauthorized") || lowerError.contains("401")) {
      return "Sessão expirada. Faça login novamente.";
    }
    return technicalError;
  }

  Future<void> _handleWhatsApp(Invoice invoice) async {
    if (_isSendingWhatsapp) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() => _isSendingWhatsapp = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 10),
          Text("Adicionando à fila de envio..."),
        ]),
        duration: Duration(seconds: 1),
      ),
    );

    final errorMessage =
        await Provider.of<InvoiceProvider>(context, listen: false)
            .resendWhatsappNotification(invoiceId: invoice.id, token: token);

    setState(() {
      _isSendingWhatsapp = false;
      _showFeedback = true;
      if (errorMessage == null) {
        _isFeedbackError = false;
        _feedbackTitle = "Agendado!";
        _feedbackMessage =
            "A mensagem foi colocada na fila e será enviada em breve.";
      } else {
        _isFeedbackError = true;
        _feedbackTitle = "Não foi possível enviar";
        _feedbackMessage = _getFriendlyErrorMessage(errorMessage);
      }
    });
  }

  // ============================
  // MOBILE: BottomSheet de ações/filtros
  // ============================
  void _openFiltersSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18.r),
                  topRight: Radius.circular(18.r),
                ),
                border: Border.all(color: AppColors.border(isDark)),
              ),
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Container(
                    width: 44.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: AppColors.border(isDark),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.funnel_simple,
                            color: AppColors.primaryBlue, size: 18.sp),
                        SizedBox(width: 10.w),
                        Text(
                          "Filtros e ações",
                          style: GoogleFonts.sairaCondensed(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(PhosphorIcons.x,
                              color: AppColors.textSecondary(isDark)),
                        )
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border(isDark)),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.all(16.w),
                      children: [
                        _buildMobileTopControls(isDark),
                        SizedBox(height: 14.h),
                        _buildMobileFilters(isDark),
                        SizedBox(height: 14.h),
                        _buildMobileActions(isDark),
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileTopControls(bool isDark) {
    final competenceMY =
        _competenceMonthYear ?? _formatMonthYear(DateTime.now());
    final items = _monthItemsWithAll;
    final competenceItem = items.firstWhere(
      (m) => m.key == competenceMY,
      orElse: () => _MonthItem(competenceMY, _monthLabelFromKey(competenceMY)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Competência (vencimento)",
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary(isDark),
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isExpanded: true,
            value: competenceItem.key,
            items: items
                .map((m) => DropdownMenuItem(
                      value: m.key,
                      child: Text(m.label, style: GoogleFonts.inter()),
                    ))
                .toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() => _competenceMonthYear = val);
              _applyLocalFilters();
            },
            buttonStyleData: ButtonStyleData(
              height: 48.h,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border(isDark)),
              ),
            ),
            dropdownStyleData: DropdownStyleData(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: AppColors.surface(isDark),
              ),
              maxHeight: 360.h,
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          "Recebidos por (gateway/método)",
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary(isDark),
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonHideUnderline(
          child: DropdownButton2<ReceivedFilter>(
            isExpanded: true,
            value: _receivedFilter,
            items: ReceivedFilter.values
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f.label, style: GoogleFonts.inter()),
                    ))
                .toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() => _receivedFilter = val);
              _applyLocalFilters();
            },
            buttonStyleData: ButtonStyleData(
              height: 48.h,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border(isDark)),
              ),
            ),
            dropdownStyleData: DropdownStyleData(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: AppColors.surface(isDark),
              ),
              maxHeight: 360.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFilters(bool isDark) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.magnifying_glass,
                  color: AppColors.primaryBlue, size: 18.sp),
              SizedBox(width: 10.w),
              Text(
                "Busca rápida",
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: () {
                    _clearFilters();
                  },
                  icon: Icon(PhosphorIcons.trash,
                      size: 16.sp, color: AppColors.errorRed),
                  label: Text(
                    "Limpar",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: AppColors.errorRed,
                    ),
                  ),
                )
            ],
          ),
          SizedBox(height: 10.h),
          _buildSearchInput("Buscar Aluno", _searchNameController, isDark),
          SizedBox(height: 10.h),
          _buildSearchInput("Buscar Tutor", _searchTutorController, isDark),
          SizedBox(height: 10.h),
          _buildClassFilter(isDark),
        ],
      ),
    );
  }

  Widget _buildMobileActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _fetchData,
          icon: Icon(PhosphorIcons.arrows_clockwise,
              size: 18.sp, color: AppColors.primaryBlue),
          label: Text(
            "Atualizar",
            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            side: const BorderSide(color: AppColors.primaryBlue),
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
          ),
        ),
        SizedBox(height: 10.h),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _showCompensationScreen = true);
          },
          icon: Icon(PhosphorIcons.arrows_counter_clockwise,
              size: 18.sp, color: Colors.white),
          label: Text(
            "Compensação",
            style: GoogleFonts.inter(fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warningOrange,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
          ),
        ),
        SizedBox(height: 10.h),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _showAutomationDashboard = true);
          },
          icon: Icon(PhosphorIcons.robot, size: 18.sp, color: Colors.white),
          label: Text(
            "Automação",
            style: GoogleFonts.inter(fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.automationPurple,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
          ),
        ),
        SizedBox(height: 10.h),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showNovaCobrancaPopup();
          },
          icon: Icon(PhosphorIcons.plus, size: 18.sp, color: Colors.white),
          label: Text(
            "Nova Cobrança",
            style: GoogleFonts.inter(fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoadingBackground = Provider.of<InvoiceProvider>(context).isLoading;

    final privacy = context.watch<PrivacyProvider>();
    debugPrint(
        '[Financeiro] build -> providerHash=${privacy.hashCode} hide=${privacy.hideFinancialValues} loaded=${privacy.isLoaded}');

    return ScreenUtilInit(
      // ✅ Mobile-first
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: AppColors.background(isDark),
          body: Stack(
            children: [
              if (_showAutomationDashboard)
                Container()
              else if (_showCompensationScreen)
                Container()
              else
                SafeArea(
                  child: Column(
                    children: [
                      _buildMobileHeader(isDark, privacy),
                      if ((isLoadingBackground &&
                              _filteredInvoices.isNotEmpty) ||
                          (_isSyncing && _filteredInvoices.isNotEmpty))
                        const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchData,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      16.w, 14.h, 16.w, 12.h),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildKPIsMobile(isDark, privacy),
                                      SizedBox(height: 12.h),
                                      _buildReceivedTimelineMobile(
                                          isDark, privacy),
                                      SizedBox(height: 12.h),
                                      _buildTabBarMobile(isDark),
                                      SizedBox(height: 8.h),
                                    ],
                                  ),
                                ),
                              ),
                              SliverFillRemaining(
                                child: Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 12.w),
                                  child: _buildListBodyMobile(isDark, privacy),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_showFeedback)
                ActionStatusPopup(
                  title: _feedbackTitle,
                  message: _feedbackMessage,
                  isError: _isFeedbackError,
                  onAnimationFinished: () =>
                      setState(() => _showFeedback = false),
                ),
            ],
          ),
          floatingActionButton:
              !_showAutomationDashboard && !_showCompensationScreen
                  ? FloatingActionButton.extended(
                      onPressed: _showNovaCobrancaPopup,
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      icon: const Icon(PhosphorIcons.plus),
                      label: Text(
                        "Cobrança",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                      ),
                    )
                  : null,
        );
      },
    );
  }

  // ============================
  // MOBILE HEADER (compacto, focado)
  // ============================
  Widget _buildMobileHeader(bool isDark, PrivacyProvider privacy) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(bottom: BorderSide(color: AppColors.border(isDark))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Gestão Financeira",
                  style: GoogleFonts.sairaCondensed(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(isDark),
                    fontSize: 24.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  "Boletos, recebidos e inadimplência",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(isDark),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: privacy.hideFinancialValues
                ? "Valores privados"
                : "Valores visíveis",
            onPressed: () =>
                context.read<PrivacyProvider>().toggleHideFinancialValues(),
            icon: Icon(
              privacy.hideFinancialValues
                  ? PhosphorIcons.eye_slash
                  : PhosphorIcons.eye,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          IconButton(
            tooltip: "Filtros e ações",
            onPressed: _openFiltersSheet,
            icon: Icon(
              PhosphorIcons.funnel_simple,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ============================
  // KPI MOBILE (horizontal)
  // ============================
  Widget _buildKPIsMobile(bool isDark, PrivacyProvider privacy) {
    final competenceMY =
        _competenceMonthYear ?? _formatMonthYear(DateTime.now());
    final cashMY = _cashMonthYear ?? _formatMonthYear(DateTime.now());

    final competenceLabel = _monthLabelFromKey(competenceMY);

    final cashAll = cashMY == _allMonthsKey;
    final cashLabel =
        cashAll ? _allMonthsItem.label : _monthLabelFromKey(cashMY);

    final cards = <Widget>[
      _kpiCardCompact(
        title: "A RECEBER",
        value: _kpiTotals['pending']!,
        color: AppColors.warningOrange,
        icon: PhosphorIcons.clock_afternoon_fill,
        isDark: isDark,
        subtitle: "Ref: $competenceLabel",
        privacy: privacy,
        privacyId: _kpiId('pending'),
      ),
      _kpiCardCompact(
        title: "RECEBIDO",
        value: _kpiTotals['paid']!,
        color: AppColors.primaryGreen,
        icon: PhosphorIcons.check_circle_fill,
        isDark: isDark,
        subtitle: "Caixa: $cashLabel",
        privacy: privacy,
        privacyId: _kpiId('paid'),
      ),
      _kpiCardCompact(
        title: "CANCELADO",
        value: _kpiTotals['canceled']!,
        color: Colors.grey,
        icon: PhosphorIcons.x_circle_fill,
        isDark: isDark,
        subtitle: "Ref: $competenceLabel",
        privacy: privacy,
        privacyId: _kpiId('canceled'),
      ),
      _kpiCardCompact(
        title: "REGISTROS",
        value: _filteredInvoices.length.toDouble(),
        color: AppColors.primaryBlue,
        icon: PhosphorIcons.list_numbers_fill,
        isDark: isDark,
        isCurrency: false,
        subtitle: _tabController.index == 3
            ? (_paidCompetenceFilterKey != null ? "Caixa + Ref" : "Caixa")
            : "Competência",
        privacy: privacy,
        privacyId: _kpiId('records'),
      ),
    ];

    return SizedBox(
      height: 112.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  Widget _kpiCardCompact({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    required bool isDark,
    required PrivacyProvider privacy,
    required String privacyId,
    bool isCurrency = true,
    String? subtitle,
  }) {
    final displayValue = isCurrency
        ? intl.NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
            .format(value)
        : value.toInt().toString();

    final hidden = isCurrency ? privacy.isHiddenFor(privacyId) : false;

    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: (privacy.hideFinancialValues && isCurrency)
          ? () => context.read<PrivacyProvider>().toggleRevealCard(privacyId)
          : null,
      child: Container(
        width: 255.w,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  if (isCurrency)
                    SensitiveValueText(
                      hidden: privacy.hideFinancialValues ? hidden : false,
                      valueText: displayValue,
                      style: GoogleFonts.sairaCondensed(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(isDark),
                      ),
                    )
                  else
                    Text(
                      displayValue,
                      style: GoogleFonts.sairaCondensed(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  if (subtitle != null) ...[
                    SizedBox(height: 3.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // TIMELINE MOBILE (compacta)
  // ============================
  Widget _buildReceivedTimelineMobile(bool isDark, PrivacyProvider privacy) {
    final months = _monthItems;
    if (months.isEmpty) return const SizedBox.shrink();

    final cashMY = _cashMonthYear ?? _formatMonthYear(DateTime.now());
    final cashAll = cashMY == _allMonthsKey;

    final selectedLabel =
        cashAll ? _allMonthsItem.label : _monthLabelFromKey(cashMY);

    final selectedTotal = cashAll
        ? _receivedTimelineTotals.values.fold<double>(0.0, (a, b) => a + b)
        : (_receivedTimelineTotals[cashMY] ?? 0.0);

    final paidCompetenceLabel = _paidCompetenceFilterKey == null
        ? null
        : _monthLabelFromKey(_paidCompetenceFilterKey!);

    final totalId = _timelineTotalId(cashMY);
    final totalHidden = privacy.isHiddenFor(totalId);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chart_line_up,
                  color: AppColors.primaryGreen, size: 18.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  "Recebidos (Caixa)",
                  style: GoogleFonts.sairaCondensed(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.25)),
                ),
                child: InkWell(
                  onTap: privacy.hideFinancialValues
                      ? () => context
                          .read<PrivacyProvider>()
                          .toggleRevealCard(totalId)
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedLabel,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 11.sp,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      SensitiveValueText(
                        hidden:
                            privacy.hideFinancialValues ? totalHidden : false,
                        valueText: intl.NumberFormat.currency(
                                locale: 'pt_BR', symbol: 'R\$')
                            .format(selectedTotal),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 11.sp,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: months.map((m) {
                final selected = !cashAll && cashMY == m.key;
                final total = _receivedTimelineTotals[m.key] ?? 0.0;

                final chipId = _timelineChipId(m.key);
                final hidden = privacy.isHiddenFor(chipId);

                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _cashMonthYear = m.key;
                        _paidCompetenceFilterKey = null;
                      });
                      if (_tabController.index != 3) {
                        _tabController.animateTo(3);
                      }
                      _applyLocalFilters();
                    },
                    onLongPress: privacy.hideFinancialValues
                        ? () => context
                            .read<PrivacyProvider>()
                            .toggleRevealCard(chipId)
                        : null,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryGreen
                                .withOpacity(isDark ? 0.22 : 0.12)
                            : (isDark ? Colors.black26 : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryGreen
                              : AppColors.border(isDark),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.label,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 11.sp,
                              color: selected
                                  ? AppColors.primaryGreen
                                  : AppColors.textPrimary(isDark),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          SensitiveValueText(
                            hidden:
                                privacy.hideFinancialValues ? hidden : false,
                            valueText: intl.NumberFormat.currency(
                                    locale: 'pt_BR', symbol: 'R\$')
                                .format(total),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.sp,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (paidCompetenceLabel != null) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(PhosphorIcons.funnel,
                    size: 16.sp, color: AppColors.warningOrange),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    "PAGOS filtrados por referência: $paidCompetenceLabel",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.sp,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _clearPaidCompetenceFilter,
                  child: Icon(PhosphorIcons.x_circle_fill,
                      size: 18.sp, color: AppColors.warningOrange),
                )
              ],
            ),
          ],
          SizedBox(height: 12.h),
          if (_receivedBreakdownByCompetence.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _receivedBreakdownByCompetence.entries.map((e) {
                  final compKey = e.key;
                  final value = e.value;

                  final label = _monthLabelFromKey(compKey);
                  final isSelectedComp = _paidCompetenceFilterKey != null &&
                      _paidCompetenceFilterKey == compKey;

                  final bdId = _breakdownChipId(compKey, cashMY);
                  final hidden = privacy.isHiddenFor(bdId);

                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_tabController.index != 3) {
                            _tabController.animateTo(3);
                          }
                          _paidCompetenceFilterKey = compKey;
                        });
                        _applyLocalFilters();
                      },
                      onLongPress: privacy.hideFinancialValues
                          ? () => context
                              .read<PrivacyProvider>()
                              .toggleRevealCard(bdId)
                          : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(isDark
                              ? (isSelectedComp ? 0.22 : 0.14)
                              : (isSelectedComp ? 0.14 : 0.08)),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelectedComp
                                ? AppColors.primaryBlue
                                : AppColors.primaryBlue.withOpacity(0.25),
                            width: isSelectedComp ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 11.sp,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            SensitiveValueText(
                              hidden:
                                  privacy.hideFinancialValues ? hidden : false,
                              valueText: intl.NumberFormat.currency(
                                      locale: 'pt_BR', symbol: 'R\$')
                                  .format(value),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 11.sp,
                                color: AppColors.textPrimary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Text(
              "Sem pagamentos para o filtro atual.",
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: AppColors.textSecondary(isDark),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  // ============================
  // TAB BAR MOBILE
  // ============================
  Widget _buildTabBarMobile(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: AppColors.textSecondary(isDark),
        labelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12.sp),
        indicatorColor: AppColors.primaryBlue,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: "TODOS"),
          Tab(text: "PENDENTES"),
          Tab(text: "VENCIDOS"),
          Tab(text: "PAGOS"),
          Tab(text: "CANCELADOS"),
        ],
      ),
    );
  }

  // ============================
  // LIST BODY MOBILE (card/expansion)
  // ============================
  Widget _buildListBodyMobile(bool isDark, PrivacyProvider privacy) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);

    if (invoiceProvider.isLoading &&
        _filteredInvoices.isEmpty &&
        invoiceProvider.allInvoices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredInvoices.isEmpty) {
      final hint = _tabController.index == 3
          ? (_paidCompetenceFilterKey != null
              ? "Você está vendo PAGOS filtrados por CAIXA + REFERÊNCIA."
              : "Na aba PAGOS, o mês vem do CAIXA (linha do tempo).")
          : "Nas abas abertas/vencidas, o mês vem da COMPETÊNCIA (vencimento).";

      return Center(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.magnifying_glass,
                  size: 54.sp,
                  color: AppColors.textSecondary(isDark).withOpacity(0.5)),
              SizedBox(height: 12.h),
              Text(
                "Nenhum registro encontrado.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 16.sp, color: AppColors.textSecondary(isDark)),
              ),
              SizedBox(height: 8.h),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(isDark),
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 14.h),
              OutlinedButton.icon(
                onPressed: _openFiltersSheet,
                icon: Icon(PhosphorIcons.funnel_simple,
                    size: 18.sp, color: AppColors.primaryBlue),
                label: Text(
                  "Abrir filtros",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final studentIds = _groupedInvoices.keys.toList();

    return ListView.separated(
      padding: EdgeInsets.only(bottom: 90.h),
      itemCount: studentIds.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final studentId = studentIds[index];
        final invoices = _groupedInvoices[studentId]!;
        final formattedIndex =
            (studentIds.length - index).toString().padLeft(2, '0');

        return _StudentGroupCardMobile(
          key: ValueKey(studentId),
          indexText: formattedIndex,
          invoices: invoices,
          isDark: isDark,
          privacy: privacy,
          studentTotalPrivacyId: _studentTotalId(studentId),
          invoiceValueIdBuilder: (id) => _invoiceValueId(id),
          onInvoiceTap: _showCobrancaDetails,
          onNegotiate: () => _showNegotiation(context, invoices),
          onWhatsappTap: _handleWhatsApp,
        );
      },
    );
  }

  // --- componentes reutilizados abaixo ---

  Widget _buildSearchInput(
      String hint, TextEditingController controller, bool isDark) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: AppColors.textPrimary(isDark)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary(isDark)),
        prefixIcon: Icon(PhosphorIcons.magnifying_glass,
            color: AppColors.textSecondary(isDark)),
        filled: true,
        fillColor: isDark ? Colors.black26 : Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
      ),
    );
  }

  Widget _buildClassFilter(bool isDark) {
    return Consumer<ClassProvider>(builder: (context, provider, _) {
      final classes = List<ClassModel>.from(provider.classes)
        ..sort((a, b) => a.name.compareTo(b.name));
      return DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          hint: Text('Filtrar por Turma',
              style: GoogleFonts.inter(color: AppColors.textSecondary(isDark))),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                "Todas as Turmas",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            ...classes.map((c) => DropdownMenuItem(
                value: c.id,
                child: Text("${c.name} (${c.schoolYear})",
                    style: GoogleFonts.inter()))),
          ],
          value: _selectedClassId,
          onChanged: (val) {
            setState(() => _selectedClassId = val);
            _applyLocalFilters();
          },
          buttonStyleData: ButtonStyleData(
            height: 52.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[100],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border(isDark)),
            ),
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: AppColors.surface(isDark),
            ),
            maxHeight: 340.h,
          ),
        ),
      );
    });
  }
}

// ============================
// Widgets auxiliares PRIVACY
// ============================
class SensitiveValueText extends StatelessWidget {
  final String valueText;
  final TextStyle style;
  final bool hidden;

  const SensitiveValueText({
    super.key,
    required this.valueText,
    required this.style,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Text(
        hidden ? "R\$ •••••" : valueText,
        key: ValueKey(hidden),
        style: style,
      ),
    );
  }
}

// ============================
// Student Group (MOBILE)
// ============================
class _StudentGroupCardMobile extends StatelessWidget {
  final List<Invoice> invoices;
  final bool isDark;
  final String indexText;

  final Function(Invoice) onInvoiceTap;
  final VoidCallback onNegotiate;
  final Function(Invoice) onWhatsappTap;

  final PrivacyProvider privacy;
  final String studentTotalPrivacyId;
  final String Function(String invoiceId) invoiceValueIdBuilder;

  const _StudentGroupCardMobile({
    super.key,
    required this.invoices,
    required this.isDark,
    required this.indexText,
    required this.onInvoiceTap,
    required this.onNegotiate,
    required this.onWhatsappTap,
    required this.privacy,
    required this.studentTotalPrivacyId,
    required this.invoiceValueIdBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const SizedBox.shrink();

    final first = invoices.first;
    final total = invoices.fold(0.0, (sum, i) => sum + i.value) / 100.0;

    final pendingCount = invoices
        .where((i) => i.status == 'pending' || _isOverdue(i.status, i.dueDate))
        .length;

    final hiddenTotal = privacy.isHiddenFor(studentTotalPrivacyId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          childrenPadding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
            child: Text(
              (first.student?.fullName.substring(0, 1).toUpperCase() ?? "?"),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  first.student?.fullName ?? "Desconhecido",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(isDark),
                    fontSize: 14.sp,
                  ),
                ),
              ),
              Text(
                indexText,
                style: GoogleFonts.sairaCondensed(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                  color: AppColors.textSecondary(isDark).withOpacity(0.6),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4.h),
              Text(
                "Resp: ${first.tutor?.fullName ?? '-'}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  if (pendingCount > 0)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.warningOrange.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.warningOrange.withOpacity(0.55)),
                      ),
                      child: Text(
                        "$pendingCount abertos",
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: AppColors.warningOrange,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.35)),
                      ),
                      child: Text(
                        "ok",
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(10.r),
                    onTap: privacy.hideFinancialValues
                        ? () => context
                            .read<PrivacyProvider>()
                            .toggleRevealCard(studentTotalPrivacyId)
                        : null,
                    child: SensitiveValueText(
                      hidden: privacy.hideFinancialValues ? hiddenTotal : false,
                      valueText: intl.NumberFormat.currency(
                              locale: 'pt_BR', symbol: 'R\$')
                          .format(total),
                      style: GoogleFonts.sairaCondensed(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            ...invoices.map((inv) => Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: _InvoiceCardMobile(
                    invoice: inv,
                    isDark: isDark,
                    privacy: privacy,
                    privacyValueId: invoiceValueIdBuilder(inv.id),
                    onTap: () => onInvoiceTap(inv),
                    onWhatsappTap: onWhatsappTap,
                  ),
                )),
            if (pendingCount > 0) ...[
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNegotiate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warningOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  icon: Icon(PhosphorIcons.handshake, size: 18.sp),
                  label: Text(
                    "Negociar pendências",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================
// Invoice (MOBILE card)
// ============================
class _InvoiceCardMobile extends StatelessWidget {
  final Invoice invoice;
  final bool isDark;
  final VoidCallback onTap;
  final Function(Invoice) onWhatsappTap;

  final PrivacyProvider privacy;
  final String privacyValueId;

  const _InvoiceCardMobile({
    required this.invoice,
    required this.isDark,
    required this.onTap,
    required this.onWhatsappTap,
    required this.privacy,
    required this.privacyValueId,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = _isOverdue(invoice.status, invoice.dueDate);
    final canSendWhatsapp =
        (invoice.status == 'pending' || overdue) && !invoice.isCompensationHold;
    final isPaid = invoice.status == 'paid';
    final paymentDate = invoice.effectivePaidAt;

    final hidden = privacy.isHiddenFor(privacyValueId);

    final headerColor = overdue
        ? AppColors.errorRed
        : isPaid
            ? AppColors.primaryGreen
            : AppColors.primaryBlue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: overdue
              ? AppColors.errorRed.withOpacity(0.05)
              : (isDark ? Colors.black12 : Colors.white),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha 1: descrição + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    invoice.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary(isDark),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                _StatusBadge(status: invoice.status, dueDate: invoice.dueDate),
              ],
            ),
            SizedBox(height: 8.h),

            // Linha 2: badges (gateway/ref)
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _GatewayBadge(
                    gateway: invoice.gateway,
                    method: invoice.paymentMethod,
                    isDark: isDark),
                _RefBadge(
                  dueDate: invoice.dueDate,
                  paidAt: paymentDate,
                  isDark: isDark,
                ),
              ],
            ),

            SizedBox(height: 10.h),

            // Linha 3: data + valor + whatsapp
            Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(isDark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: headerColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPaid
                            ? PhosphorIcons.check_circle_fill
                            : PhosphorIcons.calendar_blank,
                        size: 16.sp,
                        color: headerColor,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        isPaid
                            ? (paymentDate != null
                                ? "Pago ${intl.DateFormat('dd/MM/yyyy').format(paymentDate)}"
                                : "Pago (sem data)")
                            : "Vence ${intl.DateFormat('dd/MM/yyyy').format(invoice.dueDate)}",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.sp,
                          color: headerColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(10.r),
                  onTap: privacy.hideFinancialValues
                      ? () => context
                          .read<PrivacyProvider>()
                          .toggleRevealCard(privacyValueId)
                      : null,
                  child: SensitiveValueText(
                    hidden: privacy.hideFinancialValues ? hidden : false,
                    valueText: intl.NumberFormat.currency(
                            locale: 'pt_BR', symbol: 'R\$')
                        .format(invoice.value / 100),
                    style: GoogleFonts.sairaCondensed(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
                if (canSendWhatsapp) ...[
                  SizedBox(width: 10.w),
                  IconButton(
                    onPressed: () => onWhatsappTap(invoice),
                    tooltip: "Enviar Boleto/Pix via WhatsApp",
                    icon: Icon(
                      PhosphorIcons.whatsapp_logo_fill,
                      color: AppColors.whatsappGreen,
                      size: 22.sp,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GatewayBadge extends StatelessWidget {
  final String? gateway;
  final String? method;
  final bool isDark;

  const _GatewayBadge(
      {required this.gateway, required this.method, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    final gw = gateway?.toLowerCase() ?? '';
    final pm = method?.toLowerCase() ?? '';

    if (gw == 'cora') {
      bgColor = AppColors.coraPink.withOpacity(0.10);
      textColor = AppColors.coraPink;
      text = pm == 'pix' ? "Cora (Pix)" : "Cora (Boleto)";
      icon = pm == 'pix' ? PhosphorIcons.qr_code : PhosphorIcons.barcode;
    } else if (gw == 'mercadopago') {
      bgColor = AppColors.mpBlue.withOpacity(0.10);
      textColor = AppColors.mpBlue;
      text = pm == 'pix' ? "MP (Pix)" : "MP (Boleto)";
      icon = pm == 'pix' ? PhosphorIcons.qr_code : PhosphorIcons.barcode;
    } else {
      bgColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
      textColor = isDark ? Colors.grey[300]! : Colors.grey[700]!;
      text = "Manual";
      icon = PhosphorIcons.money;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: textColor.withOpacity(isDark ? 0.25 : 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: textColor),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefBadge extends StatelessWidget {
  final DateTime dueDate;
  final DateTime? paidAt;
  final bool isDark;

  const _RefBadge(
      {required this.dueDate, required this.paidAt, required this.isDark});

  String _formatMY(DateTime d) => intl.DateFormat('MM/yyyy').format(d);

  String _monthLabel(String my) {
    final parts = my.split('/');
    final d = DateTime(int.parse(parts[1]), int.parse(parts[0]), 1);
    final raw = intl.DateFormat('MMM/yyyy', 'pt_BR').format(d);
    return raw.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final refKey = _formatMY(dueDate);
    final refLabel = _monthLabel(refKey);

    String? paidLabel;
    if (paidAt != null) {
      paidLabel = _monthLabel(_formatMY(paidAt!));
    }

    final isRemanescente = paidLabel != null && paidLabel != refLabel;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.30)),
          ),
          child: Text(
            "REF $refLabel",
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        if (isRemanescente) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.warningOrange.withOpacity(isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(10.r),
              border:
                  Border.all(color: AppColors.warningOrange.withOpacity(0.30)),
            ),
            child: Text(
              "ENTROU $paidLabel",
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.warningOrange,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final DateTime dueDate;

  const _StatusBadge({required this.status, required this.dueDate});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    if (status == 'paid') {
      color = AppColors.primaryGreen;
      label = "PAGO";
    } else if (status == 'canceled') {
      color = Colors.grey;
      label = "CANCELADO";
    } else if (_isOverdue(status, dueDate)) {
      color = AppColors.errorRed;
      label = "VENCIDO";
    } else {
      color = AppColors.primaryBlue;
      label = "ABERTO";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

/// ✅ CORREÇÃO IMPORTANTE:
bool _isOverdue(String status, DateTime dueDate) {
  if (status == 'overdue') return true;

  final today =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  return status == 'pending' && dueDate.isBefore(today);
}

// ============================
// BatchPrintDialog (mantido)
// ============================
class BatchPrintDialog extends StatefulWidget {
  final List<Invoice> invoices;
  final Function(List<String> selectedIds) onConfirm;

  final PrivacyProvider privacy;
  final String Function(String invoiceId) valueIdBuilder;

  const BatchPrintDialog({
    super.key,
    required this.invoices,
    required this.onConfirm,
    required this.privacy,
    required this.valueIdBuilder,
  });

  @override
  State<BatchPrintDialog> createState() => _BatchPrintDialogState();
}

class _BatchPrintDialogState extends State<BatchPrintDialog> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    for (var inv in widget.invoices) {
      if (inv.status == 'pending' || _isOverdue(inv.status, inv.dueDate)) {
        _selectedIds.add(inv.id);
      }
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedInvoices = List<Invoice>.from(widget.invoices)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return AlertDialog(
      backgroundColor: AppColors.surface(isDark),
      title: Text(
        "Gerar Carnê de Pagamento",
        style: GoogleFonts.sairaCondensed(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary(isDark),
        ),
      ),
      content: SizedBox(
        width: 400.w,
        height: 420.h,
        child: Column(
          children: [
            Text(
              "Selecione as faturas para gerar um único PDF:",
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: sortedInvoices.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.border(isDark)),
                itemBuilder: (context, index) {
                  final invoice = sortedInvoices[index];
                  final isSelected = _selectedIds.contains(invoice.id);
                  final isOverdueItem =
                      _isOverdue(invoice.status, invoice.dueDate);
                  final isPaid = invoice.status == 'paid';
                  final isCanceled = invoice.status == 'canceled';
                  final isEnabled = !isCanceled;

                  final id = widget.valueIdBuilder(invoice.id);
                  final hidden = widget.privacy.isHiddenFor(id);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: isEnabled ? (val) => _toggle(invoice.id) : null,
                    activeColor: AppColors.primaryBlue,
                    title: Text(
                      intl.DateFormat('dd/MM/yyyy').format(invoice.dueDate),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isOverdueItem
                            ? AppColors.errorRed
                            : isPaid
                                ? AppColors.primaryGreen
                                : isEnabled
                                    ? AppColors.textPrimary(isDark)
                                    : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      "${invoice.description} (${isPaid ? 'Pago' : isCanceled ? 'Cancelado' : 'Aberto'})",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    secondary: InkWell(
                      borderRadius: BorderRadius.circular(8.r),
                      onTap: widget.privacy.hideFinancialValues
                          ? () => context
                              .read<PrivacyProvider>()
                              .toggleRevealCard(id)
                          : null,
                      child: SensitiveValueText(
                        hidden:
                            widget.privacy.hideFinancialValues ? hidden : false,
                        valueText: intl.NumberFormat.currency(
                                locale: 'pt_BR', symbol: 'R\$')
                            .format(invoice.value / 100),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar",
              style: TextStyle(color: AppColors.textSecondary(isDark))),
        ),
        ElevatedButton.icon(
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  widget.onConfirm(_selectedIds.toList());
                  Navigator.pop(context);
                },
          style:
              ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          icon:
              const Icon(PhosphorIcons.printer, size: 18, color: Colors.white),
          label: const Text("Gerar PDF Unificado",
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
