class ApiConfig {
  // --- AMBIENTE DE DESENVOLVIMENTO ---

  // Use 10.0.2.2 para o emulador Android se a API estiver rodando no seu PC
  // Use o IP da sua máquina na rede se estiver testando em um celular físico
  // Use localhost (ou 127.0.0.1) se estiver rodando no Windows/Linux/Web

  // static const String apiUrl = '$baseUrl/api';

  // static const String baseUrl =
  //     'https://school-management-api-76ef.onrender.com';
  // // Esta é a URL para o WebSocket (WSS = WebSocket Seguro)

  // static const String wsUrl = 'wss://school-management-api-76ef.onrender.com';

  // static const String baseUrl =
  //     'https://weightiest-ironically-marta.ngrok-free.dev';

  // static const String apiUrl = '$baseUrl/api';
  // static const String wsUrl = 'ws://localhost:3000';

  // static const String baseUrl = 'http://localhost:3000';

  // static const String apiUrl = '$baseUrl/api';

  // static String get wsUrl {
  //   if (baseUrl.startsWith('https://')) {
  //     return baseUrl.replaceFirst('https://', 'wss://');
  //   }
  //   if (baseUrl.startsWith('http://')) {
  //     return baseUrl.replaceFirst('http://', 'ws://');
  //   }
  //   return baseUrl;
  // }

  // static const String frontendUrl =
  //     'https://monumental-mochi-037b2b.netlify.app/';
  // static const String baseUrl = 'http://localhost:3000';

  // static const String apiUrl = '$baseUrl/api';
  // static const String wsUrl = 'ws://localhost:3000';

  static const String apiUrl = '$baseUrl/api';

  static const String frontendUrl = 'https://academyhub-mobile.netlify.app/';

  static const String baseUrl =
      'https://school-management-api-76ef.onrender.com';
  // Esta é a URL para o WebSocket (WSS = WebSocket Seguro)
  static const String wsUrl = 'wss://school-management-api-76ef.onrender.com';
}
