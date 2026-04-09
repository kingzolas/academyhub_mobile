import 'dart:convert';
import 'dart:typed_data';
import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:http/http.dart' as http;
import 'package:academyhub_mobile/config/api_config.dart';

class InvoiceService {
  final String _baseUrl = ApiConfig.apiUrl;

  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Invoice> createInvoice({
    required Map<String, dynamic> invoiceData,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/invoices');
    final headers = _getHeaders(token);
    final body = jsonEncode(invoiceData);

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Invoice.fromJson(data);
    } else {
      throw Exception('Falha ao criar fatura: ${response.body}');
    }
  }

  Future<List<Invoice>> getAllInvoices({
    required String token,
    String? status,
  }) async {
    String queryString = status != null ? '?status=$status' : '';
    final url = Uri.parse('$_baseUrl/invoices$queryString');
    final headers = _getHeaders(token);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Invoice.fromJson(json)).toList();
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception('Falha ao buscar faturas: ${errorBody['message']}');
    }
  }

  Future<List<Invoice>> getInvoicesByStudent({
    required String studentId,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/invoices/student/$studentId');
    final headers = _getHeaders(token);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Invoice.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao buscar faturas do aluno: ${response.body}');
    }
  }

  Future<List<Invoice>> getGuardianInvoices({
    required String token,
    String? studentId,
  }) async {
    final normalizedStudentId = (studentId ?? '').trim();
    final url = Uri.parse('$_baseUrl/guardian-auth/invoices').replace(
      queryParameters: normalizedStudentId.isEmpty
          ? null
          : {'studentId': normalizedStudentId},
    );
    final headers = _getHeaders(token);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final rawInvoices = data['invoices'] as List<dynamic>? ?? const [];
      return rawInvoices
          .whereType<Map<String, dynamic>>()
          .map(Invoice.fromJson)
          .toList();
    } else {
      String message = 'Falha ao buscar os boletos do responsável.';
      try {
        final errorBody = jsonDecode(response.body);
        message = (errorBody['message'] ?? message).toString();
      } catch (_) {}
      throw Exception(message);
    }
  }

  /// Rota: GET /api/invoices/:id
  Future<Invoice> getInvoiceById({
    required String invoiceId,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/invoices/$invoiceId');
    final headers = _getHeaders(token);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Invoice.fromJson(data);
    } else {
      throw Exception('Falha ao carregar detalhes da fatura.');
    }
  }

  Future<dynamic> checkMpStatus({
    required String paymentId,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/invoices/mp/$paymentId');
    final headers = _getHeaders(token);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao consultar status no MP: ${response.body}');
    }
  }

  // --- Sincronização de Status (Cora/MP) ---
  Future<Map<String, dynamic>> syncPendingInvoices(
      {required String token}) async {
    final url = Uri.parse('$_baseUrl/invoices/sync-pending');
    final headers = _getHeaders(token);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao sincronizar: ${response.body}');
    }
  }

  // ✅ NOVO: DEBUG CORA
  // Rota: GET /invoices/debug/cora/:externalId
  Future<Map<String, dynamic>> debugCoraInvoice({
    required String externalId,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/invoices/debug/cora/$externalId');
    final headers = _getHeaders(token);

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      String msg = 'Falha ao consultar a Cora.';
      try {
        final body = jsonDecode(response.body);
        msg = body['message'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  // --- Cancelar Fatura ---
  Future<void> cancelInvoice({
    required String invoiceId,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/invoices/$invoiceId/cancel');
    final headers = _getHeaders(token);

    final response = await http.put(url, headers: headers);

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      String msg = 'Erro desconhecido';
      try {
        final body = jsonDecode(response.body);
        msg = body['message'] ?? response.body;
      } catch (_) {
        msg = response.body;
      }
      throw Exception(msg);
    }
  }

  // --- Download do PDF Unificado ---
  Future<Uint8List> downloadBatchPdf({
    required List<String> invoiceIds,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/invoices/batch-print');
    final headers = _getHeaders(token);

    final body = jsonEncode({'invoiceIds': invoiceIds});

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      String msg = 'Erro ao gerar PDF.';
      try {
        final err = jsonDecode(response.body);
        msg = err['message'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  Future<Uint8List> downloadGuardianBatchPdf({
    required List<String> invoiceIds,
    required String token,
    String? studentId,
  }) async {
    final url = Uri.parse('$_baseUrl/guardian-auth/invoices/batch-print');
    final headers = _getHeaders(token);
    final body = jsonEncode({
      'invoiceIds': invoiceIds,
      if ((studentId ?? '').trim().isNotEmpty) 'studentId': studentId!.trim(),
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      String msg = 'Erro ao gerar o PDF do boleto.';
      try {
        final err = jsonDecode(response.body);
        msg = (err['message'] ?? msg).toString();
      } catch (_) {}
      throw Exception(msg);
    }
  }

  // --- Reenvio de WhatsApp ---
  Future<void> resendWhatsapp({
    required String invoiceId,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/invoices/$invoiceId/resend');
    final headers = _getHeaders(token);

    final response = await http.post(url, headers: headers);

    if (response.statusCode != 200) {
      String msg = 'Erro ao enviar mensagem.';
      try {
        final body = jsonDecode(response.body);
        msg = body['message'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }
}
