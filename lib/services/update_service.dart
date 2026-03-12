import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// --- MODEL ATUALIZADO ---
// Adicionamos 'body' e 'name' para alimentar os novos Pop-ups
class UpdateRelease {
  final String version; // ex: "1.0.2"
  final String tagName; // ex: "v1.0.2"
  final String name; // Título da release
  final String body; // O texto Markdown (changelog)
  final String downloadUrl; // Link do .exe

  UpdateRelease({
    required this.version,
    required this.tagName,
    required this.name,
    required this.body,
    required this.downloadUrl,
  });
}

class UpdateService {
  // A URL da sua API (Back-end próprio)
  final String _baseUrl =
      "https://school-management-api-76ef.onrender.com/api/releases";

  /// Busca as informações da última release na SUA API
  Future<UpdateRelease?> getLatestReleaseInfo() async {
    try {
      // 1. Configura a URL
      // Usamos o endpoint /latest que criamos no seu backend
      final urlStr = "$_baseUrl/latest";

      // --- SUA LÓGICA DE SSL MANTIDA (INTACTA) ---
      HttpClient client = HttpClient();
      client.badCertificateCallback =
          ((X509Certificate cert, String host, int port) => true);

      // Faz a requisição manualmente
      HttpClientRequest request = await client.getUrl(Uri.parse(urlStr));

      // Cabeçalhos para evitar cache
      request.headers
          .add("Cache-Control", "no-cache, no-store, must-revalidate");
      request.headers.add("Pragma", "no-cache");
      request.headers.add("Expires", "0");

      HttpClientResponse response = await request.close();

      // Lê a resposta como String
      String responseBody = await response.transform(utf8.decoder).join();

      // Validação
      if (response.statusCode == 200 &&
          responseBody != 'null' &&
          responseBody.isNotEmpty) {
        final json = jsonDecode(responseBody);

        // Tratamento dos dados vindos do MongoDB
        String rawTag = json['tag'] ?? '';
        String versionString =
            rawTag.replaceAll('v', ''); // Remove o 'v' para ter só o número

        // Retornamos o objeto preenchido.
        // A comparação se é maior ou menor agora é feita pelo UpdateManager,
        // assim conseguimos mostrar o modal de "Novidades" mesmo se já estiver atualizado.
        return UpdateRelease(
          version: versionString,
          tagName: rawTag,
          name: json['name'] ?? 'Nova Atualização',
          body: json['body'] ?? '', // Aqui vem o Markdown do GitHub
          downloadUrl: json['downloadUrl'] ?? '',
        );
      } else {
        // Se a API retornar null (nenhuma release cadastrada) ou erro
        // print("API retornou status ${response.statusCode} ou body vazio");
      }
    } catch (e) {
      // print("Erro ao buscar update: $e");
    }
    return null;
  }

  /// Baixa e instala
  /// LÓGICA MANTIDA 100% IGUAL AO SEU ORIGINAL
  Future<void> downloadAndInstall(
      String downloadUrl, Function(double) onProgress) async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = "${dir.path}/academy_hub_update.exe";

      // Configura o DIO para também ignorar SSL no download (importante!)
      final dio = Dio();
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      };

      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      await Process.run(savePath, [
        "/VERYSILENT",
        "/SUPPRESSMSGBOXES",
        "/NORESTART",
        "/CLOSEAPPLICATIONS"
      ]);

      exit(0);
    } catch (e) {
      print("Erro na instalação: $e");
      throw Exception("Falha na instalação");
    }
  }
}
