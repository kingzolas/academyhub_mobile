import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/model/tutor_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/tutor_service.dart';
import 'package:academyhub_mobile/widgets/student_details_popup.dart'; // Para buildInputDecoration
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class EditTutorDialog extends StatefulWidget {
  final TutorInStudent tutorLink;
  final String studentId;

  const EditTutorDialog(
      {super.key, required this.tutorLink, required this.studentId});

  @override
  State<EditTutorDialog> createState() => _EditTutorDialogState();
}

class _EditTutorDialogState extends State<EditTutorDialog> {
  final _formKey = GlobalKey<FormState>();
  final TutorService _tutorService = TutorService();
  bool _isSubmitting = false;

  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _cpfController;
  late TextEditingController _relationshipController;

  @override
  void initState() {
    super.initState();
    final tutorInfo = widget.tutorLink.tutorInfo;
    _fullNameController = TextEditingController(text: tutorInfo.fullName);
    _emailController = TextEditingController(text: tutorInfo.email);
    _phoneNumberController = TextEditingController(text: tutorInfo.phoneNumber);
    _cpfController = TextEditingController(text: tutorInfo.cpf);
    _relationshipController =
        TextEditingController(text: widget.tutorLink.relationship);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _cpfController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar('Corrija os erros no formulário.');
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) {
      _showErrorSnackbar('Erro de autenticação.');
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final tutorData = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'cpf': _cpfController.text.trim(),
      };

      await _tutorService.updateTutor(
          widget.tutorLink.tutorInfo.id, token, tutorData);

      final updatedLink = await _tutorService.updateTutorRelationship(
          widget.studentId,
          widget.tutorLink.tutorInfo.id,
          _relationshipController.text.trim(),
          token);

      if (mounted) {
        Navigator.of(context).pop(updatedLink);
      }
    } catch (e) {
      _showErrorSnackbar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    // Captura de Tema
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cor do header (roxo) adaptada
    final headerColor =
        isDark ? Colors.deepPurple.shade900 : Colors.deepPurple.shade600;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      backgroundColor: theme.cardColor, // Fundo adaptativo
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.symmetric(horizontal: 25.w)
          .copyWith(top: 10.h, bottom: 5.h),
      actionsPadding: EdgeInsets.fromLTRB(15.w, 0, 15.w, 15.h),
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: headerColor,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15.r), topRight: Radius.circular(15.r)),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.user_focus_bold,
                color: Colors.white, size: 26.sp),
            SizedBox(width: 12.w),
            Text(
              'Editar Tutor',
              style: GoogleFonts.sairaCondensed(
                  fontWeight: FontWeight.bold,
                  fontSize: 22.sp,
                  color: Colors.white),
            ),
          ],
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_fullNameController, 'Nome Completo *',
                    PhosphorIcons.user, isDark),
                SizedBox(height: 15.h),
                _buildTextField(_cpfController, 'CPF',
                    PhosphorIcons.identification_card, isDark,
                    readOnly: false, keyboardType: TextInputType.number),
                SizedBox(height: 15.h),
                _buildTextField(
                    _emailController, 'Email', PhosphorIcons.envelope, isDark,
                    keyboardType: TextInputType.emailAddress),
                SizedBox(height: 15.h),
                _buildTextField(_phoneNumberController, 'Telefone',
                    PhosphorIcons.phone, isDark,
                    keyboardType: TextInputType.phone),
                SizedBox(height: 15.h),
                _buildTextField(
                    _relationshipController,
                    'Parentesco * (Ex: Mãe)',
                    PhosphorIcons.users_three,
                    isDark),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          icon: _isSubmitting
              ? SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Icon(PhosphorIcons.check_circle_fill, size: 18.sp),
          label: const Text('Salvar'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
              textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, fontSize: 14.sp)),
          onPressed: _isSubmitting ? null : _submitForm,
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    // Cores adaptativas para input readOnly
    final fillColor = readOnly
        ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
        : (isDark ? Colors.grey.shade900 : const Color(0xffD0DFE9));

    final textColor = readOnly
        ? (isDark ? Colors.grey.shade500 : Colors.grey.shade700)
        : (isDark ? Colors.white : Colors.black87);

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      // Passando context para buildInputDecoration
      decoration: buildInputDecoration(context, label, icon)
          .copyWith(fillColor: fillColor),
      style: GoogleFonts.inter(
          color: textColor, fontWeight: FontWeight.w500, fontSize: 15.sp),
      validator: (value) {
        if (label.contains('*') && (value == null || value.trim().isEmpty)) {
          return 'Campo obrigatório';
        }
        return null;
      },
    );
  }
}
