// lib/model/assistant_message_model.dart
class AssistantMessage {
  final String text;
  final bool isUser;

  AssistantMessage({
    required this.text,
    required this.isUser,
  });

  // Helper para converter para o formato que a API espera
  Map<String, dynamic> toJson() {
    return {
      'role': isUser ? 'user' : 'model',
      'parts': [
        {'text': text}
      ],
    };
  }
}
