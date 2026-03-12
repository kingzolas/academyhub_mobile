import 'dart:convert';
import 'package:http/http.dart' as http;

// Modelos para os dados do IBGE
class StateModel {
  final int id;
  final String sigla;
  final String nome;

  StateModel({required this.id, required this.sigla, required this.nome});

  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      id: json['id'],
      sigla: json['sigla'],
      nome: json['nome'],
    );
  }
}

class CityModel {
  final int id;
  final String nome;

  CityModel({required this.id, required this.nome});

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'],
      nome: json['nome'],
    );
  }
}

class LocationService {
  final String _baseUrl = 'https://servicodados.ibge.gov.br/api/v1/localidades';

  Future<List<StateModel>> fetchStates() async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/estados?orderBy=nome'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => StateModel.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar estados.');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar estados.');
    }
  }

  Future<List<CityModel>> fetchCities(int stateId) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/estados/$stateId/municipios'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => CityModel.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar cidades.');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar cidades.');
    }
  }
}
