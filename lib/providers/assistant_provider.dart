import 'package:academyhub_mobile/model/assistant_message_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/assistant_service.dart';
import 'package:flutter/material.dart';

class AssistantProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  final AssistantService _assistantService;

  // Variáveis para Resiliência e Retry
  int _maxRetries = 3;
  String? _lastError;

  AssistantProvider({
    required AuthProvider authProvider,
    required AssistantService assistantService,
  })  : _authProvider = authProvider,
        _assistantService = assistantService {
    _messages.add(AssistantMessage(
      text:
          "Olá! Sou o Olho de Deus 👁️. Posso consultar dados de alunos, turmas e financeiro. O que deseja saber?",
      isUser: false,
    ));
  }

  final List<AssistantMessage> _messages = [];
  bool _isLoading = false;

  List<AssistantMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _lastError;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isLoading) return;

    final token = _authProvider.token;
    if (token == null) {
      _lastError = "Sessão expirada. Faça login novamente.";
      notifyListeners();
      return;
    }

    // 1. Adiciona a mensagem do usuário na tela IMEDIATAMENTE
    _messages.add(AssistantMessage(text: text, isUser: true));
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    String responseText = "Não foi possível obter uma resposta.";
    int currentRetry = 0;
    bool success = false;

    while (currentRetry < _maxRetries && !success) {
      try {
        // 2. Prepara o histórico para a API
        // IMPORTANTE: O backend espera o histórico ANTERIOR à pergunta atual.
        // Como já adicionamos a pergunta atual em _messages (passo 1),
        // precisamos filtrar para não enviar a pergunta atual duplicada no histórico.

        final previousMessages = _messages.sublist(0, _messages.length - 1);

        final formattedHistory = previousMessages.map((msg) {
          return {
            "role": msg.isUser ? "user" : "model",
            "parts": [
              {"text": msg.text}
            ]
          };
        }).toList();

        // Remove a mensagem de boas-vindas inicial se for do modelo (Gemini prefere começar com user)
        if (formattedHistory.isNotEmpty &&
            formattedHistory.first["role"] == "model") {
          formattedHistory.removeAt(0);
        }

        // 3. Envia para o Service
        responseText = await _assistantService.sendMessage(
          token: token,
          question: text, // Passa o texto atual como a 'question'
          history: formattedHistory,
        );

        success = true;
      } catch (e) {
        // Lógica de Retry para erros 503 (Sobrecarga)
        if (e.toString().contains('503') ||
            e.toString().toLowerCase().contains('overloaded')) {
          currentRetry++;
          if (currentRetry < _maxRetries) {
            int delaySeconds = 2 * currentRetry; // 2s, 4s, 6s...
            print(
                '⚠️ [Assistant] 503 Detectado. Retry $currentRetry em ${delaySeconds}s...');
            await Future.delayed(Duration(seconds: delaySeconds));
            continue;
          }
        }

        // Se falhar de vez ou for outro erro
        responseText =
            "Erro: ${e.toString().replaceAll('Exception:', '').trim()}";
        print('❌ [Assistant] Erro final: $e');
        break;
      }
    }

    // 4. Adiciona a resposta da IA na tela
    _messages.add(AssistantMessage(text: responseText, isUser: false));
    _isLoading = false;
    notifyListeners();
  }
}
