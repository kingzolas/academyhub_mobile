// import 'package:academyhub_mobile/model/model_alunos.dart';
// import 'package:academyhub_mobile/providers/auth_provider.dart';
// import 'package:academyhub_mobile/services/student_service.dart';
// import 'package:academyhub_mobile/util/listas_dynamicas.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart' as intl;
// import 'package:provider/provider.dart';

// class Cardinfo extends StatefulWidget {
//   final String texto;
//   final String numero;
//   final IconData icone;
//   final Color color;

//   const Cardinfo(
//       {super.key,
//       required this.color,
//       required this.texto,
//       required this.numero,
//       required this.icone});

//   @override
//   State<Cardinfo> createState() => _CardinfoState();
// }

// class _CardinfoState extends State<Cardinfo> {
//   @override
//   Widget build(BuildContext context) {
//     return ScreenUtilInit(
//         designSize: Size(1920, 1080),
//         minTextAdapt: true,
//         splitScreenMode: true,
//         builder: (context, child) {
//           return Container(
//             height: 155.sp,
//             width: 395.sp,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.2),
//                   blurRadius: 18.sp,
//                   offset: Offset(4.sp, 4.sp),
//                 )
//               ],
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   height: 155.sp,
//                   width: 10.sp,
//                   decoration: BoxDecoration(
//                     color: widget.color,
//                     borderRadius: BorderRadius.only(
//                         bottomLeft: Radius.circular(5),
//                         topLeft: Radius.circular(5)),
//                   ),
//                 ),
//                 SizedBox(
//                   width: 30.sp,
//                 ),
//                 Container(
//                   // color: Colors.amber,
//                   width: 240.sp,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         widget.texto,
//                         style: GoogleFonts.leagueSpartan(
//                           color: widget.color,
//                           fontSize: 20.sp,
//                           // fontFamily: 'League Spartan',
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                       SizedBox(
//                         height: 0.sp,
//                       ),
//                       Text(
//                         widget.numero,
//                         style: GoogleFonts.leagueSpartan(
//                           color: Color(0xB71B1F26),
//                           fontSize: 34.sp,
//                           // fontFamily: 'League Spartan',
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(
//                   width: 20.sp,
//                 ),
//                 Icon(
//                   widget.icone,
//                   color: widget.color,
//                   size: 60.sp,
//                 )
//               ],
//             ),
//           );
//         });
//   }
// }

// Widget DatasComemorativas() {
//   final comemorativas = ListaComemorativa.getComemorativas();
//   return Container(
//     child: Column(
//       children: [
//         Container(
//           width: 395.sp,
//           height: 41.sp,
//           decoration: BoxDecoration(
//             color: Color(0xff3C3C43),
//             borderRadius: BorderRadius.only(
//               topLeft: Radius.circular(10.sp),
//               topRight: Radius.circular(10.sp),
//             ),
//           ),
//           child: Row(
//             children: [
//               SizedBox(
//                 width: 30.sp,
//               ),
//               Text(
//                 'Datas comemmorativas',
//                 style: GoogleFonts.sairaCondensed(
//                     color: Colors.white,
//                     fontSize: 27.sp,
//                     fontWeight: FontWeight.w700),
//               ),
//               SizedBox(
//                 width: 10.sp,
//               ),
//               Icon(
//                 PhosphorIcons.confetti_fill,
//                 color: Colors.white,
//               )
//             ],
//           ),
//         ),
//         Container(
//           width: 395.sp,
//           height: 290.sp,
//           decoration: BoxDecoration(
//             boxShadow: [
//               BoxShadow(
//                 blurRadius: 18.sp,
//                 color: Colors.black.withOpacity(0.3),
//               ),
//             ],
//             color: Colors.white,
//             borderRadius: BorderRadius.only(
//               bottomLeft: Radius.circular(
//                 10.sp,
//               ),
//               bottomRight: Radius.circular(10.sp),
//             ),
//           ),
//           child: Padding(
//               padding: EdgeInsets.only(
//                   top: 0.sp, left: 30.sp, right: 30.sp, bottom: 10.sp),
//               child: Container(
//                 child: ListView.builder(
//                   itemCount: ListaComemorativa.comemorativas.length,
//                   itemBuilder: (context, index) {
//                     var comemorativa = comemorativas[index];
//                     return _infoContainer(
//                       cor: comemorativa['Cor'],
//                       Titulo: comemorativa['Titulo'],
//                       Data: comemorativa['Data'],
//                       icone: comemorativa['Icone'],
//                     );
//                   },
//                 ),
//               )),
//         ),
//       ],
//     ),
//   );
// }

// Widget Agendamentos() {
//   final avaliacoes = ListaAvaliacoes.getAvaliacoes();
//   return Container(
//     child: Column(
//       children: [
//         Container(
//           width: 395.sp,
//           height: 41.sp,
//           decoration: BoxDecoration(
//             color: Color(0xff3C3C43),
//             borderRadius: BorderRadius.only(
//               topLeft: Radius.circular(10.sp),
//               topRight: Radius.circular(10.sp),
//             ),
//           ),
//           child: Row(
//             children: [
//               SizedBox(
//                 width: 20.sp,
//               ),
//               Text(
//                 'Agendamentos',
//                 style: GoogleFonts.sairaCondensed(
//                     color: Colors.white,
//                     fontSize: 27.sp,
//                     fontWeight: FontWeight.w700),
//               ),
//               SizedBox(
//                 width: 10.sp,
//               ),
//               Icon(
//                 PhosphorIcons.hourglass_high_fill,
//                 color: Colors.white,
//               )
//             ],
//           ),
//         ),
//         Container(
//           width: 395.sp,
//           height: 290.sp,
//           decoration: BoxDecoration(
//             boxShadow: [
//               BoxShadow(
//                 blurRadius: 18.sp,
//                 color: Colors.black.withOpacity(0.3),
//               ),
//             ],
//             color: Colors.white,
//             borderRadius: BorderRadius.only(
//               bottomLeft: Radius.circular(
//                 10.sp,
//               ),
//               bottomRight: Radius.circular(10.sp),
//             ),
//           ),
//           child: Padding(
//               padding: EdgeInsets.only(
//                   left: 30.sp, right: 30.sp, top: 0.sp, bottom: 0.sp),
//               child: Container(
//                 child: ListView.builder(
//                   itemCount: ListaAvaliacoes.avaliacoes.length,
//                   itemBuilder: (context, index) {
//                     var avaliacao = avaliacoes[index];
//                     return _infoContainerAgendamentos(
//                         cor: avaliacao['Cor'],
//                         Titulo: avaliacao['Titulo'],
//                         Data: avaliacao['Data'],
//                         icone: avaliacao['Icone']);
//                   },
//                 ),
//               )),
//         )
//       ],
//     ),
//   );
// }

// class AniversariantesWidget extends StatefulWidget {
//   const AniversariantesWidget({super.key});

//   @override
//   State<AniversariantesWidget> createState() => _AniversariantesWidgetState();
// }

// class _AniversariantesWidgetState extends State<AniversariantesWidget> {
//   final StudentService _studentService = StudentService();
//   late final Future<List<Student>> _birthdaysFuture;

//   @override
//   void initState() {
//     super.initState();
//     final token = context.read<AuthProvider>().token;
//     _birthdaysFuture = _studentService.getUpcomingBirthdays(token);
//   }

//   int _calculateAge(DateTime birthDate) {
//     DateTime currentDate = DateTime.now();
//     int age = currentDate.year - birthDate.year;
//     if (currentDate.month < birthDate.month ||
//         (currentDate.month == birthDate.month &&
//             currentDate.day < birthDate.day)) {
//       age--;
//     }
//     return age + 1; // Idade que a pessoa fará
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       child: Column(
//         children: [
//           Container(
//             width: 820.w,
//             height: 41.h,
//             decoration: BoxDecoration(
//               color: const Color(0xff3C3C43),
//               borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(10.r),
//                 topRight: Radius.circular(10.r),
//               ),
//             ),
//             child: Row(
//               children: [
//                 SizedBox(width: 20.w),
//                 Text(
//                   'Aniversáriantes',
//                   style: GoogleFonts.sairaCondensed(
//                       color: Colors.white,
//                       fontSize: 27.sp,
//                       fontWeight: FontWeight.w700),
//                 ),
//                 SizedBox(width: 10.w),
//                 const Icon(
//                   PhosphorIcons.cake_fill,
//                   color: Colors.white,
//                 )
//               ],
//             ),
//           ),
//           Container(
//             width: 820.w,
//             height: 290.h,
//             decoration: BoxDecoration(
//               boxShadow: [
//                 BoxShadow(
//                   blurRadius: 18.r,
//                   color: Colors.black.withOpacity(0.3),
//                 ),
//               ],
//               color: Colors.white,
//               borderRadius: BorderRadius.only(
//                 bottomLeft: Radius.circular(10.r),
//                 bottomRight: Radius.circular(10.r),
//               ),
//             ),
//             child: FutureBuilder<List<Student>>(
//               future: _birthdaysFuture,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }

//                 if (snapshot.hasError) {
//                   return Center(
//                     child: Text(
//                       'Erro ao carregar aniversariantes.',
//                       style: GoogleFonts.inter(color: Colors.red),
//                     ),
//                   );
//                 }

//                 if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return Center(
//                     child: Text(
//                       'Nenhum aniversariante próximo.',
//                       style: GoogleFonts.inter(),
//                     ),
//                   );
//                 }

//                 final aniversarios = snapshot.data!;

//                 return ListView.builder(
//                   itemCount: aniversarios.length,
//                   itemBuilder: (context, index) {
//                     var student = aniversarios[index];
//                     return _cedulaAniversa(
//                       nome: student.fullName,
//                       data: intl.DateFormat('dd/MM').format(student.birthDate),
//                       turma: "Não definida", // Ajustar com model de turma
//                       idade: _calculateAge(student.birthDate),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// Widget _cedulaAniversa({
//   required String nome,
//   required String data,
//   required String turma,
//   required int idade,
// }) {
//   return Container(
//     padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
//     decoration: BoxDecoration(
//         border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Row(
//           children: [
//             const Icon(PhosphorIcons.user_circle_fill,
//                 color: Colors.grey, size: 30),
//             SizedBox(width: 15.w),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(nome,
//                     style: GoogleFonts.inter(
//                         fontWeight: FontWeight.bold, fontSize: 16.sp)),
//                 Text(turma,
//                     style: GoogleFonts.inter(
//                         color: Colors.grey.shade600, fontSize: 14.sp)),
//               ],
//             ),
//           ],
//         ),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             Text(data,
//                 style: GoogleFonts.inter(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16.sp,
//                     color: Color(0xff007AFF))),
//             Text("Fará $idade anos",
//                 style: GoogleFonts.inter(
//                     color: Colors.grey.shade600, fontSize: 14.sp)),
//           ],
//         ),
//       ],
//     ),
//   );
// }

// Widget _infoContainer({
//   required Color cor,
//   required String Titulo,
//   required String Data,
//   required IconData icone,
// }) {
//   return Container(
//     child: Padding(
//       padding: EdgeInsets.only(top: 10.sp),
//       child: Row(
//         children: [
//           Container(
//             height: 50.sp,
//             width: 50.sp,
//             decoration: BoxDecoration(
//               color: cor,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Center(
//               child: Icon(
//                 icone,
//                 color: Colors.white,
//                 size: 20.sp,
//               ),
//             ),
//           ),
//           SizedBox(
//             width: 10,
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 Titulo,
//                 style: GoogleFonts.leagueSpartan(
//                     color: Color(0xff292929),
//                     fontSize: 21.sp,
//                     fontWeight: FontWeight.w700),
//               ),
//               Text(
//                 Data,
//                 style: GoogleFonts.leagueSpartan(
//                     height: 1.sp,
//                     color: Color(0xff5B5E63),
//                     fontSize: 21.sp,
//                     fontWeight: FontWeight.w500),
//               )
//             ],
//           )
//         ],
//       ),
//     ),
//   );
// }

// Widget _infoContainerAgendamentos(
//     {required Color cor,
//     required String Titulo,
//     required String Data,
//     required IconData icone,
//     String? Turma}) {
//   return Container(
//     child: Padding(
//       padding: EdgeInsets.only(
//         top: 10.sp,
//       ),
//       child: Row(
//         children: [
//           Container(
//             height: 50.sp,
//             width: 50.sp,
//             decoration: BoxDecoration(
//               color: cor,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Center(
//               child: Icon(
//                 icone,
//                 color: Colors.white,
//                 size: 30.sp,
//               ),
//             ),
//           ),
//           SizedBox(
//             width: 10,
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 Titulo,
//                 style: GoogleFonts.leagueSpartan(
//                     color: Color(0xff292929),
//                     fontSize: 21.sp,
//                     fontWeight: FontWeight.w700),
//               ),
//               Text(
//                 '${Data} | ${Turma ?? ''}',
//                 style: GoogleFonts.leagueSpartan(
//                     height: 1.sp,
//                     color: Color(0xff5B5E63),
//                     fontSize: 21.sp,
//                     fontWeight: FontWeight.w500),
//               )
//             ],
//           )
//         ],
//       ),
//     ),
//   );
// }
