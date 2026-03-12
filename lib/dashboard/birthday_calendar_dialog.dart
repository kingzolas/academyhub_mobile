// import 'package:academyhub_mobile/model/student_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/student_provider.dart';
import 'package:flutter/gestures.dart'; // Importante para Scroll
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:provider/provider.dart';

class BirthdayCalendarDialog extends StatefulWidget {
  const BirthdayCalendarDialog({super.key});

  @override
  State<BirthdayCalendarDialog> createState() => _BirthdayCalendarDialogState();
}

class _BirthdayCalendarDialogState extends State<BirthdayCalendarDialog> {
  int _selectedMonth = DateTime.now().month;
  bool _isLoading = true;

  final List<String> _months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await Provider.of<StudentProvider>(context, listen: false)
        .fetchStudents(auth.token!);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // [POSICIONAMENTO] Alinhado à direita para não cobrir o centro
      alignment: Alignment.centerRight,
      insetPadding: EdgeInsets.only(right: 40.w, top: 50.h, bottom: 50.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: Container(
        width: 450.w, // Largura mais compacta
        height: 650.h,
        padding: EdgeInsets.all(24.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.cake_fill,
                        color: Colors.pinkAccent, size: 24.sp),
                    SizedBox(width: 10.w),
                    Text("Calendário de Aniversários",
                        style: GoogleFonts.sairaCondensed(
                            fontSize: 22.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 20.sp))
              ],
            ),
            SizedBox(height: 20.h),

            // [CORREÇÃO SCROLL] Wrapper para permitir arrastar com mouse
            SizedBox(
              height: 40.h,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse, // Habilita mouse drag
                  },
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 12,
                  separatorBuilder: (_, __) => SizedBox(width: 8.w),
                  itemBuilder: (ctx, index) {
                    final monthIndex = index + 1;
                    final isSelected = monthIndex == _selectedMonth;
                    return InkWell(
                      onTap: () => setState(() => _selectedMonth = monthIndex),
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.pinkAccent : Colors.white,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.pinkAccent
                                    : Colors.grey[300]!)),
                        child: Text(
                          _months[index],
                          style: GoogleFonts.inter(
                              color:
                                  isSelected ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Consumer<StudentProvider>(
                      builder: (ctx, provider, _) {
                        final birthdays = provider.students.where((s) {
                          if (!s.isActive) return false;
                          try {
                            final date = DateTime.parse(s.birthDate.toString());
                            return date.month == _selectedMonth;
                          } catch (e) {
                            return false;
                          }
                        }).toList();

                        birthdays.sort((a, b) {
                          final dateA = DateTime.parse(a.birthDate.toString());
                          final dateB = DateTime.parse(b.birthDate.toString());
                          return dateA.day.compareTo(dateB.day);
                        });

                        if (birthdays.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(PhosphorIcons.confetti,
                                    size: 48.sp, color: Colors.grey[200]),
                                SizedBox(height: 10.h),
                                Text(
                                    "Nenhum aniversariante em ${_months[_selectedMonth - 1]}",
                                    style: GoogleFonts.inter(
                                        color: Colors.grey[400])),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: birthdays.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey[100]),
                          itemBuilder: (ctx, i) {
                            final student = birthdays[i];
                            final dob =
                                DateTime.parse(student.birthDate.toString());

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 4.h, horizontal: 0),
                              leading: Container(
                                width: 45.sp,
                                height: 45.sp,
                                decoration: BoxDecoration(
                                  color: Colors.pink[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text("${dob.day}",
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.sp,
                                          color: Colors.pink)),
                                ),
                              ),
                              title: Text(student.fullName,
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.sp)),
                              subtitle: Text(
                                  "Turma: ${student.classId?.toString() ?? 'Não enturmado'}",
                                  style: GoogleFonts.inter(
                                      fontSize: 12.sp, color: Colors.grey)),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
