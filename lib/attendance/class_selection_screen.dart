import 'package:academyhub_mobile/attendance/attendance_swipe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Importe o AuthProvider para pegar o token
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';

// Definindo um tipo para o callback para ficar mais limpo
typedef ClassSelectedCallback = void Function(String classId, String className);

class ClassSelectionScreen extends StatefulWidget {
  // Adicionamos um callback para o botão de voltar funcionar no IndexedStack
  final VoidCallback? onBack;
  // [NOVO] Callback para avisar o pai (Dashboard) qual turma foi escolhida
  final ClassSelectedCallback onClassSelected;

  const ClassSelectionScreen({
    super.key,
    this.onBack,
    required this.onClassSelected, // Obrigatório agora
  });

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Carrega as turmas assim que abre a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
    });
  }

  void _loadClasses() {
    // 1. Obtém o AuthProvider (sem ouvir mudanças, apenas para ler dados)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);

    // 2. Verifica se temos o token
    final token = authProvider.token;
    final user = authProvider.user;

    if (token != null) {
      // 3. Monta o filtro (opcional, mas recomendado para garantir segurança por escola)
      Map<String, String> filter = {};
      if (user?.schoolId != null) {
        filter['schoolId'] = user!.schoolId!;
      }

      // 4. Chama o método com os parâmetros corretos
      classProvider.fetchClasses(token, filter: filter);
    } else {
      debugPrint("Erro: Token não encontrado ao tentar buscar turmas.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    final classes = classProvider.classes;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Selecione a Turma",
          style:
              GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18.sp),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caret_left,
              color: Theme.of(context).iconTheme.color),
          onPressed: () {
            // Se foi passado um callback, executa (ex: voltar para Home)
            if (widget.onBack != null) {
              widget.onBack!();
            }
          },
        ),
      ),
      body: classProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
              ? Center(
                  child: Text(
                    "Nenhuma turma encontrada.",
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    final turma = classes[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12.h),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        leading: Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A859).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              PhosphorIcons.chalkboard_teacher_fill,
                              color: Color(0xFF00A859)),
                        ),
                        title: Text(
                          turma.name,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 16.sp),
                        ),
                        // Validação segura caso studentsCount seja nulo
                        subtitle: Text(
                          "${turma.studentCount ?? 0} Alunos",
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                        trailing: const Icon(PhosphorIcons.caret_right),
                        onTap: () {
                          // [CORREÇÃO CRÍTICA]
                          // NÃO usamos Navigator.push aqui, pois ele cobre o menu.
                          // Em vez disso, chamamos o callback para o Dashboard lidar com a troca.
                          widget.onClassSelected(turma.id!, turma.name);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
