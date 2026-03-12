import 'dart:convert';
import 'package:academyhub_mobile/model/negotiation_model.dart';
import 'package:http/http.dart' as http;
import 'package:academyhub_mobile/config/api_config.dart';

class NegotiationService {
  // ... createNegotiation (Mantenha o código anterior do create) ...
  Future<String> createNegotiation({
    required String token,
    required String studentId,
    required List<String> invoiceIds,
    required NegotiationRules rules,
  }) async {
    // (Copie o código do createNegotiation que já estava funcionando ou use o do passo anterior)
    final url =
        Uri.parse('${ApiConfig.baseUrl}/api/negotiations/internal/create');
    // ... logica do post ...
    // Vou resumir aqui para focar no listByStudent que é onde está o erro
    final bodyEncoded = json.encode({
      'studentId': studentId,
      'invoiceIds': invoiceIds,
      'rules': rules.toJson(),
    });
    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: bodyEncoded);
    if (response.statusCode == 201) {
      final d = json.decode(response.body);
      return d['linkToken'] ?? d['negotiation']['token'];
    }
    throw Exception('Erro ao criar');
  }

  // --- LIST BY STUDENT (ATUALIZADO) ---
  Future<List<Negotiation>> listByStudent({
    required String token,
    required String studentId,
  }) async {
    final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/negotiations/internal/student/$studentId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic decodedBody = json.decode(response.body);

        if (decodedBody is List) {
          return decodedBody.map((item) {
            Map<String, dynamic> mapItem;

            if (item is String) {
              mapItem = json.decode(item);
            } else if (item is Map<String, dynamic>) {
              mapItem = item;
            } else {
              mapItem = Map<String, dynamic>.from(item);
            }

            // Passa pelo "Sanitizador" reforçado
            return Negotiation.fromJson(_sanitizeJson(mapItem));
          }).toList();
        } else {
          return [];
        }
      } else {
        throw Exception('Falha ao listar negociações: ${response.body}');
      }
    } catch (e) {
      print('❌ Erro Fatal em listByStudent: $e');
      // Retornar lista vazia em caso de erro para não travar a tela é uma opção,
      // ou re-lançar a exceção. Vamos re-lançar para você ver o log.
      throw Exception("Erro ao carregar histórico: $e");
    }
  }

  // --- SANITIZER REFORÇADO ---
  Map<String, dynamic> _sanitizeJson(Map<String, dynamic> json) {
    try {
      // 1. Cria um objeto "Dummy" de estudante com campos vazios
      // Isso evita que Student.fromJson quebre se esperar strings não nulas
      final dummyStudent = {
        "_id": "id_desconhecido",
        "id": "id_desconhecido",
        "fullName": "Aluno",
        "name": "Aluno",
        "cpf": "", // Preenche com vazio para não dar Null error
        "email": "", // Preenche com vazio
        "phone": "", // Preenche com vazio
        "address": "",
      };

      // Corrige 'studentId' na raiz
      if (json.containsKey('studentId')) {
        if (json['studentId'] is String) {
          final String id = json['studentId'];
          final newStudent = Map<String, dynamic>.from(dummyStudent);
          newStudent['_id'] = id;
          newStudent['id'] = id;
          json['studentId'] = newStudent;
        }
      }

      // Corrige Invoices
      if (json['invoices'] != null && json['invoices'] is List) {
        List<dynamic> invoices = json['invoices'];

        json['invoices'] = invoices.map((inv) {
          if (inv is Map<String, dynamic>) {
            // Se o estudante na fatura for só ID (String), troca pelo dummy
            if (inv['student'] is String) {
              final String id = inv['student'];
              final newStudent = Map<String, dynamic>.from(dummyStudent);
              newStudent['_id'] = id;
              newStudent['id'] = id;
              inv['student'] = newStudent;
            }

            // Se o tutor na fatura for só ID (String), troca pelo dummy
            if (inv['tutor'] is String) {
              final String id = inv['tutor'];
              final newTutor = Map<String, dynamic>.from(dummyStudent);
              newTutor['_id'] = id;
              newTutor['id'] = id;
              newTutor['fullName'] = "Responsável";
              newTutor['name'] = "Responsável";
              inv['tutor'] = newTutor;
            }
          }
          return inv;
        }).toList();
      }

      return json;
    } catch (e) {
      print("⚠️ Aviso ao sanitizar JSON: $e");
      return json;
    }
  }
}
