import 'package:academyhub_mobile/model/academic_record_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart'; // Precisaremos para o form
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/subject_provider.dart'; // Precisaremos para o form
import 'package:academyhub_mobile/services/student_service.dart';
// Importe o novo formulário que criaremos a seguir
import 'package:academyhub_mobile/widgets/student_record_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AcademicHistoryManagerDialog extends StatefulWidget {
  final String studentId;
  final List<AcademicRecord> initialHistory;

  const AcademicHistoryManagerDialog({
    super.key,
    required this.studentId,
    required this.initialHistory,
  });

  @override
  State<AcademicHistoryManagerDialog> createState() =>
      _AcademicHistoryManagerDialogState();
}

class _AcademicHistoryManagerDialogState
    extends State<AcademicHistoryManagerDialog> {
  late List<AcademicRecord> _records;
  bool _isLoading = false;
  String? _error;

  final StudentService _studentService = StudentService();
  late final AuthProvider _authProvider;

  // Carrega as disciplinas da escola uma única vez para passar ao formulário
  late final Future<List<SubjectModel>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _records = List.from(widget.initialHistory);
    // Ordena os registros do mais recente para o mais antigo
    _records.sort((a, b) => b.schoolYear.compareTo(a.schoolYear));
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _subjectsFuture = _fetchSubjects();
  }

  Future<List<SubjectModel>> _fetchSubjects() async {
    // Busca todas as disciplinas disponíveis para usar no formulário de notas
    final token = _authProvider.token;
    if (token == null) return [];

    try {
      // --- CORREÇÃO AQUI ---
      // 1. Pega o provider
      final subjectProvider =
          Provider.of<SubjectProvider>(context, listen: false);

      // 2. Chama a função (que é 'void')
      await subjectProvider.fetchSubjects(token);

      // 3. Retorna a lista que o provider buscou
      return subjectProvider.subjects;
      // --- FIM DA CORREÇÃO ---
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Erro ao carregar lista de disciplinas: $e');
      }
      return [];
    }
  }

  // --- ABRIR O FORMULÁRIO (PARA ADICIONAR OU EDITAR) ---
  Future<void> _openRecordForm(
      AcademicRecord? recordToEdit, List<SubjectModel> allSubjects) async {
    final List<AcademicRecord>? updatedList =
        await showDialog<List<AcademicRecord>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StudentRecordFormDialog(
        studentId: widget.studentId,
        recordToEdit: recordToEdit,
        allSubjects: allSubjects, // Passa a lista de disciplinas
      ),
    );

    // Se o formulário retornou a lista atualizada (após salvar)
    if (updatedList != null && mounted) {
      setState(() {
        _records = updatedList
          ..sort((a, b) => b.schoolYear.compareTo(a.schoolYear)); // Re-ordena
      });
      _showSuccessSnackbar(recordToEdit == null
          ? 'Registro adicionado com sucesso.'
          : 'Registro atualizado com sucesso.');
    }
  }

  // --- DELETAR UM REGISTRO ---
  Future<void> _deleteRecord(String recordId) async {
    // Confirmação
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
            'Tem certeza que deseja excluir este registro acadêmico? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir')),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = _authProvider.token;
    if (token == null) {
      _showErrorSnackbar('Erro de autenticação.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updatedList = await _studentService.deleteHistoryRecord(
          token, widget.studentId, recordId);
      if (mounted) {
        setState(() {
          _records = updatedList
            ..sort((a, b) => b.schoolYear.compareTo(a.schoolYear));
        });
        _showSuccessSnackbar('Registro excluído com sucesso.');
      }
    } catch (e) {
      if (mounted) _showErrorSnackbar('Erro ao excluir: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      backgroundColor: Colors.white,
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 10.h),
      actionsPadding: EdgeInsets.fromLTRB(15.w, 0, 15.w, 15.h),

      // Título
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade700,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15.r),
            topRight: Radius.circular(15.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.book_bookmark_bold,
                    color: Colors.white, size: 26.sp),
                SizedBox(width: 12.w),
                Text('Gerenciar Histórico',
                    style: GoogleFonts.sairaCondensed(
                        fontWeight: FontWeight.bold,
                        fontSize: 22.sp,
                        color: Colors.white)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () =>
                  Navigator.of(context).pop(_records), // Retorna a lista atual
              tooltip: 'Fechar',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),

      // Conteúdo
      content: SizedBox(
        width: 800.w, // Popup largo
        height: 600.h, // Popup alto
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)))
                : _records.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum registro acadêmico encontrado.',
                          style: GoogleFonts.inter(
                              fontSize: 16.sp, color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final record = _records[index];
                          return _buildRecordTile(record);
                        },
                      ),
      ),

      // Ações
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
          onPressed: () =>
              Navigator.of(context).pop(_records), // Retorna a lista atual
          child: const Text('Fechar'),
        ),

        // Espera as disciplinas carregarem para habilitar o botão
        FutureBuilder<List<SubjectModel>>(
            future: _subjectsFuture,
            builder: (context, snapshot) {
              final bool canAdd =
                  snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData;
              return ElevatedButton.icon(
                icon: Icon(PhosphorIcons.plus_circle_fill, size: 18.sp),
                label: const Text('Adicionar Registro Anual'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                  textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 14.sp),
                ),
                // Desabilita se as disciplinas não carregaram
                onPressed:
                    canAdd ? () => _openRecordForm(null, snapshot.data!) : null,
              );
            }),
      ],
    );
  }

  // --- Widget para montar cada item da lista ---
  Widget _buildRecordTile(AcademicRecord record) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(color: Colors.grey.shade200, width: 0.8),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 15.w),
        title: Text(
          '${record.gradeLevel} - ${record.schoolYear}',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 17.sp,
              color: Colors.deepPurple.shade800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              'Escola: ${record.schoolName} (${record.city}/${record.state})',
              style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.black54),
            ),
            SizedBox(height: 4.h),
            Text(
              'Resultado: ${record.finalResult} (${record.grades.length} disciplinas, Carga: ${record.annualWorkload ?? "N/A"})',
              style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.black54),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botão Editar
            FutureBuilder<List<SubjectModel>>(
                future: _subjectsFuture,
                builder: (context, snapshot) {
                  // Habilita edição só qnd as disciplinas carregarem
                  final canEdit =
                      snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData;
                  return IconButton(
                    icon: Icon(PhosphorIcons.pencil_simple_line_bold,
                        color: canEdit
                            ? Colors.blueGrey.shade600
                            : Colors.grey.shade300,
                        size: 20.sp),
                    tooltip: canEdit ? 'Editar Registro' : 'Carregando...',
                    onPressed: canEdit
                        ? () => _openRecordForm(record, snapshot.data!)
                        : null,
                  );
                }),
            SizedBox(width: 8.w),
            // Botão Excluir
            IconButton(
              icon: Icon(PhosphorIcons.trash_simple_bold,
                  color: Colors.red.shade400, size: 20.sp),
              tooltip: 'Excluir Registro',
              onPressed: () => _deleteRecord(record.id),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers de UI ---
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange.shade800,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          left: 10,
          right: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
    ));
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          left: 10,
          right: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
    ));
  }
}
