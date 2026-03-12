import 'package:academyhub_mobile/services/public_registration_service.dart';
import 'package:academyhub_mobile/util/cidades_ibge.dart';
// import 'package:academyhub_mobile/services/location_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class PublicRegistrationScreen extends StatefulWidget {
  final String schoolId;

  const PublicRegistrationScreen({super.key, required this.schoolId});

  @override
  State<PublicRegistrationScreen> createState() =>
      _PublicRegistrationScreenState();
}

class _PublicRegistrationScreenState extends State<PublicRegistrationScreen> {
  final PublicRegistrationService _service = PublicRegistrationService();
  final LocationService _locationService = LocationService();

  // --- Controle de Fluxo ---
  // 0: Triagem
  // 1: Aluno (Dados Pessoais)
  // 2: Endereço
  // 3: Saúde (NOVO)
  // 4: Tutor (Condicional para Menores)
  // 5: Sucesso
  int _currentStep = 0;
  String? _registrationType; // 'ADULT_STUDENT' ou 'MINOR_STUDENT'

  // Chaves de Formulário
  final _formKeyStudent = GlobalKey<FormState>();
  final _formKeyAddress = GlobalKey<FormState>();
  final _formKeyHealth = GlobalKey<FormState>(); // NOVO
  final _formKeyTutor = GlobalKey<FormState>();

  bool _isLoading = false;

  // --- Controllers Aluno ---
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();
  final _cpfController = TextEditingController();
  final _rgController = TextEditingController(); // NOVO
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _gender = 'Masculino';
  String _race = 'Branca';
  String _nationality = 'Brasileira';

  // --- Controllers Endereço ---
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _zipController = TextEditingController();
  final _complementController = TextEditingController(); // NOVO
  StateModel? _selectedState;
  CityModel? _selectedCity;
  List<StateModel> _states = [];
  List<CityModel> _cities = [];

  // --- Controllers Saúde (NOVO) ---
  bool _hasHealthProblem = false;
  final _healthProblemDetails = TextEditingController();
  bool _takesMedication = false;
  final _medicationDetails = TextEditingController();
  bool _hasAllergy = false;
  final _allergyDetails = TextEditingController();
  final _feverMedication = TextEditingController(); // Importante para crianças
  final _foodObservations = TextEditingController();

  // --- Controllers Tutor ---
  final _tutorNameController = TextEditingController();
  final _tutorCpfController = TextEditingController();
  final _tutorRgController = TextEditingController(); // NOVO
  final _tutorPhoneController = TextEditingController();
  final _tutorEmailController = TextEditingController(); // NOVO
  final _tutorBirthController = TextEditingController(); // NOVO
  final _tutorRelationController = TextEditingController();

  // --- Máscaras ---
  final _dateMask = MaskTextInputFormatter(
      mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
  final _phoneMask = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _zipMask = MaskTextInputFormatter(
      mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _fetchStates();
  }

  Future<void> _fetchStates() async {
    try {
      final states = await _locationService.fetchStates();
      setState(() => _states = states);
    } catch (e) {
      debugPrint("Erro location: $e");
    }
  }

  Future<void> _fetchCities(StateModel state) async {
    try {
      final cities = await _locationService.fetchCities(state.id);
      setState(() {
        _cities = cities;
        _selectedCity = null;
      });
    } catch (e) {
      debugPrint("Erro cities: $e");
    }
  }

  // --- Lógica de Navegação ---
  void _nextStep() {
    if (_currentStep == 1 && !_formKeyStudent.currentState!.validate()) return;
    if (_currentStep == 2 && !_formKeyAddress.currentState!.validate()) return;
    if (_currentStep == 3 && !_formKeyHealth.currentState!.validate()) return;
    if (_currentStep == 4 && !_formKeyTutor.currentState!.validate()) return;

    // Lógica de Pulo
    if (_currentStep == 3 && _registrationType == 'ADULT_STUDENT') {
      // Se é adulto, pula etapa 4 (Tutor) e envia
      _submitForm();
    } else if (_currentStep == 4 && _registrationType == 'MINOR_STUDENT') {
      // Se é menor, envia após etapa 4
      _submitForm();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submitForm() async {
    setState(() => _isLoading = true);

    try {
      // 1. Monta Address
      final addressData = {
        'street': _streetController.text,
        'number': _numberController.text,
        'neighborhood': _neighborhoodController.text,
        'zipCode': _zipController.text,
        'complement': _complementController.text,
        'city': _selectedCity?.nome,
        'state': _selectedState?.sigla,
      };

      // 2. Monta HealthInfo
      final healthInfoData = {
        'hasHealthProblem': _hasHealthProblem,
        'healthProblemDetails': _healthProblemDetails.text,
        'takesMedication': _takesMedication,
        'medicationDetails': _medicationDetails.text,
        'hasAllergy': _hasAllergy,
        'allergyDetails': _allergyDetails.text,
        'feverMedication': _feverMedication.text,
        'foodObservations': _foodObservations.text,
        // Adicione outros campos booleanos se necessário
      };

      // 3. Monta Payload Final
      final payload = {
        'school_id': widget.schoolId,
        'registrationType': _registrationType,
        'studentData': {
          'fullName': _nameController.text,
          'birthDate': _parseDate(_birthController.text),
          'cpf': _cpfController.text,
          'rg': _rgController.text,
          'phoneNumber': _phoneController.text,
          'email': _emailController.text,
          'gender': _gender,
          'race': _race,
          'nationality': _nationality,
          'address': addressData,
          'healthInfo': healthInfoData, // AGORA INCLUSO
          'authorizedPickups':
              [], // Pode ser adicionado numa etapa extra se quiser
        },
        'tutorData': _registrationType == 'MINOR_STUDENT'
            ? {
                'fullName': _tutorNameController.text,
                'cpf': _tutorCpfController.text,
                'rg': _tutorRgController.text,
                'birthDate': _parseDate(_tutorBirthController.text),
                'phoneNumber': _tutorPhoneController.text,
                'email': _tutorEmailController.text,
                'relationship': _tutorRelationController.text,
                'nationality': 'Brasileira', // Default ou input
                'gender': 'Outro', // Default ou input
                'address': addressData, // Assume mesmo endereço por padrão
              }
            : null
      };

      await _service.submitRegistrationRequest(payload);

      setState(() => _currentStep = 5); // Tela Sucesso (índice 5)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Erro: ${e.toString()}"),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _parseDate(String date) {
    try {
      return DateFormat('dd/MM/yyyy').parse(date).toIso8601String();
    } catch (e) {
      return null;
    }
  }

  // --- BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            if (_currentStep < 5) _buildHeader(),
            Expanded(child: _buildBody()),
            if (_currentStep > 0 && _currentStep < 5) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Barra de progresso baseada em 4 etapas (Triagem, Aluno, Endereço, Saúde, Tutor?)
    double progress = _currentStep / 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
                icon: Icon(Icons.arrow_back_ios, size: 20.sp),
                onPressed: _prevStep,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints()),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pré-Matrícula Online",
                    style: GoogleFonts.leagueSpartan(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                SizedBox(height: 4.h),
                LinearProgressIndicator(
                  value: progress > 1.0 ? 1.0 : progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case 0:
        return _buildStepTriagem();
      case 1:
        return _buildStepStudent();
      case 2:
        return _buildStepAddress();
      case 3:
        return _buildStepHealth(); // NOVA TELA
      case 4:
        return _buildStepTutor();
      case 5:
        return _buildSuccessScreen();
      default:
        return Container();
    }
  }

  // --- ETAPAS DO WIZARD ---

  // 0. TRIAGEM
  Widget _buildStepTriagem() {
    return Padding(
      padding: EdgeInsets.all(25.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.student_fill, size: 60.sp, color: Colors.indigo),
          SizedBox(height: 20.h),
          Text("Bem-vindo!",
              style: GoogleFonts.leagueSpartan(
                  fontSize: 28.sp, fontWeight: FontWeight.bold)),
          Text("Para agilizar sua matrícula, preencha os dados a seguir.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16.sp, color: Colors.grey.shade600)),
          SizedBox(height: 40.h),
          _buildOptionCard(
            title: "Sou o Aluno (Maior de 18)",
            subtitle: "Responsável pela própria matrícula.",
            icon: PhosphorIcons.user,
            onTap: () => setState(() {
              _registrationType = 'ADULT_STUDENT';
              _currentStep = 1;
            }),
          ),
          SizedBox(height: 20.h),
          _buildOptionCard(
            title: "Sou Pai / Responsável",
            subtitle: "Matriculando um menor de idade.",
            icon: PhosphorIcons.users_three,
            onTap: () => setState(() {
              _registrationType = 'MINOR_STUDENT';
              _currentStep = 1;
            }),
          ),
        ],
      ),
    );
  }

  // 1. ALUNO
  Widget _buildStepStudent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyStudent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle("Dados do Aluno"),
            _buildTextField("Nome Completo *", _nameController,
                icon: PhosphorIcons.user),
            SizedBox(height: 15.h),
            _buildTextField("Data de Nascimento *", _birthController,
                icon: PhosphorIcons.calendar,
                mask: _dateMask,
                keyboardType: TextInputType.number),
            SizedBox(height: 15.h),
            _buildTextField("CPF (Obrigatório p/ Maior)", _cpfController,
                icon: PhosphorIcons.identification_card,
                mask: _cpfMask,
                keyboardType: TextInputType.number,
                isRequired: _registrationType == 'ADULT_STUDENT'),
            SizedBox(height: 15.h),
            _buildTextField("RG (Opcional)", _rgController,
                icon: PhosphorIcons.identification_badge, isRequired: false),
            SizedBox(height: 15.h),
            _buildTextField("Celular/WhatsApp *", _phoneController,
                icon: PhosphorIcons.whatsapp_logo,
                mask: _phoneMask,
                keyboardType: TextInputType.phone),
            SizedBox(height: 15.h),
            _buildTextField("E-mail (Opcional)", _emailController,
                icon: PhosphorIcons.envelope,
                keyboardType: TextInputType.emailAddress,
                isRequired: false),
            SizedBox(height: 15.h),
            Row(
              children: [
                Expanded(
                    child: _buildDropdown(
                        "Gênero",
                        _gender,
                        ["Masculino", "Feminino", "Outro"],
                        (v) => setState(() => _gender = v!))),
                SizedBox(width: 15.w),
                Expanded(
                    child: _buildDropdown(
                        "Raça",
                        _race,
                        ["Branca", "Preta", "Parda", "Outro"],
                        (v) => setState(() => _race = v!))),
              ],
            )
          ],
        ),
      ),
    );
  }

  // 2. ENDEREÇO
  Widget _buildStepAddress() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyAddress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle("Endereço Residencial"),
            _buildTextField("CEP *", _zipController,
                icon: PhosphorIcons.map_pin,
                mask: _zipMask,
                keyboardType: TextInputType.number),
            SizedBox(height: 15.h),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField2<StateModel>(
                    decoration:
                        _inputDecoration("UF", PhosphorIcons.map_trifold),
                    items: _states
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e.sigla)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedState = val);
                      _fetchCities(val!);
                    },
                    value: _selectedState,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField2<CityModel>(
                    decoration:
                        _inputDecoration("Cidade", PhosphorIcons.buildings),
                    items: _cities
                        .map((e) => DropdownMenuItem(
                            value: e,
                            child:
                                Text(e.nome, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCity = val),
                    value: _selectedCity,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15.h),
            _buildTextField("Rua / Logradouro *", _streetController,
                icon: PhosphorIcons.map_pin),
            SizedBox(height: 15.h),
            Row(
              children: [
                Expanded(
                    flex: 3,
                    child: _buildTextField("Bairro *", _neighborhoodController,
                        icon: PhosphorIcons.house_line)),
                SizedBox(width: 10.w),
                Expanded(
                    flex: 2,
                    child: _buildTextField("Número *", _numberController,
                        icon: PhosphorIcons.hash)),
              ],
            ),
            SizedBox(height: 15.h),
            _buildTextField("Complemento", _complementController,
                icon: PhosphorIcons.info, isRequired: false),
          ],
        ),
      ),
    );
  }

  // 3. SAÚDE (NOVO)
  Widget _buildStepHealth() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyHealth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle("Ficha de Saúde"),
            Text("Informações cruciais para a segurança do aluno.",
                style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20.h),
            _buildSwitchTile("Possui problema de saúde?", _hasHealthProblem,
                (v) => setState(() => _hasHealthProblem = v)),
            if (_hasHealthProblem)
              _buildTextField("Qual problema?", _healthProblemDetails,
                  icon: PhosphorIcons.heartbeat),
            SizedBox(height: 15.h),
            _buildSwitchTile("Toma medicamento controlado?", _takesMedication,
                (v) => setState(() => _takesMedication = v)),
            if (_takesMedication)
              _buildTextField("Qual medicamento/dosagem?", _medicationDetails,
                  icon: PhosphorIcons.pill),
            SizedBox(height: 15.h),
            _buildSwitchTile("Possui alergias?", _hasAllergy,
                (v) => setState(() => _hasAllergy = v)),
            if (_hasAllergy)
              _buildTextField("Quais alergias?", _allergyDetails,
                  icon: PhosphorIcons.warning),
            SizedBox(height: 20.h),
            _buildTextField(
                "Remédio para Febre (Se necessário) *", _feverMedication,
                icon: PhosphorIcons.thermometer),
            SizedBox(height: 15.h),
            _buildTextField(
                "Restrições Alimentares / Observações", _foodObservations,
                icon: PhosphorIcons.fork_knife, isRequired: false, maxLines: 3),
          ],
        ),
      ),
    );
  }

  // 4. TUTOR
  Widget _buildStepTutor() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKeyTutor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle("Dados do Responsável"),
            Text("Quem assinará o contrato e será o responsável financeiro.",
                style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20.h),
            _buildTextField("Nome Completo *", _tutorNameController,
                icon: PhosphorIcons.user_gear),
            SizedBox(height: 15.h),
            _buildTextField("CPF *", _tutorCpfController,
                icon: PhosphorIcons.identification_card,
                mask: _cpfMask,
                keyboardType: TextInputType.number),
            SizedBox(height: 15.h),
            _buildTextField("RG (Opcional)", _tutorRgController,
                icon: PhosphorIcons.identification_badge, isRequired: false),
            SizedBox(height: 15.h),
            _buildTextField("Data de Nascimento *", _tutorBirthController,
                icon: PhosphorIcons.calendar,
                mask: _dateMask,
                keyboardType: TextInputType.number),
            SizedBox(height: 15.h),
            _buildTextField("Celular *", _tutorPhoneController,
                icon: PhosphorIcons.whatsapp_logo,
                mask: _phoneMask,
                keyboardType: TextInputType.phone),
            SizedBox(height: 15.h),
            _buildTextField("E-mail *", _tutorEmailController,
                icon: PhosphorIcons.envelope,
                keyboardType: TextInputType.emailAddress),
            SizedBox(height: 15.h),
            _buildDropdown(
                "Grau de Parentesco",
                _tutorRelationController.text.isEmpty
                    ? "Mãe"
                    : _tutorRelationController.text,
                ["Mãe", "Pai", "Avó/Avô", "Tio/Tia", "Outro"],
                (v) => _tutorRelationController.text = v!),
          ],
        ),
      ),
    );
  }

  // 5. SUCESSO
  Widget _buildSuccessScreen() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(PhosphorIcons.check_circle_fill,
                  size: 80.sp, color: Colors.green),
            ),
            SizedBox(height: 30.h),
            Text("Tudo Certo!",
                style: GoogleFonts.leagueSpartan(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            SizedBox(height: 10.h),
            Text(
                "Seus dados foram enviados para a secretaria. Entraremos em contato em breve para confirmar a matrícula.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 16.sp, color: Colors.grey.shade600)),
            SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r))),
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/'),
                child: Text("Voltar ao Início",
                    style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- COMPONENTES REUTILIZÁVEIS ---

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: SizedBox(
        width: double.infinity,
        height: 55.h,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
          ),
          onPressed: _isLoading ? null : _nextStep,
          child: _isLoading
              ? CircularProgressIndicator(color: Colors.white)
              : Text(
                  (_currentStep == 3 && _registrationType == 'ADULT_STUDENT') ||
                          _currentStep == 4
                      ? "FINALIZAR E ENVIAR"
                      : "CONTINUAR",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _stepTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Text(text,
          style: GoogleFonts.leagueSpartan(
              fontSize: 22.sp, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOptionCard(
      {required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: Colors.indigo.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.indigo.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(icon, color: Colors.indigo, size: 24.sp),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 16.sp)),
                  SizedBox(height: 4.h),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 13.sp, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: Colors.indigo, size: 22.sp),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.indigo, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.red.shade300)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.red, width: 2)),
      contentPadding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 15.w),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {required IconData icon,
      TextInputFormatter? mask,
      TextInputType? keyboardType,
      bool isRequired = true,
      int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: mask != null ? [mask] : [],
      decoration: _inputDecoration(label, icon),
      validator: (val) {
        if (isRequired && (val == null || val.isEmpty))
          return 'Campo obrigatório';
        if (label.contains('E-mail') && val!.isNotEmpty && !val.contains('@'))
          return 'E-mail inválido';
        return null;
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return DropdownButtonFormField2<String>(
      decoration: _inputDecoration(label, PhosphorIcons.caret_down),
      value: value,
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.indigo,
      contentPadding: EdgeInsets.zero,
    );
  }
}
