import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Seus imports de model e provider
import '../../../model/expense_model.dart';
import '../../../model/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../popup/transaction_success_popup.dart';
// Certifique-se de ter esse utilitário ou remova o formatter se não tiver
import '../../../util/currency_formatter.dart';

class ExpenseFormSheet extends StatefulWidget {
  final Expense? existingExpense;
  const ExpenseFormSheet({super.key, this.existingExpense});

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  DateTime _dueDate = DateTime.now();
  int _refMonth = DateTime.now().month;
  int _refYear = DateTime.now().year;

  String _selectedCategory = 'Outros';
  String _selectedStatus = 'pending';
  String? _selectedStaffId;
  String _selectedStaffName = "";

  bool _isLoading = false;
  bool _isManualDescription = false;

  final List<String> _categories = [
    'Aluguel',
    'Energia',
    'Água',
    'Internet',
    'Pessoal',
    'Manutenção',
    'Marketing',
    'Impostos',
    'Vale/Adiantamento',
    'Outros'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<UserProvider>(context, listen: false).fetchUsers(auth.token!);
    });

    if (widget.existingExpense != null) {
      final e = widget.existingExpense!;
      _descController.text = e.description;
      _amountController.text = _currencyFormat.format(e.amount);
      _dueDate = e.date;
      // .trim() aqui corrige o bug do ícone se o banco tiver espaços extras
      _selectedCategory = _categories.contains(e.category.trim())
          ? e.category.trim()
          : 'Outros';
      _selectedStatus = e.status;
      _selectedStaffId = e.relatedStaff;
      _isManualDescription = true;
      _refMonth = e.date.month;
      _refYear = e.date.year;
    } else {
      _updateAutoDescription();
    }
  }

  // Lógica de Ícones corrigida para ser robusta
  _CategoryStyle _getCategoryStyle(String category, bool isDark) {
    Color getBg(Color base) =>
        isDark ? base.withOpacity(0.15) : base.withOpacity(0.1);

    // Normalização para evitar erros de string
    final cleanCat = category.trim();

    switch (cleanCat) {
      case 'Energia':
        return _CategoryStyle(PhosphorIcons.lightning_fill, Colors.amber[700]!,
            getBg(Colors.amber));
      case 'Água':
        return _CategoryStyle(
            PhosphorIcons.drop_fill, Colors.blue[600]!, getBg(Colors.blue));
      case 'Internet':
        return _CategoryStyle(PhosphorIcons.wifi_high_bold, Colors.cyan[600]!,
            getBg(Colors.cyan));
      case 'Pessoal':
        return _CategoryStyle(PhosphorIcons.users_three_fill,
            Colors.purple[600]!, getBg(Colors.purple));
      case 'Vale/Adiantamento':
        return _CategoryStyle(PhosphorIcons.hand_soap_fill,
            Colors.redAccent[700]!, getBg(Colors.red));
      case 'Aluguel':
        return _CategoryStyle(PhosphorIcons.house_line_fill,
            Colors.indigo[600]!, getBg(Colors.indigo));
      case 'Manutenção':
        return _CategoryStyle(
            PhosphorIcons.wrench_fill, Colors.brown[600]!, getBg(Colors.brown));
      case 'Marketing':
        return _CategoryStyle(PhosphorIcons.megaphone_fill, Colors.pink[600]!,
            getBg(Colors.pink));
      case 'Impostos':
        return _CategoryStyle(PhosphorIcons.bank_fill, Colors.blueGrey[700]!,
            getBg(Colors.blueGrey));
      default:
        return _CategoryStyle(
            PhosphorIcons.tag_fill,
            isDark ? Colors.grey[400]! : Colors.grey[600]!,
            isDark ? Colors.grey[800]! : Colors.grey[200]!);
    }
  }

  void _updateAutoDescription() {
    if (_isManualDescription) return;
    String monthStr = _refMonth.toString().padLeft(2, '0');
    if (_selectedCategory == 'Vale/Adiantamento') {
      if (_selectedStaffName.isNotEmpty) {
        String firstName = _selectedStaffName.split(' ')[0];
        _descController.text =
            "Adiantamento - $firstName ($monthStr/$_refYear)";
      } else {
        _descController.text = "Adiantamento Salarial ($monthStr/$_refYear)";
      }
    } else {
      _descController.text = "$_selectedCategory - ref. $monthStr/$_refYear";
    }
  }

  double _parseCurrency(String text) {
    String cleanText =
        text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
    return double.tryParse(cleanText) ?? 0.0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == 'Vale/Adiantamento' && _selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Selecione o funcionário."),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final provider = Provider.of<ExpenseProvider>(context, listen: false);

      final double amount = _parseCurrency(_amountController.text);
      final finalDate = _selectedCategory == 'Vale/Adiantamento'
          ? DateTime(_refYear, _refMonth, DateTime.now().day)
          : _dueDate;

      final expense = Expense(
        id: widget.existingExpense?.id,
        description: _descController.text,
        amount: amount,
        date: finalDate,
        category: _selectedCategory,
        status:
            _selectedCategory == 'Vale/Adiantamento' ? 'paid' : _selectedStatus,
        relatedStaff:
            _selectedCategory == 'Vale/Adiantamento' ? _selectedStaffId : null,
      );

      if (widget.existingExpense == null) {
        await provider.addExpense(auth.token!, expense);
        if (mounted)
          _showSuccessPopup("Despesa Registrada!", _amountController.text);
      } else {
        await provider.updateExpense(
            auth.token!, expense.id!, expense.toJson());
        if (mounted)
          _showSuccessPopup("Despesa Atualizada!", _amountController.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessPopup(String title, String amount) {
    // Implemente sua lógica de popup aqui ou use Snackbars simples para mobile
    // Exemplo simplificado:
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$title - $amount"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor; // ou um tom específico para Sheets

    // Ajuste para o teclado não cobrir o form
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(bottom: keyboardSpace),
      constraints: BoxConstraints(maxHeight: 0.9.sh), // Ocupa max 90% da tela
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar (Indicador visual de arraste)
          Center(
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Título Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
            child: Row(
              children: [
                Icon(
                  widget.existingExpense == null
                      ? PhosphorIcons.plus_circle_fill
                      : PhosphorIcons.pencil_simple_fill,
                  color: isDark ? Colors.white : Colors.black,
                  size: 28.sp,
                ),
                SizedBox(width: 12.w),
                Text(
                  widget.existingExpense == null
                      ? "Nova Despesa"
                      : "Editar Despesa",
                  style: GoogleFonts.sairaCondensed(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.withOpacity(0.1)),

          // Conteúdo com Scroll
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CATEGORIA
                    _buildLabel("Categoria", isDark),
                    DropdownButtonFormField<String>(
                      value: _categories.contains(_selectedCategory)
                          ? _selectedCategory
                          : 'Outros',
                      decoration: _inputDecoration("", isDark),
                      dropdownColor: theme.cardColor,
                      items: _categories.map((c) {
                        final style = _getCategoryStyle(c, isDark);
                        return DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(style.icon, size: 18.sp, color: style.color),
                              SizedBox(width: 10.w),
                              Text(c,
                                  style: GoogleFonts.inter(
                                      fontSize: 14.sp,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedCategory = v!;
                          _selectedStatus =
                              (_selectedCategory == 'Vale/Adiantamento')
                                  ? 'paid'
                                  : 'pending';
                          _updateAutoDescription();
                        });
                      },
                    ),
                    SizedBox(height: 16.h),

                    // VALOR (Destaque Visual)
                    _buildLabel("Valor", isDark),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      // Adicione o CurrencyInputFormatter se tiver a classe
                      // inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 24.sp,
                          color: isDark ? Colors.white : Colors.black),
                      decoration: _inputDecoration("R\$ 0,00", isDark).copyWith(
                        prefixIcon:
                            Icon(PhosphorIcons.money, color: Colors.green),
                      ),
                      validator: (v) => v!.isEmpty ? "Obrigatório" : null,
                    ),
                    SizedBox(height: 16.h),

                    // MÊS / ANO (Row)
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Mês Ref.", isDark),
                              DropdownButtonFormField<int>(
                                value: _refMonth,
                                decoration: _inputDecoration("", isDark),
                                dropdownColor: theme.cardColor,
                                items: List.generate(12, (index) => index + 1)
                                    .map((m) {
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      DateFormat('MMMM', 'pt_BR')
                                          .format(DateTime(2024, m, 1))
                                          .toUpperCase(),
                                      style: GoogleFonts.inter(
                                          fontSize: 13.sp,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() {
                                  _refMonth = v!;
                                  _updateAutoDescription();
                                }),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Ano", isDark),
                              DropdownButtonFormField<int>(
                                value: _refYear,
                                decoration: _inputDecoration("", isDark),
                                dropdownColor: theme.cardColor,
                                items: [2024, 2025, 2026]
                                    .map((y) => DropdownMenuItem(
                                        value: y, child: Text("$y")))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _refYear = v!;
                                  _updateAutoDescription();
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // CONDICIONAIS
                    if (_selectedCategory == 'Vale/Adiantamento') ...[
                      _buildStaffSelector(isDark),
                    ] else ...[
                      _buildDateAndStatus(isDark),
                    ],

                    SizedBox(height: 16.h),

                    // DESCRIÇÃO
                    _buildLabel("Descrição", isDark),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                          color: isDark ? Colors.white : Colors.black),
                      onChanged: (v) => _isManualDescription = v.isNotEmpty,
                      decoration:
                          _inputDecoration("Detalhes...", isDark).copyWith(
                              suffixIcon: _isManualDescription
                                  ? IconButton(
                                      icon: Icon(
                                          PhosphorIcons.arrow_counter_clockwise,
                                          size: 20.sp),
                                      onPressed: () => setState(() {
                                        _isManualDescription = false;
                                        _updateAutoDescription();
                                      }),
                                    )
                                  : null),
                    ),

                    SizedBox(height: 30.h),

                    // BOTÃO SALVAR (Full Width)
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF00A859), // Verde AcademyHub
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text("SALVAR LANÇAMENTO",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16.sp)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildStaffSelector(bool isDark) {
    // Implementação simplificada do Seletor
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final staffList = userProvider.users; // Filtre conforme necessário

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Colaborador", isDark),
        InkWell(
          onTap: () {
            // Dica: Use um modal simples aqui ou um SearchDelegate
            _showStaffSearchModal(context, staffList);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
            decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                    color: _selectedStaffId == null
                        ? Colors.red.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.3))),
            child: Row(
              children: [
                Icon(PhosphorIcons.user,
                    color: isDark ? Colors.white70 : Colors.black54),
                SizedBox(width: 10.w),
                Expanded(
                    child: Text(
                        _selectedStaffId == null
                            ? "Selecione..."
                            : _selectedStaffName,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black))),
                Icon(PhosphorIcons.caret_down, size: 16.sp),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateAndStatus(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Vencimento", isDark),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030));
                  if (d != null) setState(() => _dueDate = d);
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
                  decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.grey.withOpacity(0.3))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd/MM').format(_dueDate),
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black)),
                      Icon(PhosphorIcons.calendar_blank,
                          size: 16.sp, color: Colors.grey),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Status", isDark),
              Container(
                height: 48.h, // Altura para alinhar com o input
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    _buildStatusBtn("Pendente", 'pending', isDark),
                    _buildStatusBtn("Pago", 'paid', isDark),
                  ],
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildStatusBtn(String label, String val, bool isDark) {
    final isSelected = _selectedStatus == val;
    final color = val == 'paid' ? Colors.green : Colors.orange;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = val),
        child: Container(
          margin: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(6.r),
            border:
                isSelected ? Border.all(color: color.withOpacity(0.5)) : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey,
                  fontSize: 12.sp)),
        ),
      ),
    );
  }

  void _showStaffSearchModal(BuildContext context, List<User> staff) {
    // Mesma lógica do seu dialog original, mas adaptada para modal se quiser
    // Por brevidade, mantive simplificado acima, mas você pode colar seu Dialog de staff aqui.
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              // Copie o conteúdo do seu _openStaffSelectionDialog original aqui
              title: Text("Selecione"),
              content: SizedBox(
                width: 300,
                height: 300,
                child: ListView(
                  children: staff
                      .map((u) => ListTile(
                            title: Text(u.fullName),
                            onTap: () {
                              setState(() {
                                _selectedStaffId = u.id;
                                _selectedStaffName = u.fullName;
                                _updateAutoDescription();
                              });
                              Navigator.pop(ctx);
                            },
                          ))
                      .toList(),
                ),
              ),
            ));
  }

  Widget _buildLabel(String text, bool isDark) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey)),
      );

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? Colors.grey[800] : Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
    );
  }
}

class _CategoryStyle {
  final IconData icon;
  final Color color;
  final Color bgColor;
  _CategoryStyle(this.icon, this.color, this.bgColor);
}
