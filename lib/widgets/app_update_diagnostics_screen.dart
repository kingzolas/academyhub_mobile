import 'package:academyhub_mobile/services/app_update_service.dart';
import 'package:flutter/material.dart';

class AppUpdateDiagnosticsScreen extends StatefulWidget {
  const AppUpdateDiagnosticsScreen({super.key});

  @override
  State<AppUpdateDiagnosticsScreen> createState() =>
      _AppUpdateDiagnosticsScreenState();
}

class _AppUpdateDiagnosticsScreenState
    extends State<AppUpdateDiagnosticsScreen> {
  final AppUpdateService _service = AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    _service.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de atualização')),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          final remote = _service.remoteBuild;
          final entries = <MapEntry<String, String>>[
            const MapEntry('Build em execução', AppUpdateService.currentBuildId),
            MapEntry('Estado', _service.state.name),
            MapEntry('Build publicado', remote?.buildId ?? '-'),
            MapEntry('Commit publicado', remote?.commit ?? '-'),
            MapEntry('Publicado em', remote?.deployedAt ?? '-'),
            MapEntry('Service worker', _service.workerSummary ?? '-'),
            MapEntry('Última falha', _service.lastError ?? '-'),
          ];
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == entries.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FilledButton.icon(
                    onPressed: _service.isChecking
                        ? null
                        : () => _service.checkNow(reason: 'diagnostics'),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Verificar agora'),
                  ),
                );
              }
              final entry = entries[index];
              return ListTile(
                title: Text(entry.key),
                subtitle: SelectableText(entry.value),
              );
            },
          );
        },
      ),
    );
  }
}
