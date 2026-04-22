import 'dart:typed_data';

import 'package:academyhub_mobile/model/guardian_absence_justification_request_model.dart';
import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/guardian_absence_justification_request_service.dart';
import 'package:academyhub_mobile/services/guardian_auth_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GuardianAttendanceScreen extends StatefulWidget {
  final GuardianLinkedStudent student;
  final bool embedded;
  final double bottomPadding;
  final String? focusRequestId;
  final int focusNonce;
  final int realtimeRefreshNonce;

  const GuardianAttendanceScreen({
    super.key,
    required this.student,
    this.embedded = false,
    this.bottomPadding = 32,
    this.focusRequestId,
    this.focusNonce = 0,
    this.realtimeRefreshNonce = 0,
  });

  @override
  State<GuardianAttendanceScreen> createState() =>
      _GuardianAttendanceScreenState();
}

class _GuardianAttendanceScreenState extends State<GuardianAttendanceScreen> {
  final GuardianAuthService _service = GuardianAuthService();
  final GuardianAbsenceJustificationRequestService _requestService =
      GuardianAbsenceJustificationRequestService();

  GuardianAttendanceScreenData? _data;
  List<GuardianAbsenceJustificationRequest> _requests = [];
  bool _isLoading = true;
  bool _isRequestsLoading = false;
  bool _isSubmittingRequest = false;
  String? _error;
  String? _requestError;
  final Set<String> _expandedRequestIds = {};
  bool _requestsSectionExpanded = true;

  @override
  void initState() {
    super.initState();
    _applyFocusedRequest();
    _load();
  }

  @override
  void didUpdateWidget(covariant GuardianAttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id ||
        oldWidget.realtimeRefreshNonce != widget.realtimeRefreshNonce) {
      _load();
      return;
    }

    if (oldWidget.focusNonce != widget.focusNonce) {
      _applyFocusedRequest();
      setState(() {});
    }
  }

  void _applyFocusedRequest() {
    final requestId = (widget.focusRequestId ?? '').trim();
    if (requestId.isNotEmpty) {
      _requestsSectionExpanded = true;
      _expandedRequestIds.add(requestId);
    }
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;

    if (token == null || token.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _error =
            'Sua sessão expirou. Entre novamente para acompanhar a frequência.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isRequestsLoading = true;
      _error = null;
      _requestError = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _service.getGuardianAttendance(
          token: token,
          studentId: widget.student.id,
        ),
        _requestService.getRequests(
          token: token,
          studentId: widget.student.id,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _data = results[0] as GuardianAttendanceScreenData;
        _requests =
            (results[1] as List<GuardianAbsenceJustificationRequest>).toList();
        _isLoading = false;
        _isRequestsLoading = false;
        _requestError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isRequestsLoading = false;
      });
    }
  }

  Future<void> _loadRequestsOnly() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    setState(() {
      _isRequestsLoading = true;
      _requestError = null;
    });

    try {
      final result = await _requestService.getRequests(
        token: token,
        studentId: widget.student.id,
      );
      if (!mounted) return;
      setState(() {
        _requests = result;
        _isRequestsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requestError = e.toString().replaceFirst('Exception: ', '');
        _isRequestsLoading = false;
      });
    }
  }

  Future<void> _showRequestSheet({
    GuardianAbsenceJustificationRequest? complementFor,
  }) async {
    final notesController = TextEditingController();
    DateTimeRange? selectedRange = complementFor == null
        ? DateTimeRange(start: DateTime.now(), end: DateTime.now())
        : null;
    var selectedDocumentType = GuardianAbsenceDocumentTypes.medicalCertificate;
    PlatformFile? selectedFile;
    Uint8List? selectedFileBytes;
    var isSubmitting = false;
    String? localError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickRange() async {
              final now = DateTime.now();
              final result = await showDateRangePicker(
                context: context,
                initialDateRange: selectedRange,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 2),
                helpText: 'Período do abono',
                cancelText: 'Cancelar',
                confirmText: 'Selecionar',
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: const Color(0xFF00A859),
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (result != null) {
                setSheetState(() => selectedRange = result);
              }
            }

            Future<void> pickFile() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                withData: true,
              );
              final files = result?.files ?? const <PlatformFile>[];
              if (files.isEmpty) return;
              final file = files.first;

              setSheetState(() {
                selectedFile = file;
                selectedFileBytes = file.bytes;
                localError = null;
              });
            }

            Future<void> submit() async {
              final token = context.read<AuthProvider>().token;
              if (token == null || token.trim().isEmpty) {
                setSheetState(() => localError =
                    'Sua sessão expirou. Entre novamente para solicitar o abono.');
                return;
              }

              final notes = notesController.text.trim();
              if (complementFor == null && selectedRange == null) {
                setSheetState(
                    () => localError = 'Selecione o período do abono.');
                return;
              }
              if (GuardianAbsenceDocumentTypes.requiresAttachment(
                    selectedDocumentType,
                  ) &&
                  selectedFileBytes == null &&
                  complementFor == null) {
                setSheetState(
                  () => localError = 'Este tipo de documento exige anexo.',
                );
                return;
              }
              if (notes.isEmpty && selectedFileBytes == null) {
                setSheetState(
                  () => localError =
                      'Informe uma observação ou anexe um arquivo.',
                );
                return;
              }

              setSheetState(() {
                isSubmitting = true;
                localError = null;
              });
              setState(() => _isSubmittingRequest = true);

              try {
                if (complementFor == null) {
                  await _requestService.createRequest(
                    token: token,
                    studentId: widget.student.id,
                    requestedStartDate: selectedRange!.start,
                    requestedEndDate: selectedRange!.end,
                    documentType: selectedDocumentType,
                    notes: notes,
                    attachmentBytes: selectedFileBytes,
                    attachmentName: selectedFile?.name,
                    attachmentMimeType: _mimeFromExtension(selectedFile?.name),
                  );
                } else {
                  await _requestService.complementRequest(
                    token: token,
                    requestId: complementFor.id,
                    notes: notes,
                    attachmentBytes: selectedFileBytes,
                    attachmentName: selectedFile?.name,
                    attachmentMimeType: _mimeFromExtension(selectedFile?.name),
                  );
                }

                if (!mounted || !sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                await _loadRequestsOnly();
                _showFeedback(
                  complementFor == null
                      ? 'Solicitação enviada para análise da escola.'
                      : 'Complemento enviado para a escola.',
                );
              } catch (e) {
                setSheetState(() {
                  localError = e.toString().replaceFirst('Exception: ', '');
                  isSubmitting = false;
                });
              } finally {
                if (mounted) setState(() => _isSubmittingRequest = false);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20.w,
                  14.h,
                  20.w,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20.h,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44.w,
                          height: 5.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        complementFor == null
                            ? 'Solicitar abono'
                            : 'Enviar complemento',
                        style: GoogleFonts.inter(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        complementFor == null
                            ? 'A escola analisa o pedido antes de refletir na frequência.'
                            : 'Inclua a informação solicitada pela escola.',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                          height: 1.45,
                        ),
                      ),
                      if (complementFor == null) ...[
                        SizedBox(height: 16.h),
                        _GuardianRequestSheetButton(
                          icon: PhosphorIcons.calendar_blank_fill,
                          label: 'Período',
                          value: selectedRange == null
                              ? 'Selecionar período'
                              : '${_formatDate(selectedRange!.start)} até ${_formatDate(selectedRange!.end)}',
                          onTap: pickRange,
                        ),
                        SizedBox(height: 12.h),
                        DropdownButtonFormField<String>(
                          initialValue: selectedDocumentType,
                          decoration:
                              _sheetInputDecoration('Tipo do documento'),
                          items: GuardianAbsenceDocumentTypes.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    GuardianAbsenceDocumentTypes.label(type),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => selectedDocumentType = value);
                            }
                          },
                        ),
                      ],
                      SizedBox(height: 12.h),
                      TextField(
                        controller: notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: _sheetInputDecoration(
                          complementFor == null
                              ? 'Justificativa ou observação'
                              : 'Complemento',
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _GuardianRequestSheetButton(
                        icon: PhosphorIcons.paperclip_fill,
                        label: 'Anexo',
                        value: selectedFile?.name ?? 'PDF, JPG ou PNG',
                        onTap: pickFile,
                      ),
                      if (localError != null) ...[
                        SizedBox(height: 12.h),
                        Text(
                          localError!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEF4444),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      SizedBox(height: 18.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A859),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: Size.fromHeight(48.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: isSubmitting
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  complementFor == null
                                      ? 'Enviar solicitação'
                                      : 'Enviar complemento',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    notesController.dispose();
  }

  InputDecoration _sheetInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        fontSize: 12.sp,
        color: const Color(0xFF6B7280),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Color(0xFF00A859)),
      ),
    );
  }

  String? _mimeFromExtension(String? fileName) {
    final extension = (fileName ?? '').split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return null;
    }
  }

  Future<void> _cancelRequest(
    GuardianAbsenceJustificationRequest request,
  ) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    try {
      await _requestService.cancelRequest(
        token: token,
        requestId: request.id,
        reason: 'Cancelado pelo responsável no aplicativo.',
      );
      await _loadRequestsOnly();
      _showFeedback('Solicitação cancelada.');
    } catch (e) {
      _showFeedback(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sem data';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildRequestsSectionV2() {
    final openCount = _requests.where((request) => request.isOpen).length;
    final visibleRequests = _requests.toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? a.requestedStartDate ?? DateTime(1900);
        final bDate = b.createdAt ?? b.requestedStartDate ?? DateTime(1900);
        return bDate.compareTo(aDate);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuardianAttendanceSectionHeader(
          title: 'Minhas solicitações',
          subtitle: openCount == 0
              ? 'Acompanhe aqui os pedidos enviados para análise da escola.'
              : '$openCount solicitação${openCount == 1 ? '' : 'ões'} em andamento.',
          count: _requests.length,
          isExpanded: _requestsSectionExpanded,
          onTap: () {
            setState(
              () => _requestsSectionExpanded = !_requestsSectionExpanded,
            );
          },
          trailing: ElevatedButton.icon(
            onPressed: _isSubmittingRequest ? null : () => _showRequestSheet(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A859),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            icon: Icon(PhosphorIcons.plus_bold, size: 16.sp),
            label: Text(
              'Solicitar',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        AnimatedCrossFade(
          firstChild: _GuardianRequestsCollapsedSummary(
            count: _requests.length,
            openCount: openCount,
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isRequestsLoading)
                const _GuardianAttendanceEmpty(
                  title: 'Carregando solicitações',
                  message: 'Buscando os pedidos de abono vinculados ao aluno.',
                )
              else if (_requestError != null)
                _GuardianAttendanceEmpty(
                  title: 'Não foi possível carregar solicitações',
                  message: _requestError!,
                )
              else if (_requests.isEmpty)
                const _GuardianAttendanceEmpty(
                  title: 'Nenhuma solicitação enviada',
                  message:
                      'Quando houver atestado ou justificativa, toque em Solicitar para enviar à escola.',
                )
              else
                ...visibleRequests.map(
                  (request) {
                    final isExpanded = _expandedRequestIds.contains(request.id);
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: _GuardianAbsenceRequestCardV2(
                        request: request,
                        isExpanded: isExpanded,
                        highlighted: request.id == widget.focusRequestId,
                        onToggle: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedRequestIds.remove(request.id);
                            } else {
                              _expandedRequestIds.add(request.id);
                            }
                          });
                        },
                        onComplement: request.status ==
                                GuardianAbsenceJustificationRequestStatuses
                                    .needsInformation
                            ? () => _showRequestSheet(complementFor: request)
                            : null,
                        onCancel: request.isOpen
                            ? () => _cancelRequest(request)
                            : null,
                      ),
                    );
                  },
                ),
            ],
          ),
          crossFadeState: _requestsSectionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          sizeCurve: Curves.easeOut,
        ),
        SizedBox(height: 10.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                PhosphorIcons.info_fill,
                color: const Color(0xFF2F80ED),
                size: 18.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'A solicitação não altera a chamada automaticamente. A escola analisa o pedido e o abono só é aplicado quando existir uma falta real no período aprovado.',
                  style: GoogleFonts.inter(
                    fontSize: 11.8.sp,
                    color: const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                    height: 1.38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = _data?.selectedStudent ?? widget.student;
    final summary = _data?.attendance.summary;
    final records =
        _data?.attendance.recentRecords ?? const <GuardianAttendanceRecord>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: const Color(0xFF111827),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frequência',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    student.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A859)),
            )
          : _error != null
              ? _GuardianAttendanceError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: const Color(0xFF00A859),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20.w,
                      widget.embedded ? 84.h : 16.h,
                      20.w,
                      widget.bottomPadding.h,
                    ),
                    children: [
                      _GuardianAttendanceStudentCard(student: student),
                      SizedBox(height: 16.h),
                      _GuardianAttendanceHeroV2(
                        student: student,
                        summary: summary,
                        openRequestsCount:
                            _requests.where((request) => request.isOpen).length,
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _GuardianAttendanceMetric(
                              label: 'Presenças',
                              value: '${summary?.presentCount ?? 0}',
                              color: const Color(0xFF00A859),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _GuardianAttendanceMetric(
                              label: 'Faltas',
                              value: '${summary?.absentCount ?? 0}',
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _GuardianAttendanceMetric(
                              label: 'Recentes',
                              value: '${summary?.recentAbsences ?? 0}',
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      _buildRequestsSectionV2(),
                      SizedBox(height: 18.h),
                      Text(
                        'Histórico recente',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (records.isEmpty)
                        const _GuardianAttendanceEmpty(
                          title: 'Sem registros encontrados',
                          message:
                              'Os registros de frequência aparecerão aqui assim que forem lançados.',
                        )
                      else
                        ...records.map(
                          (record) => Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child:
                                _GuardianAttendanceRecordCard(record: record),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _GuardianAttendanceHeroV2 extends StatelessWidget {
  final GuardianLinkedStudent student;
  final GuardianAttendanceSummary? summary;
  final int openRequestsCount;

  const _GuardianAttendanceHeroV2({
    required this.student,
    required this.summary,
    required this.openRequestsCount,
  });

  @override
  Widget build(BuildContext context) {
    final rate = summary?.presenceRate ?? 0;
    final attention = summary?.attentionLevel == 'attention';
    final firstName = student.firstName.trim();

    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: attention
              ? const [Color(0xFFFFF7ED), Color(0xFFEFF6FF)]
              : const [Color(0xFFE7F8EF), Color(0xFFEAF2FF)],
        ),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: attention ? const Color(0xFFFED7AA) : const Color(0xFFD7F0E2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A859),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A859).withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  PhosphorIcons.calendar_check_fill,
                  color: Colors.white,
                  size: 23.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frequência',
                      style: TextStyle(
                        color: const Color(0xFF111827),
                        fontSize: 28.sp,
                        fontFamily: 'GR Milesons Three',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      firstName.isEmpty
                          ? 'Acompanhe presença, faltas e solicitações de abono analisadas pela escola.'
                          : 'Acompanhe a presença de $firstName, veja faltas recentes e solicite abono quando houver justificativa.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF4B5563),
                        fontSize: 12.8.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: _GuardianHeroMetric(
                  label: 'Presença',
                  value: '${rate.toStringAsFixed(1)}%',
                  color: attention
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF00A859),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _GuardianHeroMetric(
                  label: 'Pedidos abertos',
                  value: '$openRequestsCount',
                  color: const Color(0xFF2F80ED),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          const Row(
            children: [
              Expanded(
                child: _GuardianHeroStepChip(
                  label: 'Solicitar',
                  icon: PhosphorIcons.paper_plane_tilt_fill,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _GuardianHeroStepChip(
                  label: 'Acompanhar',
                  icon: PhosphorIcons.path_fill,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _GuardianHeroStepChip(
                  label: 'Análise',
                  icon: PhosphorIcons.magnifying_glass_fill,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuardianHeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GuardianHeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5.sp,
              color: const Color(0xFF4B5563),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianHeroStepChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _GuardianHeroStepChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF00A859), size: 14.sp),
          SizedBox(width: 5.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF111827),
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAttendanceSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget trailing;

  const _GuardianAttendanceSectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.isExpanded,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF111827),
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _GuardianAttendancePill(
                        label: '$count',
                        color: const Color(0xFF2F80ED),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280),
                      fontSize: 11.8.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              children: [
                trailing,
                SizedBox(height: 8.h),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    PhosphorIcons.caret_down_bold,
                    color: const Color(0xFF6B7280),
                    size: 16.sp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianRequestsCollapsedSummary extends StatelessWidget {
  final int count;
  final int openCount;

  const _GuardianRequestsCollapsedSummary({
    required this.count,
    required this.openCount,
  });

  @override
  Widget build(BuildContext context) {
    return _GuardianAttendanceEmpty(
      title: count == 0
          ? 'Nenhuma solicitação enviada'
          : '$count solicitação${count == 1 ? '' : 'ões'} no histórico',
      message: openCount == 0
          ? 'Toque para abrir a lista completa e ver o andamento.'
          : '$openCount pedido${openCount == 1 ? '' : 's'} aguardando análise ou complemento.',
    );
  }
}

class _GuardianAbsenceRequestCardV2 extends StatelessWidget {
  final GuardianAbsenceJustificationRequest request;
  final bool isExpanded;
  final bool highlighted;
  final VoidCallback onToggle;
  final VoidCallback? onComplement;
  final VoidCallback? onCancel;

  const _GuardianAbsenceRequestCardV2({
    required this.request,
    required this.isExpanded,
    required this.highlighted,
    required this.onToggle,
    this.onComplement,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _guardianRequestStatusColor(request.status);
    final period = _guardianRequestPeriod(request);
    final hasActions = onComplement != null || onCancel != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(24.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: highlighted ? accent : accent.withValues(alpha: 0.18),
              width: highlighted ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GuardianRequestIconBox(color: accent),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          GuardianAbsenceJustificationRequestStatuses.label(
                            request.status,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          period,
                          style: GoogleFonts.inter(
                            fontSize: 11.8.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _GuardianAttendancePill(
                        label: request.appliedAt != null
                            ? 'Aplicada'
                            : GuardianAbsenceDocumentTypes.label(
                                request.documentType,
                              ),
                        color: request.appliedAt != null
                            ? const Color(0xFF00A859)
                            : accent,
                      ),
                      SizedBox(height: 8.h),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          PhosphorIcons.caret_down_bold,
                          color: const Color(0xFF6B7280),
                          size: 16.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                _guardianRequestContextLine(request),
                maxLines: isExpanded ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF6B7280),
                  fontSize: 11.8.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 14.h),
                    _GuardianAbsenceRequestTimeline(
                      request: request,
                      color: accent,
                    ),
                    SizedBox(height: 14.h),
                    _GuardianAbsenceRequestInfoPanel(request: request),
                    if (request.decisionReason.trim().isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _GuardianRequestHint(
                        title: 'Orientação da escola',
                        text: request.decisionReason.trim(),
                        color: _guardianRequestStatusColor(request.status),
                        icon: PhosphorIcons.chat_circle_text_fill,
                      ),
                    ],
                    if (hasActions) ...[
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          if (onComplement != null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onComplement,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2F80ED),
                                  side: const BorderSide(
                                    color: Color(0xFFBFDBFE),
                                  ),
                                  minimumSize: Size.fromHeight(42.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                ),
                                child: const Text('Complementar'),
                              ),
                            ),
                          if (onComplement != null && onCancel != null)
                            SizedBox(width: 10.w),
                          if (onCancel != null)
                            Expanded(
                              child: TextButton(
                                onPressed: onCancel,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  minimumSize: Size.fromHeight(42.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
                firstCurve: Curves.easeOut,
                secondCurve: Curves.easeOut,
                sizeCurve: Curves.easeOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardianRequestIconBox extends StatelessWidget {
  final Color color;

  const _GuardianRequestIconBox({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Icon(
        PhosphorIcons.file_text_fill,
        color: color,
        size: 21.sp,
      ),
    );
  }
}

class _GuardianAbsenceRequestTimeline extends StatelessWidget {
  final GuardianAbsenceJustificationRequest request;
  final Color color;

  const _GuardianAbsenceRequestTimeline({
    required this.request,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _guardianTimelineSteps(request);
    final currentIndex = _guardianTimelineCurrentIndex(request);

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _GuardianTimelineStep(
            data: steps[index],
            isCompleted: index < currentIndex,
            isCurrent: index == currentIndex,
            isLast: index == steps.length - 1,
            color: color,
          ),
      ],
    );
  }
}

class _GuardianTimelineStep extends StatelessWidget {
  final _GuardianTimelineStepData data;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;
  final Color color;

  const _GuardianTimelineStep({
    required this.data,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final stepColor =
        isCompleted || isCurrent ? color : const Color(0xFFE5E7EB);
    final textColor = isCompleted || isCurrent
        ? const Color(0xFF111827)
        : const Color(0xFF6B7280);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? stepColor.withValues(alpha: 0.14)
                    : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: stepColor, width: 1.5),
              ),
              child: Icon(
                isCompleted
                    ? PhosphorIcons.check_bold
                    : isCurrent
                        ? PhosphorIcons.circle_fill
                        : PhosphorIcons.circle,
                color: stepColor,
                size: isCurrent ? 9.sp : 12.sp,
              ),
            ),
            if (!isLast)
              Container(
                width: 2.w,
                height: 22.h,
                color: stepColor.withValues(alpha: isCompleted ? 0.55 : 0.22),
              ),
          ],
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 12.5.sp,
                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  data.description,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF6B7280),
                    fontSize: 10.8.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuardianAbsenceRequestInfoPanel extends StatelessWidget {
  final GuardianAbsenceJustificationRequest request;

  const _GuardianAbsenceRequestInfoPanel({required this.request});

  @override
  Widget build(BuildContext context) {
    final approved = request.approvedDates
        .map((date) => DateFormat('dd/MM/yyyy').format(date))
        .join(', ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _GuardianRequestInfoRow(
            label: 'Tipo do documento',
            value: GuardianAbsenceDocumentTypes.label(request.documentType),
          ),
          _GuardianRequestInfoRow(
            label: 'Anexos',
            value: request.attachments.isEmpty
                ? 'Nenhum anexo'
                : '${request.attachments.length} arquivo${request.attachments.length == 1 ? '' : 's'} enviado${request.attachments.length == 1 ? '' : 's'}',
          ),
          _GuardianRequestInfoRow(
            label: 'Enviada em',
            value: _guardianDateTimeLabel(request.createdAt),
          ),
          if (approved.isNotEmpty)
            _GuardianRequestInfoRow(
              label: 'Dias aprovados',
              value: approved,
            ),
        ],
      ),
    );
  }
}

class _GuardianRequestInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _GuardianRequestInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11.2.sp,
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianRequestHint extends StatelessWidget {
  final String title;
  final String text;
  final Color color;
  final IconData icon;

  const _GuardianRequestHint({
    required this.title,
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 9.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 11.5.sp,
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianTimelineStepData {
  final String title;
  final String description;

  const _GuardianTimelineStepData(this.title, this.description);
}

Color _guardianRequestStatusColor(String status) {
  switch (status) {
    case GuardianAbsenceJustificationRequestStatuses.approved:
    case GuardianAbsenceJustificationRequestStatuses.partiallyApproved:
      return const Color(0xFF00A859);
    case GuardianAbsenceJustificationRequestStatuses.rejected:
    case GuardianAbsenceJustificationRequestStatuses.cancelled:
      return const Color(0xFFEF4444);
    case GuardianAbsenceJustificationRequestStatuses.needsInformation:
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF2F80ED);
  }
}

String _guardianRequestPeriod(GuardianAbsenceJustificationRequest request) {
  final start = _guardianDateLabel(request.requestedStartDate);
  final end = _guardianDateLabel(request.requestedEndDate);
  return start == end ? start : '$start até $end';
}

String _guardianRequestContextLine(
  GuardianAbsenceJustificationRequest request,
) {
  final status =
      GuardianAbsenceJustificationRequestStatuses.label(request.status);
  final attachments = request.attachments.isEmpty
      ? 'sem anexo'
      : '${request.attachments.length} anexo${request.attachments.length == 1 ? '' : 's'}';
  return '$status • ${GuardianAbsenceDocumentTypes.label(request.documentType)} • $attachments';
}

String _guardianDateLabel(DateTime? date) {
  if (date == null) return 'Sem data';
  return DateFormat('dd/MM/yyyy').format(date);
}

String _guardianDateTimeLabel(DateTime? date) {
  if (date == null) return 'Não informado';
  return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(date);
}

String _guardianStudentContextLine(GuardianLinkedStudent student) {
  final classInfo = student.classInfo;
  final parts = <String>[
    _guardianCleanDisplayText(student.relationship),
    if (classInfo != null) _guardianCleanDisplayText(classInfo.name),
    if (classInfo != null) _guardianCleanDisplayText(classInfo.shift),
  ].where((part) => part.isNotEmpty).toList();

  return parts.isEmpty ? 'Responsável' : parts.join(' • ');
}

String _guardianCleanDisplayText(String value) {
  var text = value.trim();
  if (text.isEmpty) return '';

  final replacementChar = String.fromCharCode(0xFFFD);
  final mojibakeReplacement =
      '${String.fromCharCode(0x00EF)}${String.fromCharCode(0x00BF)}${String.fromCharCode(0x00BD)}';

  text = text
      .replaceAll(mojibakeReplacement, '')
      .replaceAll(replacementChar, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  const labels = {
    'Responsavel': 'Responsável',
    'Responsavel Financeiro': 'Responsável Financeiro',
    'Responsavel financeiro': 'Responsável Financeiro',
    'Responsavel Pedagogico': 'Responsável Pedagógico',
    'Responsavel pedagogico': 'Responsável Pedagógico',
    'Responsavel Legal': 'Responsável Legal',
    'Responsavel legal': 'Responsável Legal',
  };

  return labels[text] ?? text;
}

List<_GuardianTimelineStepData> _guardianTimelineSteps(
  GuardianAbsenceJustificationRequest request,
) {
  switch (request.status) {
    case GuardianAbsenceJustificationRequestStatuses.rejected:
      return const [
        _GuardianTimelineStepData('Solicitação enviada', 'Pedido recebido'),
        _GuardianTimelineStepData('Recusada', 'A escola informou o motivo'),
      ];
    case GuardianAbsenceJustificationRequestStatuses.cancelled:
      return const [
        _GuardianTimelineStepData('Solicitação enviada', 'Pedido recebido'),
        _GuardianTimelineStepData('Cancelada', 'Pedido encerrado'),
      ];
    case GuardianAbsenceJustificationRequestStatuses.needsInformation:
      return const [
        _GuardianTimelineStepData('Solicitação enviada', 'Pedido recebido'),
        _GuardianTimelineStepData('Em análise', 'Escola conferindo'),
        _GuardianTimelineStepData(
          'Complemento solicitado',
          'Envie a informação pedida',
        ),
      ];
    default:
      return [
        const _GuardianTimelineStepData(
          'Solicitação enviada',
          'Pedido recebido pela escola',
        ),
        const _GuardianTimelineStepData(
          'Em análise',
          'Gestão conferindo período e documento',
        ),
        _GuardianTimelineStepData(
          request.status ==
                  GuardianAbsenceJustificationRequestStatuses.partiallyApproved
              ? 'Aprovada parcialmente'
              : 'Decisão da escola',
          request.status ==
                  GuardianAbsenceJustificationRequestStatuses.partiallyApproved
              ? 'Somente alguns dias foram aceitos'
              : 'Aguardando parecer da escola',
        ),
        _GuardianTimelineStepData(
          request.appliedAt == null
              ? 'Aplicação na frequência'
              : 'Aplicada na frequência',
          request.appliedAt == null
              ? 'O abono depende de existir falta real'
              : 'A frequência já recebeu o abono',
        ),
      ];
  }
}

int _guardianTimelineCurrentIndex(GuardianAbsenceJustificationRequest request) {
  switch (request.status) {
    case GuardianAbsenceJustificationRequestStatuses.rejected:
    case GuardianAbsenceJustificationRequestStatuses.cancelled:
      return 1;
    case GuardianAbsenceJustificationRequestStatuses.underReview:
      return 1;
    case GuardianAbsenceJustificationRequestStatuses.needsInformation:
      return 2;
    case GuardianAbsenceJustificationRequestStatuses.approved:
    case GuardianAbsenceJustificationRequestStatuses.partiallyApproved:
      return request.appliedAt == null ? 2 : 3;
    case GuardianAbsenceJustificationRequestStatuses.pending:
    default:
      return 0;
  }
}

class _GuardianRequestSheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _GuardianRequestSheetButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20.sp, color: const Color(0xFF00A859)),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianAttendanceRecordCard extends StatelessWidget {
  final GuardianAttendanceRecord record;

  const _GuardianAttendanceRecordCard({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final isAbsent = record.isAbsent;
    final accent = isAbsent ? const Color(0xFFEF4444) : const Color(0xFF00A859);
    final dateLabel = record.date != null
        ? DateFormat('dd/MM/yyyy').format(record.date!)
        : 'Sem data';

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              isAbsent
                  ? PhosphorIcons.x_circle_fill
                  : PhosphorIcons.check_circle_fill,
              color: accent,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.label,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  dateLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                if (record.observation.trim().isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    record.observation,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAttendanceMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GuardianAttendanceMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAttendanceStudentCard extends StatelessWidget {
  final GuardianLinkedStudent student;

  const _GuardianAttendanceStudentCard({
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7EF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              PhosphorIcons.student_fill,
              color: const Color(0xFF00A859),
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _guardianStudentContextLine(student),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAttendancePill extends StatelessWidget {
  final String label;
  final Color color;

  const _GuardianAttendancePill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _GuardianAttendanceEmpty extends StatelessWidget {
  final String title;
  final String message;

  const _GuardianAttendanceEmpty({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              PhosphorIcons.calendar_check_fill,
              size: 26.sp,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianAttendanceError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _GuardianAttendanceError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.warning_circle_fill,
              size: 42.sp,
              color: const Color(0xFFEF4444),
            ),
            SizedBox(height: 14.h),
            Text(
              'Não foi possível carregar os dados.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 18.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A859),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
