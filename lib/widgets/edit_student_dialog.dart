import 'dart:async';
import 'dart:io'; // Cuidado: Só usar se !kIsWeb
import 'dart:typed_data';

import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/model/tutor_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/student_service.dart';
import 'package:academyhub_mobile/services/tutor_service.dart';
import 'package:academyhub_mobile/widgets/edit_tutor_dialog.dart';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

// IMPORTANTE: kIsWeb vem daqui
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

// --- [WIDGET DE SUCESSO - OVERLAY] ---
// (Mantido inalterado)
class UpdateSuccessOverlay extends StatefulWidget {
  final VoidCallback onRemove;
  const UpdateSuccessOverlay({super.key, required this.onRemove});

  @override
  State<UpdateSuccessOverlay> createState() => _UpdateSuccessOverlayState();
}

class _UpdateSuccessOverlayState extends State<UpdateSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _controller.forward();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _close();
    });
  }

  void _close() async {
    if (mounted) await _controller.reverse();
    widget.onRemove();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 30.h,
      right: 30.w,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Container(
            width: 350.w,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
              border: Border.all(color: Colors.grey.shade800, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PhosphorIcons.check_circle_fill,
                      color: Colors.greenAccent, size: 24.sp),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Salvo!',
                        style: GoogleFonts.sairaCondensed(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'As alterações foram salvas com sucesso.',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade300,
                          fontSize: 13.sp,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: _close,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- TELA PRINCIPAL DE EDIÇÃO ---

class EditStudentDialog extends StatefulWidget {
  final Student student;
  const EditStudentDialog({super.key, required this.student});

  @override
  State<EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final StudentService _studentService = StudentService();
  final TutorService _tutorService = TutorService();

  bool _isSubmitting = false;

  // Variáveis para Imagem
  Uint8List? _newProfileImageBytes;
  String? _newProfileImageName;

  // Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _cpfController;
  late TextEditingController _rgController;
  late TextEditingController _nationalityController;
  late TextEditingController _raceController;
  late TextEditingController _birthDateController;
  late TextEditingController _streetController;
  late TextEditingController _numberController;
  late TextEditingController _neighborhoodController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _blockController;
  late TextEditingController _lotController;

  String? _selectedGender;
  DateTime? _selectedBirthDate;
  final List<String> _genderOptions = ['Masculino', 'Feminino', 'Outro'];

  late List<TutorInStudent> _currentTutors;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.student.fullName);
    _emailController = TextEditingController(text: widget.student.email);
    _phoneNumberController =
        TextEditingController(text: widget.student.phoneNumber);
    _cpfController = TextEditingController(text: widget.student.cpf);
    _rgController = TextEditingController(text: widget.student.rg);
    _nationalityController =
        TextEditingController(text: widget.student.nationality);
    _raceController = TextEditingController(text: widget.student.race);

    _selectedGender = widget.student.gender;
    _selectedBirthDate = widget.student.birthDate;
    _birthDateController = TextEditingController(
        text: _selectedBirthDate != null
            ? intl.DateFormat('dd/MM/yyyy').format(_selectedBirthDate!)
            : '');

    _streetController =
        TextEditingController(text: widget.student.address.street);
    _numberController =
        TextEditingController(text: widget.student.address.number);
    _neighborhoodController =
        TextEditingController(text: widget.student.address.neighborhood);
    _cityController = TextEditingController(text: widget.student.address.city);
    _stateController =
        TextEditingController(text: widget.student.address.state);
    _blockController =
        TextEditingController(text: widget.student.address.block);
    _lotController = TextEditingController(text: widget.student.address.lot);

    _currentTutors = List.from(widget.student.tutors);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _nationalityController.dispose();
    _raceController.dispose();
    _birthDateController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _blockController.dispose();
    _lotController.dispose();
    super.dispose();
  }

  // --- Lógica de Permissão: Só executa se NÃO for Web ---
  Future<bool> _checkPermission() async {
    // 1. Se for WEB, retorna TRUE imediatamente.
    // O navegador cuida do popup de permissão.
    if (kIsWeb) return true;

    // 2. Se for Desktop (Windows/Mac/Linux), também retorna true.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;

    // 3. Apenas para Android e iOS Nativos
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // Android 13+ usa permissão granular de Fotos
      if (androidInfo.version.sdkInt >= 33) {
        final photos = await Permission.photos.request();
        return photos.isGranted || photos.isLimited;
      }
      // Android antigo usa Storage
      else {
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    }

    if (Platform.isIOS) {
      final photos = await Permission.photos.request();
      return photos.isGranted || photos.isLimited;
    }

    return false;
  }

  // --- Lógica de Seleção de Imagem ---
  Future<void> _pickImage() async {
    try {
      // 1. Verifica permissão (inteligente, pula se for Web)
      bool hasPermission = await _checkPermission();

      if (!hasPermission) {
        _showErrorSnackbar(
            "Permissão de acesso à galeria negada. Verifique as configurações.");
        return;
      }

      // 2. Abre o Seletor
      // Na Web Mobile, isso abrirá o menu nativo do navegador (Câmera/Arquivos)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Crucial para Web: carrega os bytes na memória
      );

      if (result != null) {
        Uint8List? fileBytes;
        String fileName = result.files.first.name;

        // Lógica Híbrida: Tenta pegar os bytes direto (Web/Desktop) ou ler do path (Mobile Nativo)
        if (result.files.first.bytes != null) {
          fileBytes = result.files.first.bytes;
        } else if (!kIsWeb && result.files.first.path != null) {
          // Só acessa File() se NÃO for Web
          File file = File(result.files.first.path!);
          fileBytes = await file.readAsBytes();
        }

        if (fileBytes != null) {
          // --- COMPRESSÃO (RESIZE) ---
          // Usamos a lib 'image' que é Dart puro e funciona na Web
          img.Image? originalImage = img.decodeImage(fileBytes);

          if (originalImage != null) {
            // Redimensiona para economizar dados
            img.Image resizedImage = img.copyResize(originalImage, width: 800);

            // Codifica para JPG
            Uint8List compressedBytes =
                Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));

            setState(() {
              _newProfileImageBytes = compressedBytes;
              _newProfileImageName =
                  fileName.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
            });
          } else {
            // Fallback caso não consiga decodificar
            setState(() {
              _newProfileImageBytes = fileBytes;
              _newProfileImageName = fileName;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao selecionar/comprimir imagem: $e");
      _showErrorSnackbar("Erro ao processar imagem.");
    }
  }

  // ... (O restante dos métodos permanece igual) ...

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF007AFF),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text =
            intl.DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _openTutorEditDialog(TutorInStudent tutorLink) async {
    try {
      final updatedTutorLink = await showDialog<TutorInStudent>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EditTutorDialog(
          tutorLink: tutorLink,
          studentId: widget.student.id,
        ),
      );

      if (updatedTutorLink != null && mounted) {
        setState(() {
          final index = _currentTutors.indexWhere(
              (t) => t.tutorInfo.id == updatedTutorLink.tutorInfo.id);
          if (index != -1) {
            _currentTutors[index] = updatedTutorLink;
          }
        });
      }
    } catch (e) {
      _showErrorSnackbar("Erro ao editar tutor: $e");
    }
  }

  void _showSuccessOverlay(BuildContext context) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => UpdateSuccessOverlay(
        onRemove: () {
          overlayEntry.remove();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar('Por favor, corrija os erros no formulário.');
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

    final Map<String, dynamic> studentData = {
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'phoneNumber': _phoneNumberController.text.trim(),
      'cpf': _cpfController.text.trim().isEmpty
          ? null
          : _cpfController.text.trim(),
      'rg':
          _rgController.text.trim().isEmpty ? null : _rgController.text.trim(),
      'nationality': _nationalityController.text.trim(),
      'race': _raceController.text.trim(),
      'gender': _selectedGender,
      'birthDate': _selectedBirthDate?.toIso8601String(),
      'address': {
        'street': _streetController.text.trim(),
        'number': _numberController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'block': _blockController.text.trim(),
        'lot': _lotController.text.trim(),
      },
    };

    try {
      final updatedStudent = await _studentService.updateStudent(
        widget.student.id,
        token,
        studentData,
        imageBytes: _newProfileImageBytes,
        imageFilename: _newProfileImageName,
      );

      final finalUpdatedStudent = updatedStudent.copyWith(
        tutors: _currentTutors,
      );

      if (mounted) {
        _showSuccessOverlay(context);
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          Navigator.of(context).pop(finalUpdatedStudent);
        }
      }
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains("subtype of type 'String'")) {
        if (mounted) {
          _showSuccessOverlay(context);
          Navigator.of(context).pop();
        }
      } else {
        _showErrorSnackbar(errorMsg);
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.sairaCondensed(
        fontWeight: FontWeight.bold, fontSize: 18.sp, color: Colors.black87);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      backgroundColor: Colors.white,
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.symmetric(horizontal: 25.w)
          .copyWith(top: 10.h, bottom: 5.h),
      actionsPadding: EdgeInsets.fromLTRB(15.w, 0, 15.w, 15.h),
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15.r), topRight: Radius.circular(15.r)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.pencil_simple_line_bold,
                    color: Colors.white, size: 26.sp),
                SizedBox(width: 12.w),
                Text(
                  'Editar Aluno',
                  style: GoogleFonts.sairaCondensed(
                      fontWeight: FontWeight.bold,
                      fontSize: 22.sp,
                      color: Colors.white),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
              tooltip: 'Fechar',
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 700.w,
        height: 600.h,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: _buildAvatarSection(),
                ),
                SizedBox(height: 20.h),
                Text('Dados Pessoais', style: titleStyle),
                SizedBox(height: 15.h),
                _buildTextField(
                    _fullNameController, 'Nome Completo *', PhosphorIcons.user),
                SizedBox(height: 15.h),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            _emailController, 'Email', PhosphorIcons.envelope,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          !value.contains('@')) {
                        return 'Email inválido';
                      }
                      return null;
                    })),
                    SizedBox(width: 15.w),
                    Expanded(
                        child: _buildTextField(_phoneNumberController,
                            'Telefone de Contato', PhosphorIcons.phone,
                            keyboardType: TextInputType.phone)),
                  ],
                ),
                SizedBox(height: 15.h),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(_cpfController, 'CPF',
                            PhosphorIcons.identification_card)),
                    SizedBox(width: 15.w),
                    Expanded(
                        child: _buildTextField(_rgController, 'RG',
                            PhosphorIcons.identification_badge)),
                  ],
                ),
                SizedBox(height: 15.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_birthDateController,
                          'Data de Nascimento', PhosphorIcons.calendar,
                          readOnly: true, onTap: () {
                        _selectDate(context);
                      }),
                    ),
                    SizedBox(width: 15.w),
                    Expanded(child: _buildGenderDropdown()),
                  ],
                ),
                SizedBox(height: 15.h),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(_nationalityController,
                            'Nacionalidade', PhosphorIcons.globe)),
                    SizedBox(width: 15.w),
                    Expanded(
                        child: _buildTextField(
                            _raceController, 'Cor/Raça', PhosphorIcons.users)),
                  ],
                ),
                SizedBox(height: 30.h),
                Text('Endereço', style: titleStyle),
                SizedBox(height: 15.h),
                _buildTextField(_streetController, 'Rua/Avenida',
                    PhosphorIcons.map_pin_line),
                SizedBox(height: 15.h),
                Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: _buildTextField(_neighborhoodController,
                            'Bairro', PhosphorIcons.map_trifold)),
                    SizedBox(width: 15.w),
                    Expanded(
                        flex: 1,
                        child: _buildTextField(
                            _numberController, 'Nº', PhosphorIcons.hash,
                            keyboardType: TextInputType.number)),
                  ],
                ),
                SizedBox(height: 15.h),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(_blockController, 'Quadra',
                            PhosphorIcons.grid_four)),
                    SizedBox(width: 15.w),
                    Expanded(
                        child: _buildTextField(
                            _lotController, 'Lote', PhosphorIcons.square_logo)),
                  ],
                ),
                SizedBox(height: 15.h),
                Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: _buildTextField(_cityController, 'Cidade',
                            PhosphorIcons.buildings)),
                    SizedBox(width: 15.w),
                    Expanded(
                        flex: 1,
                        child: _buildTextField(_stateController, 'Estado (UF)',
                            PhosphorIcons.map_pin, inputFormatters: [
                          LengthLimitingTextInputFormatter(2)
                        ])),
                  ],
                ),
                SizedBox(height: 30.h),
                Text('Tutores (${_currentTutors.length})', style: titleStyle),
                SizedBox(height: 15.h),
                _buildTutorList(),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
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
          label: const Text('Salvar Alterações'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
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

  Widget _buildAvatarSection() {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    ImageProvider? bgImage;
    Widget? childContent;

    if (_newProfileImageBytes != null) {
      bgImage = MemoryImage(_newProfileImageBytes!);
    } else {
      childContent = FutureBuilder<Uint8List?>(
        future: _studentService.getStudentPhoto(widget.student.id, token),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white);
          }
          if (snapshot.hasData && snapshot.data != null) {
            return ClipOval(
              child: Image.memory(
                snapshot.data!,
                width: 100.r * 2,
                height: 100.r * 2,
                fit: BoxFit.cover,
              ),
            );
          }
          String initials = widget.student.fullName.isNotEmpty
              ? widget.student.fullName.trim().substring(0, 1).toUpperCase()
              : '?';
          return Text(
            initials,
            style: GoogleFonts.saira(
              fontSize: 40.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: _pickImage,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100,
                border: Border.all(color: Colors.blue.shade200, width: 2),
                image: bgImage != null
                    ? DecorationImage(image: bgImage, fit: BoxFit.cover)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: bgImage == null ? childContent : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(PhosphorIcons.camera_fill,
                    color: Colors.white, size: 20.sp),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTutorList() {
    if (_currentTutors.isEmpty) {
      return Container(
          width: double.infinity,
          padding: EdgeInsets.all(15.w),
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.r)),
          child: Text('Nenhum tutor associado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey.shade700)));
    }

    return Column(
      children: _currentTutors
          .map((tutorLink) => Card(
                elevation: 0,
                margin: EdgeInsets.only(bottom: 10.h),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: Icon(PhosphorIcons.user,
                        color: Colors.deepPurple.shade600, size: 20.sp),
                  ),
                  title: Text(
                      tutorLink.tutorInfo.fullName ?? 'Nome não informado',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${tutorLink.relationship} • CPF: ${tutorLink.tutorInfo.cpf ?? 'N/A'}',
                      style: GoogleFonts.inter(fontSize: 13.sp)),
                  trailing: IconButton(
                    icon: Icon(PhosphorIcons.pencil_simple_line,
                        color: Colors.blue.shade700, size: 20.sp),
                    onPressed: () => _openTutorEditDialog(tutorLink),
                    tooltip: 'Editar Tutor',
                  ),
                ),
              ))
          .toList(),
    );
  }

  InputDecoration buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20.sp, color: const Color(0xFF007AFF)),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
      labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: buildInputDecoration(label, icon).copyWith(
          fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50),
      style: GoogleFonts.inter(
          color: readOnly ? Colors.grey.shade700 : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 15.sp),
      validator: (value) {
        if (label.contains('*') && (value == null || value.trim().isEmpty)) {
          return 'Campo obrigatório';
        }
        if (validator != null) {
          return validator(value);
        }
        return null;
      },
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: buildInputDecoration('Gênero', PhosphorIcons.gender_intersex),
      style: GoogleFonts.inter(
          color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 15.sp),
      items: _genderOptions
          .map((gender) => DropdownMenuItem(
                value: gender,
                child: Text(gender),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
        });
      },
      isExpanded: true,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(10.r),
    );
  }
}
