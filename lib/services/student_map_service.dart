import 'dart:convert';
import 'dart:math';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class StudentMapPoint {
  final Student student;
  final LatLng position;
  final String neighborhoodDisplay;

  StudentMapPoint({
    required this.student,
    required this.position,
    required this.neighborhoodDisplay,
  });
}

class NeighborhoodGeoResult {
  final String neighborhoodKey;
  final String neighborhoodDisplay;
  final LatLng center;
  final List<Student> students;

  NeighborhoodGeoResult({
    required this.neighborhoodKey,
    required this.neighborhoodDisplay,
    required this.center,
    required this.students,
  });
}

class StudentMapService {
  // Coordenadas reais da Instituição (Substitua se necessário)
  static const LatLng schoolLocation = LatLng(-6.07074, -49.9043);
  static const LatLng parauapebasCenter = LatLng(-6.07074, -49.9043);

  // Cache em memória (MVP). Depois, persistir em DB/local.
  static final Map<String, LatLng> _neighborhoodGeoCache = {};

  static DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool isInParauapebas(Student s) {
    final city = _norm(s.address.city);
    final state = _norm(s.address.state);

    final isCityOk = city == 'parauapebas';
    final isStateOk = state == 'pa' || state == 'para' || state == 'pará';

    return isCityOk && isStateOk;
  }

  static bool _isGarbageNeighborhood(String raw) {
    final v = _norm(raw);
    if (v.isEmpty) return true;
    if (v.length <= 2) return true;

    // padrões que claramente não são bairro
    final garbage = <String>{
      'qweqe',
      'sd ad',
      '---',
      'na',
      'n/a',
      'sem bairro',
      'nao informado',
      'não informado',
    };
    if (garbage.contains(v)) return true;

    return false;
  }

  static String _displayNeighborhood(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return "Não informado";
    // Capitalização simples
    return v.split(' ').map((p) {
      if (p.isEmpty) return '';
      return '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}';
    }).join(' ');
  }

  static String _neighborhoodKey(String raw) => _norm(raw);

  static Future<void> _respectRateLimit() async {
    final now = DateTime.now();
    final diff = now.difference(_lastRequestAt);
    // Delay otimizado para a API do Google Maps (aguenta mais volume)
    if (diff.inMilliseconds < 200) {
      await Future.delayed(Duration(milliseconds: 200 - diff.inMilliseconds));
    }
    _lastRequestAt = DateTime.now();
  }

  /// Geocoding via Google Maps Platform
  static Future<LatLng?> _geocodeNeighborhood({
    required String neighborhood,
    required String city,
    required String state,
  }) async {
    final key = _neighborhoodKey('$neighborhood|$city|$state');
    if (_neighborhoodGeoCache.containsKey(key)) {
      return _neighborhoodGeoCache[key];
    }

    await _respectRateLimit();

    // INSIRA A SUA CHAVE DA API DO GOOGLE ABAIXO
    const apiKey = 'AIzaSyBBYu0jgcq8zu92WL72YfD4PNOpP_S1f-k';

    final query = Uri.encodeComponent('$neighborhood, $city, $state, Brasil');
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$apiKey');

    try {
      final res = await http.get(url);

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);

      if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
        return null;
      }

      final location = data['results'][0]['geometry']['location'];
      final lat = location['lat'] as double;
      final lng = location['lng'] as double;

      final point = LatLng(lat, lng);
      _neighborhoodGeoCache[key] = point;
      return point;
    } catch (_) {
      return null;
    }
  }

  static LatLng _jitterNear(LatLng base, Student s,
      {double radiusMeters = 220}) {
    // jitter determinístico por aluno, mas pequeno
    final seed = s.id.hashCode ^
        s.fullName.hashCode ^
        s.address.street.hashCode ^
        s.address.neighborhood.hashCode;
    final rnd = Random(seed);

    final r = rnd.nextDouble() * radiusMeters; // 0..radius
    final theta = rnd.nextDouble() * 2 * pi;

    // Conversão aproximada metros->graus
    final dLat = (r * cos(theta)) / 111000.0;
    final dLon = (r * sin(theta)) / (111000.0 * cos(base.latitudeInRad));

    return LatLng(base.latitude + dLat, base.longitude + dLon);
  }

  /// Retorna agrupamento por bairro (com coordenada centro real via geocoding).
  static Future<List<NeighborhoodGeoResult>> buildNeighborhoodCenters(
    List<Student> students, {
    String city = 'Parauapebas',
    String state = 'PA',
  }) async {
    // Agrupa por bairro
    final Map<String, List<Student>> groups = {};
    final Map<String, String> displayNames = {};

    for (final s in students) {
      if (!isInParauapebas(s)) continue;

      final raw = s.address.neighborhood;
      if (_isGarbageNeighborhood(raw)) continue;

      final key = _neighborhoodKey(raw);
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(s);

      displayNames.putIfAbsent(key, () => _displayNeighborhood(raw));
    }

    final results = <NeighborhoodGeoResult>[];

    // Geocoda em sequência
    for (final entry in groups.entries) {
      final key = entry.key;
      final list = entry.value;
      final display = displayNames[key] ?? 'Desconhecido';

      final center = await _geocodeNeighborhood(
            neighborhood: display,
            city: city,
            state: state,
          ) ??
          parauapebasCenter;

      results.add(
        NeighborhoodGeoResult(
          neighborhoodKey: key,
          neighborhoodDisplay: display,
          center: center,
          students: list,
        ),
      );
    }

    // Ordena por quantidade (para chips)
    results.sort((a, b) => b.students.length.compareTo(a.students.length));
    return results;
  }

  static Future<List<StudentMapPoint>> buildPointsFromNeighborhoodCenters(
    List<NeighborhoodGeoResult> centers,
  ) async {
    final points = <StudentMapPoint>[];

    for (final c in centers) {
      for (final s in c.students) {
        points.add(
          StudentMapPoint(
            student: s,
            position: _jitterNear(c.center, s),
            neighborhoodDisplay: c.neighborhoodDisplay,
          ),
        );
      }
    }

    return points;
  }

  static int countPending(List<Student> students) {
    int pending = 0;
    for (final s in students) {
      if (!isInParauapebas(s)) {
        pending++;
        continue;
      }
      final raw = s.address.neighborhood;
      if (_isGarbageNeighborhood(raw)) pending++;
    }
    return pending;
  }

  static String compactAddress(Student s) {
    final a = s.address;

    final parts = <String>[];

    if (a.street.trim().isNotEmpty) parts.add(a.street.trim());

    // número / quadra / lote (se existir)
    final detail = <String>[];
    if ((a.number ?? '').trim().isNotEmpty)
      detail.add('Nº ${(a.number ?? '').trim()}');
    if ((a.block ?? '').trim().isNotEmpty)
      detail.add('Qd ${(a.block ?? '').trim()}');
    if ((a.lot ?? '').trim().isNotEmpty)
      detail.add('Lt ${(a.lot ?? '').trim()}');

    if (detail.isNotEmpty) parts.add(detail.join(' • '));

    final nb = a.neighborhood.trim().isNotEmpty
        ? a.neighborhood.trim()
        : 'Não informado';
    parts.add('Bairro: $nb');

    final city = a.city.trim().isNotEmpty ? a.city.trim() : '—';
    final st = a.state.trim().isNotEmpty ? a.state.trim() : '—';
    parts.add('$city/$st');

    return parts.join(' | ');
  }

  /// Calcula a distância em quilômetros em linha reta
  static double getDistanceToSchoolInKm(LatLng studentLocation) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, schoolLocation, studentLocation);
  }
}
