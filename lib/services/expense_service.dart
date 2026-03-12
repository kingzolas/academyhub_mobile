import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart'; // Ajuste o import conforme sua estrutura real
import '../model/expense_model.dart';

class ExpenseService {
  // Ajuste a rota base conforme seu ApiConfig.
  // Supondo que ApiConfig.baseUrl seja algo como 'http://seu-ip:3000/api'
  final String baseUrl = '${ApiConfig.apiUrl}/expenses';

  // Cabeçalhos padrão com Autenticação
  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 1. Listar Despesas (com filtros opcionais de data)
  Future<List<Expense>> getExpenses(String token,
      {String? startDate, String? endDate}) async {
    String queryParams = '';
    if (startDate != null && endDate != null) {
      queryParams = '?startDate=$startDate&endDate=$endDate';
    }

    final response = await http.get(
      Uri.parse('$baseUrl$queryParams'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Expense.fromJson(item)).toList();
    } else {
      throw Exception('Falha ao carregar despesas: ${response.body}');
    }
  }

  // 2. Criar Despesa
  Future<Expense> createExpense(String token, Expense expense) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: _getHeaders(token),
      body: jsonEncode(expense.toJson()),
    );

    if (response.statusCode == 201) {
      return Expense.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao criar despesa: ${response.body}');
    }
  }

  // 3. Atualizar Despesa
  Future<Expense> updateExpense(
      String token, String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: _getHeaders(token),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return Expense.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao atualizar despesa: ${response.body}');
    }
  }

  // 4. Deletar Despesa
  Future<void> deleteExpense(String token, String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: _getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao deletar despesa: ${response.body}');
    }
  }
}
