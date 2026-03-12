import 'dart:async';
import 'dart:typed_data';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/providers/school_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// --- OVERLAY DE SUCESSO (Adaptado) ---
class SchoolUpdateOverlay extends StatefulWidget {
  final VoidCallback onRemove;
  const SchoolUpdateOverlay({super.key, required this.onRemove});

  @override
  State<SchoolUpdateOverlay> createState() => _SchoolUpdateOverlayState();
}

class _SchoolUpdateOverlayState extends State<SchoolUpdateOverlay>
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
    await _controller.reverse();
    widget.onRemove();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Positioned(
      bottom: 30.h,
      right: 30.w,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Container(
            width: 380.w,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ],
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(PhosphorIcons.check_circle_fill,
                      color: Colors.greenAccent.shade700, size: 24.sp),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Sucesso!',
                          style: GoogleFonts.sairaCondensed(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp)),
                      SizedBox(height: 4.h),
                      Text('Informações atualizadas.',
                          style: GoogleFonts.inter(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade600,
                              fontSize: 14.sp),
                          maxLines: 2),
                    ],
                  ),
                ),
                IconButton(
                    icon: Icon(Icons.close,
                        color: isDark ? Colors.white54 : Colors.black54,
                        size: 18),
                    onPressed: _close),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Tela Principal ---

class SchoolSettingsScreen extends StatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  State<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends State<SchoolSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers Básicos
  final _nameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _stateRegController = TextEditingController();
  final _munRegController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();

  // Controllers Mercado Pago
  final _mpAccessTokenController = TextEditingController();
  final _mpPublicKeyController = TextEditingController();
  final _mpClientIdController = TextEditingController();
  final _mpClientSecretController = TextEditingController();

  // Estado visual
  Uint8List? _localLogoBytes;
  XFile? _selectedLogoFile;
  bool _obscureMpSecrets = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialFetch();
    });
  }

  void _initialFetch() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);

    if (auth.user?.schoolId != null) {
      await schoolProvider.loadSchoolData(auth.user!.schoolId, auth.token!);
      _populateControllers(schoolProvider);
    }
  }

  void _populateControllers(SchoolProvider provider) {
    if (provider.school == null) return;
    final s = provider.school!;

    _nameController.text = s.name;
    _legalNameController.text = s.legalName;
    _cnpjController.text = s.cnpj ?? '';
    _stateRegController.text = s.stateRegistration ?? '';
    _munRegController.text = s.municipalRegistration ?? '';
    _phoneController.text = s.contactPhone ?? '';
    _emailController.text = s.contactEmail ?? '';

    if (s.address != null) {
      _streetController.text = s.address!.street;
      _numberController.text = s.address!.number;
      _districtController.text = s.address!.district;
      _cityController.text = s.address!.city;
      _stateController.text = s.address!.state;
      _zipController.text = s.address!.zipCode;
    }

    if (s.mercadoPagoConfig != null) {
      _mpPublicKeyController.text = s.mercadoPagoConfig!.prodPublicKey ?? '';
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedLogoFile = image;
          _localLogoBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("❌ Erro ao selecionar imagem: $e");
    }
  }

  void _showSuccessOverlay() {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => SchoolUpdateOverlay(
        onRemove: () {
          overlayEntry.remove();
        },
      ),
    );
    Overlay.of(context).insert(overlayEntry);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);

    final Map<String, String> data = {
      'name': _nameController.text,
      'legalName': _legalNameController.text,
      'cnpj': _cnpjController.text,
      'stateRegistration': _stateRegController.text,
      'municipalRegistration': _munRegController.text,
      'contactPhone': _phoneController.text,
      'contactEmail': _emailController.text,
      'address[street]': _streetController.text,
      'address[number]': _numberController.text,
      'address[neighborhood]': _districtController.text,
      'address[city]': _cityController.text,
      'address[state]': _stateController.text,
      'address[cep]': _zipController.text,
    };

    if (_mpAccessTokenController.text.isNotEmpty) {
      data['mercadoPagoConfig[prodAccessToken]'] =
          _mpAccessTokenController.text;
    }
    if (_mpPublicKeyController.text.isNotEmpty) {
      data['mercadoPagoConfig[prodPublicKey]'] = _mpPublicKeyController.text;
    }
    if (_mpClientIdController.text.isNotEmpty) {
      data['mercadoPagoConfig[prodClientId]'] = _mpClientIdController.text;
    }
    if (_mpClientSecretController.text.isNotEmpty) {
      data['mercadoPagoConfig[prodClientSecret]'] =
          _mpClientSecretController.text;
    }

    final success = await schoolProvider.updateSchoolData(
      schoolId: auth.user!.schoolId,
      token: auth.token!,
      formFields: data,
      newLogo: _selectedLogoFile,
    );

    if (success && mounted) {
      _showSuccessOverlay();
      setState(() {
        _selectedLogoFile = null;
        _localLogoBytes = null;
        _mpAccessTokenController.clear();
        _mpClientSecretController.clear();
        _mpClientIdController.clear();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Erro ao atualizar."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Captura do Tema
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : const Color(0xff777F85);
    final btnBg = isDark ? Colors.grey[800] : Colors.black;

    return Consumer<SchoolProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
                left: 50.sp, right: 50.sp, top: 20.h, bottom: 50.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Minha Escola",
                                  style: GoogleFonts.sairaCondensed(
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                      fontSize: 54.sp))
                              .animate()
                              .fadeIn()
                              .moveX(begin: -10),
                          Text("Gerencie as informações institucionais",
                                  style: GoogleFonts.ubuntu(
                                      fontWeight: FontWeight.w800,
                                      height: -0.4.sp,
                                      color: subTextColor,
                                      fontSize: 24.sp))
                              .animate()
                              .fadeIn()
                              .moveX(begin: -10),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: provider.isSaving ? null : _submit,
                        icon: provider.isSaving
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(PhosphorIcons.floppy_disk,
                                color: Colors.white),
                        label: Text(
                            provider.isSaving
                                ? "Salvando..."
                                : "Salvar Alterações",
                            style: GoogleFonts.inter(
                                fontSize: 16.sp, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: btnBg,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: Colors.black.withOpacity(0.3),
                          padding: EdgeInsets.symmetric(
                              horizontal: 30.w, vertical: 20.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r)),
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),
                  SizedBox(height: 40.h),

                  // --- GRID DE CONTEÚDO ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // COLUNA DA ESQUERDA
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildSectionCard(
                              title: "Identificação",
                              icon: PhosphorIcons.identification_card,
                              delay: 100,
                              isDark: isDark,
                              children: [
                                _buildTextField(
                                    "Nome Fantasia", _nameController,
                                    icon: PhosphorIcons.buildings,
                                    isDark: isDark),
                                SizedBox(height: 20.h),
                                _buildTextField(
                                    "Razão Social", _legalNameController,
                                    icon: PhosphorIcons.article,
                                    isDark: isDark),
                                SizedBox(height: 20.h),
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildTextField(
                                            "CNPJ", _cnpjController,
                                            isDark: isDark)),
                                    SizedBox(width: 20.w),
                                    Expanded(
                                        child: _buildTextField("Insc. Estadual",
                                            _stateRegController,
                                            isDark: isDark)),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 30.h),
                            _buildSectionCard(
                              title: "Contato",
                              icon: PhosphorIcons.phone,
                              delay: 200,
                              isDark: isDark,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildTextField(
                                            "Telefone", _phoneController,
                                            icon: PhosphorIcons.phone_call,
                                            isDark: isDark)),
                                    SizedBox(width: 20.w),
                                    Expanded(
                                        child: _buildTextField(
                                            "E-mail", _emailController,
                                            icon: PhosphorIcons.envelope_simple,
                                            isDark: isDark)),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: 30.h),

                            // --- SEÇÃO MERCADO PAGO ---
                            _buildSectionCard(
                              title: "Pagamento (Mercado Pago)",
                              icon: PhosphorIcons.credit_card,
                              delay: 300,
                              isDark: isDark,
                              children: [
                                _buildWarningBox(isDark),
                                SizedBox(height: 20.h),

                                // Toggle
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => setState(() =>
                                          _obscureMpSecrets =
                                              !_obscureMpSecrets),
                                      icon: Icon(
                                          _obscureMpSecrets
                                              ? PhosphorIcons.eye
                                              : PhosphorIcons.eye_slash,
                                          size: 18,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.blue),
                                      label: Text(
                                          _obscureMpSecrets
                                              ? "Mostrar Credenciais"
                                              : "Ocultar Credenciais",
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.blue)),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),

                                _buildTextField("Access Token (Produção)",
                                    _mpAccessTokenController,
                                    icon: PhosphorIcons.key,
                                    isPassword: _obscureMpSecrets,
                                    hintText:
                                        "Deixe em branco para manter o atual",
                                    isDark: isDark),
                                SizedBox(height: 20.h),
                                _buildTextField(
                                    "Public Key", _mpPublicKeyController,
                                    icon: PhosphorIcons.lock_key_open,
                                    hintText: "Ex: APP_USR-...",
                                    isDark: isDark),
                                SizedBox(height: 20.h),
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildTextField(
                                            "Client ID", _mpClientIdController,
                                            isPassword: _obscureMpSecrets,
                                            hintText: "Opcional",
                                            isDark: isDark)),
                                    SizedBox(width: 20.w),
                                    Expanded(
                                        child: _buildTextField("Client Secret",
                                            _mpClientSecretController,
                                            isPassword: _obscureMpSecrets,
                                            hintText: "Opcional",
                                            isDark: isDark)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 30.w),

                      // COLUNA DA DIREITA
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            // CARD LOGO
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(24.w),
                              decoration: _boxDecoration(isDark, theme),
                              child: Column(
                                children: [
                                  Text("Logotipo",
                                      style: GoogleFonts.inter(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                          color: textColor)),
                                  SizedBox(height: 20.h),
                                  GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      width: 150.w,
                                      height: 150.w,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey.shade50,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5))
                                        ],
                                        border: Border.all(
                                            color: isDark
                                                ? Colors.grey[700]!
                                                : Colors.grey.shade200,
                                            width: 4),
                                        image: _getImageProvider(provider),
                                      ),
                                      child: _hasImage(provider)
                                          ? null
                                          : Icon(PhosphorIcons.image,
                                              size: 50.sp,
                                              color: Colors.grey.shade400),
                                    ),
                                  ),
                                  SizedBox(height: 15.h),
                                  TextButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(
                                        PhosphorIcons.upload_simple,
                                        size: 20),
                                    label: const Text("Alterar Imagem"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blueAccent,
                                      textStyle: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  )
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 300.ms)
                                .moveY(begin: 20, end: 0),

                            SizedBox(height: 30.h),

                            _buildSectionCard(
                              title: "Endereço",
                              icon: PhosphorIcons.map_pin,
                              delay: 400,
                              isDark: isDark,
                              children: [
                                Row(children: [
                                  Expanded(
                                      flex: 2,
                                      child: _buildTextField(
                                          "CEP", _zipController,
                                          isDark: isDark)),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                      child: _buildTextField(
                                          "UF", _stateController,
                                          isDark: isDark)),
                                ]),
                                SizedBox(height: 15.h),
                                Row(children: [
                                  Expanded(
                                      child: _buildTextField(
                                          "Cidade", _cityController,
                                          isDark: isDark)),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                      child: _buildTextField(
                                          "Bairro", _districtController,
                                          isDark: isDark)),
                                ]),
                                SizedBox(height: 15.h),
                                Row(children: [
                                  Expanded(
                                      flex: 3,
                                      child: _buildTextField(
                                          "Rua", _streetController,
                                          isDark: isDark)),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                      child: _buildTextField(
                                          "Nº", _numberController,
                                          isDark: isDark)),
                                ]),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Helpers Visuais ---

  Widget _buildWarningBox(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
            color: isDark ? Colors.red.withOpacity(0.3) : Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIcons.warning_octagon_fill,
              color: Colors.red.shade700, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Atenção: Configuração Sensível",
                  style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900),
                ),
                SizedBox(height: 4.h),
                Text(
                  "Alterar estas credenciais pode interromper imediatamente o recebimento de pagamentos da sua escola. Só modifique se tiver certeza e com o apoio técnico.",
                  style: GoogleFonts.inter(
                      fontSize: 13.sp, color: Colors.red.shade800, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Decoration _boxDecoration(bool isDark, ThemeData theme) {
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16.r),
      boxShadow: [
        BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4)),
      ],
    );
  }

  DecorationImage? _getImageProvider(SchoolProvider provider) {
    ImageProvider? image;
    if (_localLogoBytes != null) {
      image = MemoryImage(_localLogoBytes!);
    } else {
      final url = provider.currentLogoUrl;
      if (url != null) {
        image = NetworkImage(url);
      }
    }
    if (image != null) return DecorationImage(image: image, fit: BoxFit.cover);
    return null;
  }

  bool _hasImage(SchoolProvider provider) =>
      _localLogoBytes != null || provider.currentLogoUrl != null;

  Widget _buildSectionCard(
      {required String title,
      required IconData icon,
      required List<Widget> children,
      int delay = 0,
      required bool isDark}) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.grey[800]! : Colors.grey.shade100;

    return Container(
      padding: EdgeInsets.all(30.w),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
                color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24.sp, color: textColor),
              SizedBox(width: 12.w),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ],
          ),
          Divider(height: 40.h, color: dividerColor),
          ...children,
        ],
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms)
        .moveY(begin: 20, end: 0, curve: Curves.easeOut);
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {IconData? icon,
      bool isPassword = false,
      String? hintText,
      required bool isDark}) {
    final fillColor = isDark ? Colors.grey[900] : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[500] : Colors.grey.shade400;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: labelColor)),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.inter(
              fontSize: 15.sp, fontWeight: FontWeight.w500, color: textColor),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: hintColor),
            prefixIcon:
                icon != null ? Icon(icon, size: 20.sp, color: hintColor) : null,
            filled: true,
            fillColor: fillColor,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(
                    color: isDark ? Colors.blueAccent : Colors.black,
                    width: 1.5)),
          ),
          validator: (value) {
            if (controller == _mpAccessTokenController ||
                controller == _mpPublicKeyController ||
                controller == _mpClientIdController ||
                controller == _mpClientSecretController) {
              return null;
            }
            return (value == null || value.isEmpty) ? "Obrigatório" : null;
          },
        ),
      ],
    );
  }
}
