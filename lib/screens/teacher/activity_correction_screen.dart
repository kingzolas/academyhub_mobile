import 'package:academyhub_mobile/model/activity_correction_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/activity_correction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ActivityCorrectionScreen extends StatefulWidget {
  final ActivityQrResolveResult resolveResult;

  const ActivityCorrectionScreen({
    super.key,
    required this.resolveResult,
  });

  @override
  State<ActivityCorrectionScreen> createState() => _ActivityCorrectionScreenState();
}

class _ActivityCorrectionScreenState extends State<ActivityCorrectionScreen> {
  final ActivityCorrectionService _service = ActivityCorrectionService();
  final TextEditingController _generalObservationController =
      TextEditingController();
  final Map<String, TextEditingController> _noteControllers = {};
  final Map<String, String?> _selectedValues = {};

  bool _isSaving = false;
  String? _correctionId;
  bool _correctionExists = false;

  @override
  void initState() {
    super.initState();
    final correction = widget.resolveResult.correction;
    _correctionId = correction.id;
    _correctionExists = correction.exists;
    _generalObservationController.text = correction.generalObservation ?? '';

    for (final templateItem in widget.resolveResult.criteriaTemplate) {
      final existingCriterion = correction.criteria.cast<ActivityCorrectionCriterionValue?>().firstWhere(
            (item) => item?.key == templateItem.key,
            orElse: () => null,
          );
      _selectedValues[templateItem.key] = existingCriterion?.value;
      _noteControllers[templateItem.key] = TextEditingController(
        text: existingCriterion?.note ?? '',
      );
    }
  }

  @override
  void dispose() {
    _generalObservationController.dispose();
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _humanizeScaleValue(String value) {
    return value
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  List<ActivityCorrectionCriterionValue> _buildCriteriaPayload() {
    final payload = <ActivityCorrectionCriterionValue>[];

    for (final templateItem in widget.resolveResult.criteriaTemplate) {
      final selectedValue = (_selectedValues[templateItem.key] ?? '').trim();
      if (selectedValue.isEmpty) continue;

      payload.add(
        ActivityCorrectionCriterionValue(
          key: templateItem.key,
          label: templateItem.label,
          value: selectedValue,
          note: _noteControllers[templateItem.key]?.text.trim() ?? '',
        ),
      );
    }

    return payload;
  }

  String _mapErrorMessage(ActivityCorrectionException error) {
    switch (error.code) {
      case 'INVALID_ACTIVITY_QR':
        return 'Este QR Code de atividade e invalido.';
      case 'ACTIVITY_QR_NOT_FOUND':
        return 'A atividade impressa nao foi encontrada.';
      case 'ACTIVITY_QR_SCHOOL_MISMATCH':
        return 'Esta atividade pertence a outra escola.';
      case 'ACTIVITY_CORRECTION_FORBIDDEN':
        return 'Voce nao tem permissao para corrigir esta atividade.';
      case 'INVALID_ACTIVITY_CRITERIA':
      case 'INVALID_ACTIVITY_CRITERIA_VALUE':
        return 'Revise os criterios informados antes de salvar.';
      case 'ACTIVITY_CORRECTION_ALREADY_EXISTS':
        return 'Esta atividade ja possui uma correcao registrada.';
      default:
        return error.message.trim().isNotEmpty
            ? error.message
            : 'Nao foi possivel salvar a correcao da atividade.';
    }
  }

  Future<void> _saveCorrection() async {
    if (_isSaving) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessao expirada. Faça login novamente.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final criteria = _buildCriteriaPayload();
    if (criteria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um criterio para salvar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final generalObservation = _generalObservationController.text.trim();

      final correction = _correctionExists && (_correctionId ?? '').isNotEmpty
          ? await _service.updateCorrection(
              token: token,
              correctionId: _correctionId!,
              criteria: criteria,
              generalObservation: generalObservation,
            )
          : await _service.createCorrection(
              token: token,
              qrCodePayload: widget.resolveResult.activity.qrCodePayload,
              criteria: criteria,
              generalObservation: generalObservation,
            );

      if (!mounted) return;
      setState(() {
        _correctionId = correction.id;
        _correctionExists = true;
      });

      Navigator.of(context).pop(true);
    } on ActivityCorrectionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapErrorMessage(error)),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel salvar a correcao da atividade.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18.sp,
            color: isDark ? Colors.grey[300] : const Color(0xFF334155),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value.isNotEmpty ? value : 'Nao informado',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolve = widget.resolveResult;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Correção de Atividade',
          style: GoogleFonts.sairaCondensed(
            fontWeight: FontWeight.w700,
            fontSize: 24.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 120.h),
                children: [
                  Container(
                    padding: EdgeInsets.all(18.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827) : Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                PhosphorIcons.clipboard_text_fill,
                                color: const Color(0xFF2563EB),
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    resolve.activity.activityTitle.isNotEmpty
                                        ? resolve.activity.activityTitle
                                        : 'Atividade pronta',
                                    style: GoogleFonts.inter(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    resolve.activity.bookTitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _buildInfoTile(
                          icon: PhosphorIcons.student_fill,
                          label: 'Aluno',
                          value: resolve.student.name,
                          isDark: isDark,
                        ),
                        SizedBox(height: 10.h),
                        _buildInfoTile(
                          icon: PhosphorIcons.users_fill,
                          label: 'Turma',
                          value: resolve.classInfo.name,
                          isDark: isDark,
                        ),
                        SizedBox(height: 10.h),
                        _buildInfoTile(
                          icon: PhosphorIcons.book_fill,
                          label: 'Disciplina e pagina',
                          value:
                              '${resolve.activity.subject} • Pág. ${resolve.activity.pageNumber.toString().padLeft(2, '0')}',
                          isDark: isDark,
                        ),
                        SizedBox(height: 10.h),
                        _buildInfoTile(
                          icon: PhosphorIcons.chalkboard_teacher_fill,
                          label: 'Professor',
                          value: resolve.teacher.name,
                          isDark: isDark,
                        ),
                        if ((resolve.activity.printDate ?? '').trim().isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          _buildInfoTile(
                            icon: PhosphorIcons.calendar_fill,
                            label: 'Data da impressao',
                            value: resolve.activity.printDate ?? '',
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Critérios qualitativos',
                    style: GoogleFonts.sairaCondensed(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Selecione os critérios observados na atividade impressa. Você pode deixar uma nota opcional em cada item.',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      height: 1.45,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  ...widget.resolveResult.criteriaTemplate.map((templateItem) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111827) : Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color:
                              isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            templateItem.label,
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          DropdownButtonFormField<String>(
                            initialValue:
                                _selectedValues[templateItem.key]?.trim().isNotEmpty == true
                                ? _selectedValues[templateItem.key]
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Avaliação',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            items: templateItem.scale
                                .map(
                                  (scaleValue) => DropdownMenuItem<String>(
                                    value: scaleValue,
                                    child: Text(_humanizeScaleValue(scaleValue)),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedValues[templateItem.key] = value;
                                    });
                                  },
                          ),
                          SizedBox(height: 10.h),
                          TextField(
                            controller: _noteControllers[templateItem.key],
                            enabled: !_isSaving,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Observação deste critério (opcional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827) : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: TextField(
                      controller: _generalObservationController,
                      enabled: !_isSaving,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Observação geral',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCorrection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    icon: _isSaving
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(PhosphorIcons.floppy_disk_fill),
                    label: Text(
                      _isSaving
                          ? 'Salvando...'
                          : _correctionExists
                              ? 'Atualizar correção'
                              : 'Salvar correção',
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
