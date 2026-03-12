import 'dart:convert';
import 'package:http/http.dart' as http;

class InvoiceCompensationService {
  // ⚠️ Ajuste para o seu padrão (igual InvoiceService)
  final String baseUrl;

  InvoiceCompensationService({required this.baseUrl});

  Future<Map<String, dynamic>> createCompensation({
    required String token,
    required String studentId,
    required String targetInvoiceId,
    required String sourceInvoiceId,
    required String reason,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/invoice-compensations');

    final body = {
      "student": studentId,
      "target_invoice": targetInvoiceId,
      "source_invoice": sourceInvoiceId,
      "reason": reason,
      if (notes != null && notes.trim().isNotEmpty) "notes": notes.trim(),
    };

    print('🔵 [Service] POST: $uri');
    print(
        '🔵 [Service] Headers: Authorization: Bearer ${token.substring(0, 15)}...');
    print('🔵 [Service] Payload enviado: ${jsonEncode(body)}');

    final res = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print('🔵 [Service] Status Code recebido: ${res.statusCode}');
    print('🔵 [Service] Body recebido: ${res.body}');

    // Tenta decodificar o JSON com segurança
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (e) {
      print(
          '🔴 [Service] Erro ao decodificar JSON do backend. Resposta não é um JSON válido.');
      throw Exception(
          "Erro no servidor: Resposta inválida (Status ${res.statusCode})");
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // você pode padronizar pra {ok:true,data:{...}}
      if (data is Map<String, dynamic>) return data;
      return {"ok": true, "data": data};
    }

    // Tenta achar a mensagem de erro da API de várias formas possíveis
    String msg = "Erro desconhecido ao criar compensação";
    if (data is Map) {
      if (data["message"] != null) {
        msg = data["message"].toString();
      } else if (data["error"] != null &&
          data["error"] is Map &&
          data["error"]["message"] != null) {
        // Exemplo: padrão Strapi de erro
        msg = data["error"]["message"].toString();
      } else if (data["errors"] != null) {
        // Exemplo: padrão de erro de validação (array ou map de erros)
        msg = "Erro de validação: ${data["errors"].toString()}";
      } else if (data["error"] != null) {
        msg = data["error"].toString();
      }
    }

    print('🔴 [Service] Lançando exceção: $msg');
    throw Exception(msg);
  }

  Future<List<dynamic>> listCompensations({
    required String token,
    String? status, // active/resolved/canceled
    String? studentId,
  }) async {
    final qp = <String, String>{};
    if (status != null) qp["status"] = status;
    if (studentId != null) qp["student"] = studentId;

    final uri = Uri.parse('$baseUrl/api/invoice-compensations')
        .replace(queryParameters: qp.isEmpty ? null : qp);

    final res = await http.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // aceita lista pura OU {data:[...]}
      if (data is List) return data;
      if (data is Map && data["data"] is List) return data["data"];
      return [];
    }

    final msg = (data is Map && data["message"] != null)
        ? data["message"].toString()
        : "Erro ao listar compensações";
    throw Exception(msg);
  }

  Future<void> resolveCompensation({
    required String token,
    required String compensationId,
  }) async {
    final uri =
        Uri.parse('$baseUrl/api/invoice-compensations/$compensationId/resolve');

    final res = await http.patch(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    final data = jsonDecode(res.body);
    final msg = (data is Map && data["message"] != null)
        ? data["message"].toString()
        : "Erro ao resolver compensação";
    throw Exception(msg);
  }

  Future<void> cancelCompensation({
    required String token,
    required String compensationId,
  }) async {
    final uri =
        Uri.parse('$baseUrl/api/invoice-compensations/$compensationId/cancel');

    final res = await http.patch(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    final data = jsonDecode(res.body);
    final msg = (data is Map && data["message"] != null)
        ? data["message"].toString()
        : "Erro ao cancelar compensação";
    throw Exception(msg);
  }
}
