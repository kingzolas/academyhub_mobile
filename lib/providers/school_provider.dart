import 'package:academyhub_mobile/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:academyhub_mobile/model/school_model.dart';
import 'package:academyhub_mobile/services/school_service.dart';

class SchoolProvider extends ChangeNotifier {
  final SchoolService _service = SchoolService();

  SchoolModel? _school;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _logoUrlCacheBuster; // Para forçar atualização da imagem na tela

  // Getters
  SchoolModel? get currentSchool => _school;
  SchoolModel? get school => _school;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  // Retorna a URL da logo montada
  String? get currentLogoUrl {
    if (_school == null) return null;
    String baseUrl = '${ApiConfig.apiUrl}/schools/${_school!.id}/logo';
    if (_logoUrlCacheBuster != null) {
      return '$baseUrl?t=$_logoUrlCacheBuster';
    }
    return baseUrl;
  }

  // --- GERA O LINK PÚBLICO DE MATRÍCULA ---
  String get publicRegistrationLink {
    if (_school == null) return '';
    return 'https://monumental-mochi-037b2b.netlify.app/matricula-web/${_school!.id}';
  }

  Future<void> loadSchoolData(String schoolId, String token) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint("🔍 [SchoolProvider] Buscando dados da escola ID: $schoolId");
      _school = await _service.getSchool(schoolId, token);

      if (_school != null) {
        debugPrint("📦 [SchoolProvider] Objeto School recebido.");
        if (_school!.logoBytes != null) {
          debugPrint(
              "✅ [SchoolProvider] Logo detectada! Tamanho: ${_school!.logoBytes!.length} bytes");
        } else {
          debugPrint(
              "⚠️ [SchoolProvider] O campo logoBytes está NULO no objeto final.");
        }
      }
    } catch (e) {
      debugPrint("❌ [SchoolProvider] Erro ao buscar escola: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSchoolData({
    required String schoolId,
    required String token,
    required Map<String, String> formFields,
    XFile? newLogo,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _service.updateSchool(
        schoolId: schoolId,
        token: token,
        fields: formFields,
        logoFile: newLogo,
      );

      if (newLogo != null) {
        _logoUrlCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      }

      await loadSchoolData(schoolId, token);

      return true;
    } catch (e) {
      debugPrint("Erro ao salvar escola: $e");
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
