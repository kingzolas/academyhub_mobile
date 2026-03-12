import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:academyhub_mobile/config/api_config.dart';

class NegotiationPaymentProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  // Dados da negociação carregada
  Map<String, dynamic>? _negotiationData;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get negotiationData => _negotiationData;

  // ⚠️ SUBSTITUA PELA SUA CHAVE PÚBLICA DO MERCADO PAGO (Inicia com APP_USR- ou TEST-)
  final String _mpPublicKey = "APP_USR-68951ac5-c7c0-4d41-ac26-18ca0ae2c836";

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // 1. Valida o acesso (Login na Negociação)
  Future<bool> validateAccess(String token, String cpf) async {
    _setLoading(true);
    _error = null;
    try {
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/api/negotiations/public/validate/$token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'cpf': cpf}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _negotiationData = data['data']; // { studentName, totalDebt, rules... }
        _setLoading(false);
        return true;
      } else {
        throw Exception(json.decode(response.body)['message']);
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // 2. Pagar com PIX
  Future<Map<String, dynamic>?> payWithPix(String token) async {
    _setLoading(true);
    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}/api/negotiations/public/pay/$token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'method': 'pix'}),
      );

      _setLoading(false);
      if (response.statusCode == 200) {
        return json.decode(response.body)['paymentData'];
      } else {
        throw Exception(json.decode(response.body)['message']);
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  // 3. Tokenizar Cartão (Direto API Mercado Pago)
  Future<String> _tokenizeCard({
    required String cardNumber,
    required String cardHolderName,
    required String cardExpirationMonth,
    required String cardExpirationYear,
    required String securityCode,
    required String cpf,
  }) async {
    final url = Uri.parse(
        'https://api.mercadopago.com/v1/card_tokens?public_key=$_mpPublicKey');

    // Ajuste simples para ano (Se usuário digitar 25, vira 2025)
    final yearFull = cardExpirationYear.length == 2
        ? "20$cardExpirationYear"
        : cardExpirationYear;

    final body = json.encode({
      "cardNumber": cardNumber.replaceAll(' ', ''),
      "cardholder": {
        "name": cardHolderName,
        "identification": {
          "type": "CPF",
          "number": cpf.replaceAll(RegExp(r'\D'), '')
        }
      },
      "expirationMonth": int.parse(cardExpirationMonth),
      "expirationYear": int.parse(yearFull),
      "securityCode": securityCode
    });

    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['id']; // Retorna o token seguro (ex: 123abc456...)
    } else {
      throw Exception("Dados do cartão inválidos. Verifique a numeração.");
    }
  }

  // 4. Pagar com Cartão (Fluxo Completo)
  Future<bool> payWithCard({
    required String token,
    required String cardNumber,
    required String name,
    required String month,
    required String year,
    required String cvv,
    required String cpfOwner,
    required int installments,
  }) async {
    _setLoading(true);
    try {
      // A. Tokeniza no Mercado Pago
      final String cardToken = await _tokenizeCard(
        cardNumber: cardNumber,
        cardHolderName: name,
        cardExpirationMonth: month,
        cardExpirationYear: year,
        securityCode: cvv,
        cpf: cpfOwner,
      );

      // B. Envia para o NOSSO Backend
      final url =
          Uri.parse('${ApiConfig.baseUrl}/api/negotiations/public/pay/$token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'method': 'credit_card',
          'cardData': {
            'token': cardToken,
            'issuerId': '1', // Simplificado
            'paymentMethodId':
                'master', // Simplificado (ideal: detectar bandeira)
            'installments': installments
          }
        }),
      );

      _setLoading(false);
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(json.decode(response.body)['message']);
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }
}
