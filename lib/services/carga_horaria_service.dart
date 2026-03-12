// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart';

// // Importe seu model de Carga Horária
// import 'package:academyhub_mobile/model/cargaHoraria_model.dart';
// // Importa a sua configuração de API
// import 'package:academyhub_mobile/config/api_config.dart'; // <-- Ajuste este caminho se necessário

// class CargaHorariaService {
//   final String _apiBaseUrl = ApiConfig.apiUrl;

//   /// Busca a Carga Horária de uma turma/período
//   ///
//   /// [token] O token JWT para autenticação.
//   /// [filter] Um Map para filtros de query, ex: {'classId': '123', 'termId': '456'}
//   Future<List<CargaHorariaModel>> find(
//       String token, Map<String, dynamic> filter) async {
//     try {
//       final uri = Uri.parse('$_apiBaseUrl/carga-horaria').replace(
//         queryParameters: filter,
//       );

//       final response = await http.get(
//         uri,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (kDebugMode) {
//         print('[CargaHorariaService.find] GET ${uri.toString()}');
//         print(
//             '[CargaHorariaService.find] Response Code: ${response.statusCode}');
//       }

//       if (response.statusCode == 200) {
//         final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
//         final List<CargaHorariaModel> cargas = body
//             .map((dynamic item) =>
//                 CargaHorariaModel.fromJson(item as Map<String, dynamic>))
//             .toList();
//         return cargas;
//       } else {
//         try {
//           final dynamic body = json.decode(response.body);
//           throw Exception(body['message'] ?? 'Falha ao buscar carga horária.');
//         } catch (e) {
//           throw Exception(
//               'Falha ao buscar carga horária (código ${response.statusCode})');
//         }
//       }
//     } catch (e) {
//       print('Erro em CargaHorariaService.find: $e');
//       throw Exception('Erro de conexão ao buscar carga horária: $e');
//     }
//   }

//   /// Cria uma nova regra de Carga Horária
//   ///
//   /// [token] O token JWT para autenticação.
//   /// [data] Um Map com os dados (termId, classId, subjectId, horasNecessarias).
//   Future<CargaHorariaModel> create(
//       String token, Map<String, dynamic> data) async {
//     try {
//       final uri = Uri.parse('$_apiBaseUrl/carga-horaria');
//       final response = await http.post(
//         uri,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: json.encode(data),
//       );

//       if (kDebugMode) {
//         print('[CargaHorariaService.create] POST ${uri.toString()}');
//         print(
//             '[CargaHorariaService.create] Response Code: ${response.statusCode}');
//       }

//       final dynamic body = json.decode(utf8.decode(response.bodyBytes));

//       if (response.statusCode == 201) {
//         return CargaHorariaModel.fromJson(body as Map<String, dynamic>);
//       } else {
//         throw Exception(body['message'] ?? 'Falha ao criar carga horária.');
//       }
//     } catch (e) {
//       print('Erro em CargaHorariaService.create: $e');
//       throw Exception('Erro de conexão ao criar carga horária: $e');
//     }
//   }

//   /// Atualiza uma Carga Horária existente
//   ///
//   /// [token] O token JWT para autenticação.
//   /// [id] O ID da carga horária a ser atualizada.
//   /// [data] Um Map com os dados (geralmente apenas 'horasNecessarias').
//   Future<CargaHorariaModel> update(
//       String token, String id, Map<String, dynamic> data) async {
//     try {
//       final uri = Uri.parse('$_apiBaseUrl/carga-horaria/$id');
//       final response = await http.put(
//         uri,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: json.encode(data),
//       );

//       if (kDebugMode) {
//         print('[CargaHorariaService.update] PUT ${uri.toString()}');
//         print(
//             '[CargaHorariaService.update] Response Code: ${response.statusCode}');
//       }

//       final dynamic body = json.decode(utf8.decode(response.bodyBytes));

//       if (response.statusCode == 200) {
//         return CargaHorariaModel.fromJson(body as Map<String, dynamic>);
//       } else {
//         throw Exception(body['message'] ?? 'Falha ao atualizar carga horária.');
//       }
//     } catch (e) {
//       print('Erro em CargaHorariaService.update: $e');
//       throw Exception('Erro de conexão ao atualizar carga horária: $e');
//     }
//   }

//   /// Deleta uma Carga Horária
//   ///
//   /// [token] O token JWT para autenticação.
//   /// [id] O ID da carga horária a ser deletada.
//   Future<void> delete(String token, String id) async {
//     try {
//       final uri = Uri.parse('$_apiBaseUrl/carga-horaria/$id');
//       final response = await http.delete(
//         uri,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (kDebugMode) {
//         print('[CargaHorariaService.delete] DELETE ${uri.toString()}');
//         print(
//             '[CargaHorariaService.delete] Response Code: ${response.statusCode}');
//       }

//       if (response.statusCode == 200) {
//         return; // Sucesso
//       } else {
//         try {
//           final dynamic body = json.decode(response.body);
//           throw Exception(body['message'] ?? 'Falha ao deletar carga horária.');
//         } catch (e) {
//           throw Exception(
//               'Falha ao deletar carga horária (código ${response.statusCode})');
//         }
//       }
//     } catch (e) {
//       print('Erro em CargaHorariaService.delete: $e');
//       throw Exception('Erro de conexão ao deletar carga horária: $e');
//     }
//   }
// }
