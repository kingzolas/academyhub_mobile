import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyProvider extends ChangeNotifier {
  static const _keyHideFinancialValues = 'hide_financial_values';
  static const _keyRevealedCards = 'revealed_financial_cards';

  bool _hideFinancialValues = false;
  final Set<String> _revealedCards = <String>{};
  bool _loaded = false;

  PrivacyProvider() {
    debugPrint('[PrivacyProvider] CONSTRUCT -> hash=$hashCode');
  }

  bool get hideFinancialValues => _hideFinancialValues;
  bool get isLoaded => _loaded;

  /// Quando hideFinancialValues=true, o item fica oculto por padrão.
  /// Se o id estiver em _revealedCards, ele é mostrado.
  bool isHiddenFor(String id) {
    if (!_hideFinancialValues) return false;
    return !_revealedCards.contains(id);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _hideFinancialValues = prefs.getBool(_keyHideFinancialValues) ?? false;
    _revealedCards
      ..clear()
      ..addAll(prefs.getStringList(_keyRevealedCards) ?? const <String>[]);

    _loaded = true;

    debugPrint(
      '[PrivacyProvider] load -> hash=$hashCode hide=$_hideFinancialValues revealed=${_revealedCards.toList()}',
    );

    notifyListeners();
  }

  Future<void> setHideFinancialValues(bool value) async {
    _hideFinancialValues = value;

    // UX/segurança:
    // Ao alternar modo, limpa revelações pontuais
    _revealedCards.clear();

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final ok1 = await prefs.setBool(_keyHideFinancialValues, value);
    final ok2 =
        await prefs.setStringList(_keyRevealedCards, _revealedCards.toList());

    debugPrint(
        '[PrivacyProvider] setHide($value) -> hash=$hashCode okBool=$ok1 okList=$ok2');
  }

  Future<void> toggleHideFinancialValues() async {
    await setHideFinancialValues(!_hideFinancialValues);
  }

  Future<void> toggleRevealCard(String id) async {
    if (!_hideFinancialValues) {
      debugPrint(
          '[PrivacyProvider] toggleReveal ignored (not private) hash=$hashCode');
      return;
    }

    if (_revealedCards.contains(id)) {
      _revealedCards.remove(id);
    } else {
      _revealedCards.add(id);
    }

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final ok =
        await prefs.setStringList(_keyRevealedCards, _revealedCards.toList());

    debugPrint(
        '[PrivacyProvider] toggleReveal($id) -> hash=$hashCode revealed=${_revealedCards.toList()} ok=$ok');
  }
}
