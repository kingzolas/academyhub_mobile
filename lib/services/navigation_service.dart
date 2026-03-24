// lib/services/navigation_service.dart
import 'package:flutter/material.dart';

class NavigationService {
  // Essa chave global vai ser atrelada ao MaterialApp
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
