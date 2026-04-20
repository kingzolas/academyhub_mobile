import 'package:academyhub_mobile/model/guardian_auth_model.dart';
import 'package:academyhub_mobile/model/guardian_official_document_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/guardian_official_documents_provider.dart';
import 'package:academyhub_mobile/services/official_document_mobile_file_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GuardianDocumentsScreen extends StatefulWidget {
  final GuardianLinkedStudent? selectedStudent;
  final double topPadding;
  final double bottomPadding;
  final String? focusRequestId;
  final String? focusDocumentId;
  final int focusNonce;

  const GuardianDocumentsScreen({
    super.key,
    required this.selectedStudent,
    this.topPadding = 84,
    this.bottomPadding = 128,
    this.focusRequestId,
    this.focusDocumentId,
    this.focusNonce = 0,
  });

  @override
  State<GuardianDocumentsScreen> createState() =>
      _GuardianDocumentsScreenState();
}

class _GuardianDocumentsScreenState extends State<GuardianDocumentsScreen> {
  final OfficialDocumentMobileFileService _fileService =
      OfficialDocumentMobileFileService();
  final Set<String> _expandedRequestIds = {};
  final Set<String> _expandedCatalogTypes = {};
  bool _requestsSectionExpanded = true;

  @override
  void initState() {
    super.initState();
    _applyFocusExpansion();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocuments());
  }

  @override
  void didUpdateWidget(covariant GuardianDocumentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStudent?.id != widget.selectedStudent?.id) {
      _expandedRequestIds.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocuments());
    }
    if (oldWidget.focusNonce != widget.focusNonce ||
        oldWidget.focusRequestId != widget.focusRequestId ||
        oldWidget.focusDocumentId != widget.focusDocumentId) {
      _applyFocusExpansion();
    }
  }

  void _applyFocusExpansion() {
    var requestId = (widget.focusRequestId ?? '').trim();
    final documentId = (widget.focusDocumentId ?? '').trim();
    if (requestId.isEmpty && documentId.isNotEmpty) {
      final documents = context.read<GuardianOfficialDocumentsProvider>();
      for (final document in documents.documents) {
        if (document.id == documentId && document.requestId.trim().isNotEmpty) {
          requestId = document.requestId.trim();
          break;
        }
      }
    }
    if (requestId.isNotEmpty) {
      _requestsSectionExpanded = true;
      _expandedRequestIds.add(requestId);
    }
  }

  Future<void> _loadDocuments({bool silent = false}) async {
    final student = widget.selectedStudent;
    final documents = context.read<GuardianOfficialDocumentsProvider>();
    final token = context.read<AuthProvider>().token;

    if (student == null) {
      documents.clear();
      return;
    }

    if (token == null || token.trim().isEmpty) {
      return;
    }

    await documents.load(
      token: token,
      studentId: student.id,
      silent: silent,
    );
  }

  Future<void> _showRequestSheet(
    GuardianOfficialDocumentCatalogItem item,
  ) async {
    final student = widget.selectedStudent;
    final token = context.read<AuthProvider>().token;

    if (student == null) {
      _showFeedback('Selecione um aluno para solicitar documentações.');
      return;
    }

    if (token == null || token.trim().isEmpty) {
      _showFeedback('Sua sessão expirou. Entre novamente para continuar.');
      return;
    }

    final purposeController = TextEditingController(text: item.purpose);
    final notesController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _documentsSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) {
        return Consumer<GuardianOfficialDocumentsProvider>(
          builder: (context, provider, _) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.w,
                  right: 20.w,
                  top: 14.h,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20.h,
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
                            color: _documentsBorder(context),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      _DocumentTypeBadge(item: item),
                      SizedBox(height: 14.h),
                      Text(
                        'Solicitar ${item.title.toLowerCase()}',
                        style: GoogleFonts.inter(
                          color: _documentsTextPrimary(context),
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Conte rapidamente para a escola por que você precisa deste documento. Isso ajuda a secretaria a analisar e preparar o PDF correto.',
                        style: GoogleFonts.inter(
                          color: _documentsTextSecondary(context),
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: 18.h),
                      _RequestTextField(
                        label: 'Finalidade do documento',
                        controller: purposeController,
                        minLines: 3,
                        maxLines: 4,
                      ),
                      SizedBox(height: 12.h),
                      _RequestTextField(
                        label: 'Observações para a escola (opcional)',
                        controller: notesController,
                        minLines: 2,
                        maxLines: 3,
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: _documentsSoftSurface(context),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(color: _documentsBorder(context)),
                        ),
                        child: Text(
                          'Depois do envio, o pedido aparece em “Minhas solicitações” com o andamento atualizado pela escola.',
                          style: GoogleFonts.inter(
                            color: _documentsTextSecondary(context),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: provider.isSubmitting
                              ? null
                              : () async {
                                  final purpose = purposeController.text.trim();
                                  if (purpose.isEmpty) {
                                    _showFeedback(
                                      'Informe a finalidade do documento.',
                                    );
                                    return;
                                  }

                                  HapticFeedback.selectionClick();
                                  final success = await provider.createRequest(
                                    token: token,
                                    studentId: student.id,
                                    documentType: item.type,
                                    purpose: purpose,
                                    notes: notesController.text,
                                  );

                                  if (!mounted) return;
                                  if (success) {
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    _showFeedback(
                                      'Solicitação enviada para a escola.',
                                    );
                                  } else if (provider.error != null) {
                                    _showFeedback(provider.error!);
                                  }
                                },
                          icon: provider.isSubmitting
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(PhosphorIcons.paper_plane_tilt_fill,
                                  size: 17.sp),
                          label: Text(
                            provider.isSubmitting
                                ? 'Enviando...'
                                : 'Enviar solicitação',
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF00A859),
                            foregroundColor: Colors.white,
                            minimumSize: Size.fromHeight(48.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
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
  }

  Future<void> _openDocument(GuardianOfficialDocument document) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) {
      _showFeedback('Sua sessão expirou. Entre novamente para baixar.');
      return;
    }

    final provider = context.read<GuardianOfficialDocumentsProvider>();
    final Uint8List? bytes = await provider.downloadDocument(
      token: token,
      document: document,
    );

    if (!mounted) return;
    if (bytes == null) {
      _showFeedback(provider.error ?? 'Não foi possível abrir o documento.');
      return;
    }

    final result = await _fileService.openPdf(
      bytes: bytes,
      fileName: _documentFileName(document),
      mimeType: document.mimeType,
    );
    if (!mounted) return;
    if (!result.success) {
      _showFeedback(result.message);
    }

    await _loadDocuments(silent: true);
  }

  String _documentFileName(GuardianOfficialDocument document) {
    return document.fileName.trim().isEmpty
        ? '${guardianOfficialDocumentTitle(document.documentType)}.pdf'
        : document.fileName;
  }

  Future<void> _shareDocument(GuardianOfficialDocument document) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) {
      _showFeedback('Sua sessão expirou. Entre novamente para baixar.');
      return;
    }

    final provider = context.read<GuardianOfficialDocumentsProvider>();
    final Uint8List? bytes = await provider.downloadDocument(
      token: token,
      document: document,
    );

    if (!mounted) return;
    if (bytes == null) {
      _showFeedback(provider.error ?? 'Não foi possível baixar o documento.');
      return;
    }

    final result = await _fileService.shareOrSavePdf(
      bytes: bytes,
      fileName: _documentFileName(document),
      mimeType: document.mimeType,
    );
    if (!mounted) return;
    _showFeedback(result.message);
    await _loadDocuments(silent: true);
  }

  GuardianOfficialDocument? _documentForRequest(
    GuardianOfficialDocumentRequest request,
    List<GuardianOfficialDocument> documents,
  ) {
    final byRequestId = documents.where((document) {
      return document.requestId.trim().isNotEmpty &&
          document.requestId == request.id;
    }).toList();
    if (byRequestId.isNotEmpty) return byRequestId.first;

    final compatible = documents.where((document) {
      return document.documentType == request.documentType &&
          (request.status ==
                  GuardianOfficialDocumentRequestStatuses.published ||
              request.status ==
                  GuardianOfficialDocumentRequestStatuses.downloaded ||
              document.isPublished);
    }).toList();
    return compatible.isEmpty ? null : compatible.first;
  }

  void _toggleRequest(String requestId) {
    setState(() {
      if (_expandedRequestIds.contains(requestId)) {
        _expandedRequestIds.remove(requestId);
      } else {
        _expandedRequestIds.add(requestId);
      }
    });
  }

  void _toggleCatalogItem(String type) {
    setState(() {
      if (_expandedCatalogTypes.contains(type)) {
        _expandedCatalogTypes.remove(type);
      } else {
        _expandedCatalogTypes.add(type);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final student = widget.selectedStudent;

    return Consumer<GuardianOfficialDocumentsProvider>(
      builder: (context, provider, _) {
        final isInitialLoading =
            provider.isLoading && provider.requests.isEmpty;

        return RefreshIndicator(
          color: const Color(0xFF00A859),
          onRefresh: () => _loadDocuments(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20.w,
              widget.topPadding.h,
              20.w,
              widget.bottomPadding.h,
            ),
            children: [
              _DocumentsHero(student: student),
              SizedBox(height: 16.h),
              if (student == null)
                const _DocumentsEmptyState(
                  title: 'Nenhum aluno selecionado',
                  message:
                      'Quando houver um aluno vinculado a este acesso, as solicitações e documentos oficiais aparecerão aqui.',
                )
              else ...[
                if (provider.error != null &&
                    provider.requests.isEmpty &&
                    provider.documents.isEmpty)
                  _DocumentsErrorState(
                    message: provider.error!,
                    onRetry: () => _loadDocuments(),
                  ),
                if (isInitialLoading) ...[
                  const _DocumentsLoadingCard(
                    label: 'Carregando documentações oficiais...',
                  ),
                  SizedBox(height: 12.h),
                ],
                if (provider.activeRequests.isNotEmpty) ...[
                  _CollapsibleSectionHeader(
                    title: 'Minhas solicitações',
                    subtitle:
                        'Seu pedido em andamento fica no topo para acompanhar sem rolar a tela inteira.',
                    count: provider.activeRequests.length,
                    isExpanded: _requestsSectionExpanded,
                    onTap: () => setState(
                      () =>
                          _requestsSectionExpanded = !_requestsSectionExpanded,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  if (_requestsSectionExpanded)
                    ...provider.activeRequests.map(
                      (request) {
                        final document =
                            _documentForRequest(request, provider.documents);
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _CompactDocumentRequestCard(
                            request: request,
                            document: document,
                            isExpanded:
                                _expandedRequestIds.contains(request.id),
                            isDownloading:
                                provider.downloadingDocumentId == document?.id,
                            onToggle: () => _toggleRequest(request.id),
                            onOpenDocument: document == null
                                ? null
                                : () => _openDocument(document),
                            onShareDocument: document == null
                                ? null
                                : () => _shareDocument(document),
                          ),
                        );
                      },
                    )
                  else
                    _CollapsedSectionSummary(
                      icon: PhosphorIcons.path_fill,
                      label:
                          '${provider.activeRequests.length} solicitação${provider.activeRequests.length == 1 ? '' : 'es'} em andamento',
                      helper: 'Toque para ver timeline, detalhes e ações.',
                    ),
                  SizedBox(height: 16.h),
                ],
                _DocumentsSectionHeader(
                  title: 'Catálogo de documentos',
                  subtitle:
                      'Cards compactos: toque em um documento para ver quando usar e solicitar.',
                  trailing: provider.isRefreshing
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00A859),
                          ),
                        )
                      : null,
                ),
                SizedBox(height: 10.h),
                ...provider.catalog.map(
                  (item) {
                    final alreadyRequested = provider.activeRequests.any(
                      (request) => request.documentType == item.type,
                    );
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: _CompactDocumentCatalogCard(
                        item: item,
                        alreadyRequested: alreadyRequested,
                        isExpanded: _expandedCatalogTypes.contains(item.type),
                        onToggle: () => _toggleCatalogItem(item.type),
                        onRequest: () {
                          if (alreadyRequested) {
                            _showFeedback(
                              'Este documento já possui uma solicitação em andamento.',
                            );
                            return;
                          }
                          _showRequestSheet(item);
                        },
                      ),
                    );
                  },
                ),
                if (provider.activeRequests.isEmpty) ...[
                  SizedBox(height: 10.h),
                  _CollapsibleSectionHeader(
                    title: 'Minhas solicitações',
                    subtitle:
                        'Acompanhe cada etapa, da análise até a liberação.',
                    count: provider.requests.length,
                    isExpanded: _requestsSectionExpanded,
                    onTap: () => setState(
                      () =>
                          _requestsSectionExpanded = !_requestsSectionExpanded,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  if (!_requestsSectionExpanded)
                    _CollapsedSectionSummary(
                      icon: PhosphorIcons.files_fill,
                      label: provider.requests.isEmpty
                          ? 'Nenhum pedido enviado'
                          : '${provider.requests.length} protocolo${provider.requests.length == 1 ? '' : 's'} no histórico',
                      helper: 'Toque para expandir a seção.',
                    )
                  else if (provider.requests.isEmpty && !provider.isLoading)
                    const _DocumentsEmptyState(
                      title: 'Nenhuma solicitação enviada',
                      message:
                          'Solicite um documento no catálogo acima. Assim que a escola receber, o andamento aparecerá aqui.',
                    )
                  else
                    ...provider.requests.map(
                      (request) {
                        final document =
                            _documentForRequest(request, provider.documents);
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _CompactDocumentRequestCard(
                            request: request,
                            document: document,
                            isExpanded:
                                _expandedRequestIds.contains(request.id),
                            isDownloading:
                                provider.downloadingDocumentId == document?.id,
                            onToggle: () => _toggleRequest(request.id),
                            onOpenDocument: document == null
                                ? null
                                : () => _openDocument(document),
                            onShareDocument: document == null
                                ? null
                                : () => _shareDocument(document),
                          ),
                        );
                      },
                    ),
                ],
                SizedBox(height: 10.h),
                const _DocumentsSectionHeader(
                  title: 'Documentos prontos',
                  subtitle: 'PDFs oficiais assinados e publicados pela escola.',
                ),
                SizedBox(height: 10.h),
                if (provider.documents.isEmpty && !provider.isLoading)
                  const _DocumentsEmptyState(
                    title: 'Nenhum documento disponível',
                    message:
                        'Quando a escola publicar um PDF assinado, ele ficará disponível para abrir ou baixar aqui.',
                  )
                else
                  ...provider.documents.map(
                    (document) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: _PublishedDocumentCard(
                        document: document,
                        isDownloading:
                            provider.downloadingDocumentId == document.id,
                        onOpen: () => _openDocument(document),
                        onShare: () => _shareDocument(document),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DocumentsHero extends StatelessWidget {
  final GuardianLinkedStudent? student;

  const _DocumentsHero({required this.student});

  @override
  Widget build(BuildContext context) {
    final firstName = student?.firstName.trim();

    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkContext(context)
              ? const [Color(0xFF0F3D2A), Color(0xFF0F2442)]
              : const [Color(0xFFE7F8EF), Color(0xFFEAF2FF)],
        ),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: _isDarkContext(context)
              ? const Color(0xFF1F6B4A)
              : const Color(0xFFD7F0E2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: const Color(0xFF00A859),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A859).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              PhosphorIcons.files_fill,
              color: Colors.white,
              size: 23.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Documentações',
            style: TextStyle(
              color: _documentsTextPrimary(context),
              fontSize: 28.sp,
              fontFamily: 'GR Milesons Three',
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            firstName == null || firstName.isEmpty
                ? 'Solicite documentos escolares, acompanhe a análise da escola e acesse o PDF oficial quando estiver assinado.'
                : 'Solicite documentos de $firstName, acompanhe a análise da escola e acesse o PDF oficial quando estiver assinado.',
            style: GoogleFonts.inter(
              color: _documentsTextSecondary(context),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          SizedBox(height: 16.h),
          const Row(
            children: [
              Expanded(
                child: _HeroStepChip(
                  label: 'Solicitar',
                  icon: PhosphorIcons.paper_plane_tilt_fill,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HeroStepChip(
                  label: 'Acompanhar',
                  icon: PhosphorIcons.path_fill,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HeroStepChip(
                  label: 'Baixar',
                  icon: PhosphorIcons.download_simple_fill,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStepChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeroStepChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: _documentsSurface(context).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: _documentsBorder(context)),
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
                color: _documentsTextPrimary(context),
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

class _DocumentsSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _DocumentsSectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _documentsTextPrimary(context),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: _documentsTextSecondary(context),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: 12.w),
          trailing!,
        ],
      ],
    );
  }
}

class _CollapsibleSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  const _CollapsibleSectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: _documentsSurface(context),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: _documentsBorder(context)),
        ),
        child: Row(
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
                            color: _documentsTextPrimary(context),
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _SmallPill(
                        label: '$count',
                        color: const Color(0xFF00A859),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: _documentsTextSecondary(context),
                      fontSize: 11.8.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                PhosphorIcons.caret_down_bold,
                color: _documentsTextSecondary(context),
                size: 17.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedSectionSummary extends StatelessWidget {
  final IconData icon;
  final String label;
  final String helper;

  const _CollapsedSectionSummary({
    required this.icon,
    required this.label,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: _documentsSoftSurface(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _documentsBorder(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00A859), size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _documentsTextPrimary(context),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  helper,
                  style: GoogleFonts.inter(
                    color: _documentsTextSecondary(context),
                    fontSize: 11.2.sp,
                    fontWeight: FontWeight.w500,
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

class _CompactDocumentCatalogCard extends StatelessWidget {
  final GuardianOfficialDocumentCatalogItem item;
  final bool alreadyRequested;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onRequest;

  const _CompactDocumentCatalogCard({
    required this.item,
    required this.alreadyRequested,
    required this.isExpanded,
    required this.onToggle,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final color = _documentTypeColor(item.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(24.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: _documentsSurface(context),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              if (!_isDarkContext(context))
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DocumentIconBox(type: item.type, color: color),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  color: _documentsTextPrimary(context),
                                  fontSize: 15.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (item.isRecommended)
                              _SmallPill(label: 'Mais pedido', color: color),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          item.purpose,
                          maxLines: isExpanded ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _documentsTextPrimary(context),
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      PhosphorIcons.caret_down_bold,
                      color: _documentsTextSecondary(context),
                      size: 16.sp,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Text(
                    'Toque para entender quando usar e solicitar.',
                    style: GoogleFonts.inter(
                      color: _documentsTextSecondary(context),
                      fontSize: 11.3.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 12.h),
                    _ContextHint(
                      icon: PhosphorIcons.lightbulb_fill,
                      title: 'Quando usar',
                      text: item.usedWhen,
                      color: color,
                    ),
                    SizedBox(height: 8.h),
                    _ContextHint(
                      icon: PhosphorIcons.check_circle_fill,
                      title: 'O que a escola faz',
                      text: item.schoolExpectation,
                      color: const Color(0xFF00A859),
                    ),
                    SizedBox(height: 14.h),
                    SizedBox(
                      width: double.infinity,
                      child: alreadyRequested
                          ? OutlinedButton.icon(
                              onPressed: onRequest,
                              icon: Icon(
                                PhosphorIcons.clock_counter_clockwise,
                                size: 16.sp,
                              ),
                              label: const Text('Solicitação em andamento'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: color,
                                side: BorderSide(
                                  color: color.withValues(alpha: 0.45),
                                ),
                                minimumSize: Size.fromHeight(44.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.r),
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: onRequest,
                              icon: Icon(
                                PhosphorIcons.paper_plane_tilt_fill,
                                size: 16.sp,
                              ),
                              label: const Text('Solicitar este documento'),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                minimumSize: Size.fromHeight(44.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.r),
                                ),
                              ),
                            ),
                    ),
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

// ignore: unused_element
class _LegacyDocumentCatalogCard extends StatelessWidget {
  final GuardianOfficialDocumentCatalogItem item;
  final bool alreadyRequested;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onRequest;

  const _LegacyDocumentCatalogCard({
    required this.item,
    required this.alreadyRequested,
    required this.isExpanded,
    required this.onToggle,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final color = _documentTypeColor(item.type);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _documentsSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          if (!_isDarkContext(context))
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocumentIconBox(type: item.type, color: color),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.inter(
                              color: _documentsTextPrimary(context),
                              fontSize: 15.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (item.isRecommended)
                          _SmallPill(label: 'Mais pedido', color: color),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      item.purpose,
                      style: GoogleFonts.inter(
                        color: _documentsTextPrimary(context),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _ContextHint(
            icon: PhosphorIcons.lightbulb_fill,
            title: 'Quando usar',
            text: item.usedWhen,
            color: color,
          ),
          SizedBox(height: 8.h),
          _ContextHint(
            icon: PhosphorIcons.check_circle_fill,
            title: 'O que a escola faz',
            text: item.schoolExpectation,
            color: const Color(0xFF00A859),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: alreadyRequested
                ? OutlinedButton.icon(
                    onPressed: onRequest,
                    icon: Icon(PhosphorIcons.clock_counter_clockwise,
                        size: 16.sp),
                    label: const Text('Solicitação em andamento'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withValues(alpha: 0.45)),
                      minimumSize: Size.fromHeight(44.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onRequest,
                    icon:
                        Icon(PhosphorIcons.paper_plane_tilt_fill, size: 16.sp),
                    label: const Text('Solicitar este documento'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      minimumSize: Size.fromHeight(44.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompactDocumentRequestCard extends StatelessWidget {
  final GuardianOfficialDocumentRequest request;
  final GuardianOfficialDocument? document;
  final bool isExpanded;
  final bool isDownloading;
  final VoidCallback onToggle;
  final VoidCallback? onOpenDocument;
  final VoidCallback? onShareDocument;

  const _CompactDocumentRequestCard({
    required this.request,
    required this.document,
    required this.isExpanded,
    required this.isDownloading,
    required this.onToggle,
    required this.onOpenDocument,
    required this.onShareDocument,
  });

  @override
  Widget build(BuildContext context) {
    final color = request.isRejected || request.isCancelled
        ? const Color(0xFFEF4444)
        : _documentTypeColor(request.documentType);
    final hasDocumentActions = document != null && document!.isPublished;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(24.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: _documentsSurface(context),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DocumentIconBox(type: request.documentType, color: color),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guardianOfficialDocumentTitle(request.documentType),
                          style: GoogleFonts.inter(
                            color: _documentsTextPrimary(context),
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          _requestSubtitle(request),
                          style: GoogleFonts.inter(
                            color: _documentsTextSecondary(context),
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SmallPill(
                        label: guardianOfficialDocumentRequestStatusLabel(
                          request.status,
                        ),
                        color: hasDocumentActions
                            ? const Color(0xFF00A859)
                            : color,
                      ),
                      SizedBox(height: 8.h),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          PhosphorIcons.caret_down_bold,
                          color: _documentsTextSecondary(context),
                          size: 16.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                _requestContextLine(request, document),
                maxLines: isExpanded ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _documentsTextSecondary(context),
                  fontSize: 11.8.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              AnimatedCrossFade(
                firstChild: hasDocumentActions
                    ? Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: _InlineDocumentActions(
                          document: document!,
                          isDownloading: isDownloading,
                          onOpen: onOpenDocument,
                          onShare: onShareDocument,
                        ),
                      )
                    : const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (request.purpose.trim().isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      Text(
                        request.purpose,
                        style: GoogleFonts.inter(
                          color: _documentsTextSecondary(context),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (request.rejectionReason.trim().isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _ContextHint(
                        icon: PhosphorIcons.warning_circle_fill,
                        title: 'Orientação da escola',
                        text: request.rejectionReason,
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                    if (hasDocumentActions) ...[
                      SizedBox(height: 12.h),
                      _InlineDocumentActions(
                        document: document!,
                        isDownloading: isDownloading,
                        onOpen: onOpenDocument,
                        onShare: onShareDocument,
                      ),
                    ],
                    SizedBox(height: 14.h),
                    _DocumentRequestTimeline(request: request, color: color),
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

class _InlineDocumentActions extends StatelessWidget {
  final GuardianOfficialDocument document;
  final bool isDownloading;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;

  const _InlineDocumentActions({
    required this.document,
    required this.isDownloading,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFF00A859).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFF00A859).withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.check_circle_fill,
                color: const Color(0xFF00A859),
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Documento oficial disponível',
                  style: GoogleFonts.inter(
                    color: _documentsTextPrimary(context),
                    fontSize: 12.2.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isDownloading ? null : onOpen,
                  icon: isDownloading
                      ? SizedBox(
                          width: 15.w,
                          height: 15.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(PhosphorIcons.file_pdf_fill, size: 15.sp),
                  label: Text(isDownloading ? 'Abrindo...' : 'Abrir'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF00A859),
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(40.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDownloading ? null : onShare,
                  icon: Icon(PhosphorIcons.share_network_fill, size: 15.sp),
                  label: const Text('Baixar / compartilhar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00A859),
                    side: BorderSide(
                      color: const Color(0xFF00A859).withValues(alpha: 0.36),
                    ),
                    minimumSize: Size.fromHeight(40.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LegacyDocumentRequestCard extends StatelessWidget {
  final GuardianOfficialDocumentRequest request;

  const _LegacyDocumentRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final color = request.isRejected || request.isCancelled
        ? const Color(0xFFEF4444)
        : _documentTypeColor(request.documentType);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _documentsSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocumentIconBox(type: request.documentType, color: color),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guardianOfficialDocumentTitle(request.documentType),
                      style: GoogleFonts.inter(
                        color: _documentsTextPrimary(context),
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      _requestSubtitle(request),
                      style: GoogleFonts.inter(
                        color: _documentsTextSecondary(context),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallPill(
                label: guardianOfficialDocumentRequestStatusLabel(
                  request.status,
                ),
                color: color,
              ),
            ],
          ),
          if (request.purpose.trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              request.purpose,
              style: GoogleFonts.inter(
                color: _documentsTextSecondary(context),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
          if (request.rejectionReason.trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            _ContextHint(
              icon: PhosphorIcons.warning_circle_fill,
              title: 'Orientação da escola',
              text: request.rejectionReason,
              color: const Color(0xFFEF4444),
            ),
          ],
          SizedBox(height: 14.h),
          _DocumentRequestTimeline(request: request, color: color),
        ],
      ),
    );
  }
}

class _DocumentRequestTimeline extends StatelessWidget {
  final GuardianOfficialDocumentRequest request;
  final Color color;

  const _DocumentRequestTimeline({
    required this.request,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final steps = request.isRejected
        ? const [
            _TimelineStepData('Solicitação enviada', 'Pedido recebido'),
            _TimelineStepData('Recusada', 'A escola informou o motivo'),
          ]
        : request.isCancelled
            ? const [
                _TimelineStepData('Solicitação enviada', 'Pedido recebido'),
                _TimelineStepData('Cancelada', 'Pedido encerrado'),
              ]
            : const [
                _TimelineStepData('Solicitação enviada', 'Pedido recebido'),
                _TimelineStepData('Em análise', 'Secretaria conferindo'),
                _TimelineStepData('Aprovada', 'Pedido aceito'),
                _TimelineStepData('Em preparação', 'PDF sendo preparado'),
                _TimelineStepData(
                    'Aguardando assinatura', 'Assinatura da escola'),
                _TimelineStepData('Assinada', 'Documento oficial assinado'),
                _TimelineStepData('Disponível', 'Pronto para baixar'),
                _TimelineStepData('Baixada', 'Download registrado'),
              ];

    final currentIndex =
        request.isRejected || request.isCancelled ? 1 : request.progressIndex;

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineStep(
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

class _TimelineStep extends StatelessWidget {
  final _TimelineStepData data;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;
  final Color color;

  const _TimelineStep({
    required this.data,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final stepColor =
        isCompleted || isCurrent ? color : _documentsBorder(context);
    final textColor = isCompleted || isCurrent
        ? _documentsTextPrimary(context)
        : _documentsTextSecondary(context);

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
                    : _documentsSoftSurface(context),
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
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  data.description,
                  style: GoogleFonts.inter(
                    color: _documentsTextSecondary(context),
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

class _PublishedDocumentCard extends StatelessWidget {
  final GuardianOfficialDocument document;
  final bool isDownloading;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  const _PublishedDocumentCard({
    required this.document,
    required this.isDownloading,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final color = _documentTypeColor(document.documentType);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _documentsSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border:
            Border.all(color: const Color(0xFF00A859).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocumentIconBox(type: document.documentType, color: color),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guardianOfficialDocumentTitle(document.documentType),
                      style: GoogleFonts.inter(
                        color: _documentsTextPrimary(context),
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      _publishedSubtitle(document),
                      style: GoogleFonts.inter(
                        color: _documentsTextSecondary(context),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallPill(
                label: guardianOfficialDocumentStatusLabel(document.status),
                color: const Color(0xFF00A859),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: const Color(0xFF00A859).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.check_circle_fill,
                  color: const Color(0xFF00A859),
                  size: 18.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Documento oficial assinado e publicado pela escola.',
                    style: GoogleFonts.inter(
                      color: _documentsTextPrimary(context),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isDownloading ? null : onOpen,
                  icon: isDownloading
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(PhosphorIcons.file_pdf_fill, size: 16.sp),
                  label: Text(isDownloading ? 'Abrindo...' : 'Abrir'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF00A859),
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(44.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDownloading ? null : onShare,
                  icon: Icon(PhosphorIcons.share_network_fill, size: 16.sp),
                  label: const Text('Baixar / compartilhar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(44.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _ContextHint({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkContext(context) ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16.sp),
          SizedBox(width: 9.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  color: _documentsTextSecondary(context),
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(
                      color: _documentsTextPrimary(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentIconBox extends StatelessWidget {
  final String type;
  final Color color;

  const _DocumentIconBox({
    required this.type,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.w,
      height: 42.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Icon(_documentTypeIcon(type), color: color, size: 21.sp),
    );
  }
}

class _DocumentTypeBadge extends StatelessWidget {
  final GuardianOfficialDocumentCatalogItem item;

  const _DocumentTypeBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _documentTypeColor(item.type);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_documentTypeIcon(item.type), color: color, size: 15.sp),
          SizedBox(width: 7.w),
          Text(
            item.title,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RequestTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;

  const _RequestTextField({
    required this.label,
    required this.controller,
    required this.minLines,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: TextInputAction.newline,
      style: GoogleFonts.inter(
        color: _documentsTextPrimary(context),
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: _documentsTextSecondary(context),
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: _documentsSoftSurface(context),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: _documentsBorder(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFF00A859), width: 1.4),
        ),
      ),
    );
  }
}

class _DocumentsLoadingCard extends StatelessWidget {
  final String label;

  const _DocumentsLoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: _documentsSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _documentsBorder(context)),
      ),
      child: Row(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF00A859),
            strokeWidth: 2.4,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: _documentsTextSecondary(context),
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _DocumentsEmptyState({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: _documentsSurface(context),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _documentsBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.folder_open_fill,
            color: const Color(0xFF00A859),
            size: 24.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            style: GoogleFonts.inter(
              color: _documentsTextPrimary(context),
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            message,
            style: GoogleFonts.inter(
              color: _documentsTextSecondary(context),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _DocumentsErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: _isDarkContext(context)
            ? const Color(0xFF321316)
            : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Não foi possível carregar agora',
            style: GoogleFonts.inter(
              color: const Color(0xFFEF4444),
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            message,
            style: GoogleFonts.inter(
              color: _documentsTextPrimary(context),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: Icon(PhosphorIcons.arrow_clockwise, size: 15.sp),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _TimelineStepData {
  final String title;
  final String description;

  const _TimelineStepData(this.title, this.description);
}

bool _isDarkContext(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _documentsSurface(BuildContext context) => Theme.of(context).cardColor;

Color _documentsSoftSurface(BuildContext context) =>
    _isDarkContext(context) ? const Color(0xFF121A23) : const Color(0xFFF8FAFC);

Color _documentsBorder(BuildContext context) =>
    _isDarkContext(context) ? const Color(0xFF223042) : const Color(0xFFE5E7EB);

Color _documentsTextPrimary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color _documentsTextSecondary(BuildContext context) =>
    _isDarkContext(context) ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

Color _documentTypeColor(String type) {
  switch (type) {
    case GuardianOfficialDocumentTypes.enrollmentDeclaration:
      return const Color(0xFF00A859);
    case GuardianOfficialDocumentTypes.attendanceDeclaration:
      return const Color(0xFF2F80ED);
    case GuardianOfficialDocumentTypes.noDebtDeclaration:
      return const Color(0xFF0F766E);
    case GuardianOfficialDocumentTypes.transferDeclaration:
      return const Color(0xFFF59E0B);
    case GuardianOfficialDocumentTypes.incomeTaxDeclaration:
      return const Color(0xFF7C3AED);
    case GuardianOfficialDocumentTypes.paymentReceipt:
      return const Color(0xFF16A34A);
    case GuardianOfficialDocumentTypes.schoolTranscript:
      return const Color(0xFFDB2777);
    default:
      return const Color(0xFF64748B);
  }
}

IconData _documentTypeIcon(String type) {
  switch (type) {
    case GuardianOfficialDocumentTypes.enrollmentDeclaration:
      return PhosphorIcons.student_fill;
    case GuardianOfficialDocumentTypes.attendanceDeclaration:
      return PhosphorIcons.check_circle_fill;
    case GuardianOfficialDocumentTypes.noDebtDeclaration:
      return PhosphorIcons.shield_check_fill;
    case GuardianOfficialDocumentTypes.transferDeclaration:
      return PhosphorIcons.arrows_left_right_fill;
    case GuardianOfficialDocumentTypes.incomeTaxDeclaration:
      return PhosphorIcons.calculator_fill;
    case GuardianOfficialDocumentTypes.paymentReceipt:
      return PhosphorIcons.receipt_fill;
    case GuardianOfficialDocumentTypes.schoolTranscript:
      return PhosphorIcons.scroll_fill;
    default:
      return PhosphorIcons.file_text_fill;
  }
}

String _requestSubtitle(GuardianOfficialDocumentRequest request) {
  final date = request.updatedAt ?? request.createdAt;
  if (date == null) return 'Acompanhe o andamento do pedido';
  return 'Atualizado em ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(date.toLocal())}';
}

String _requestContextLine(
  GuardianOfficialDocumentRequest request,
  GuardianOfficialDocument? document,
) {
  if (document != null && document.isPublished) {
    return 'O documento oficial assinado já está liberado para abrir, baixar ou compartilhar.';
  }
  if (request.rejectionReason.trim().isNotEmpty) {
    return 'A escola retornou uma orientação sobre este pedido.';
  }
  if (request.purpose.trim().isNotEmpty) {
    return request.purpose.trim();
  }

  switch (request.status) {
    case GuardianOfficialDocumentRequestStatuses.underReview:
      return 'A secretaria está conferindo as informações antes de aprovar.';
    case GuardianOfficialDocumentRequestStatuses.approved:
      return 'Pedido aprovado. A escola vai preparar o documento oficial.';
    case GuardianOfficialDocumentRequestStatuses.awaitingSignature:
      return 'Documento preparado e aguardando assinatura institucional.';
    case GuardianOfficialDocumentRequestStatuses.signed:
      return 'Documento assinado. Falta a escola liberar para download.';
    case GuardianOfficialDocumentRequestStatuses.published:
    case GuardianOfficialDocumentRequestStatuses.downloaded:
      return 'Documento oficial disponível para o responsável.';
    case GuardianOfficialDocumentRequestStatuses.cancelled:
      return 'Este pedido foi encerrado e não seguirá para emissão.';
    case GuardianOfficialDocumentRequestStatuses.rejected:
      return 'A escola recusou este pedido e informou a orientação no detalhe.';
    case GuardianOfficialDocumentRequestStatuses.requested:
    default:
      return 'Pedido enviado. Acompanhe aqui cada avanço da escola.';
  }
}

String _publishedSubtitle(GuardianOfficialDocument document) {
  final date = document.publishedAt ?? document.signedAt ?? document.createdAt;
  final version = document.version > 1 ? ' · versão ${document.version}' : '';
  if (date == null) return 'Documento oficial disponível$version';
  return 'Publicado em ${DateFormat('dd/MM/yyyy', 'pt_BR').format(date.toLocal())}$version';
}
