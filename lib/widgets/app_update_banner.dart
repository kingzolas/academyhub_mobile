import 'package:academyhub_mobile/services/app_update_models.dart';
import 'package:academyhub_mobile/services/app_update_safety.dart';
import 'package:academyhub_mobile/services/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Keeps update handling at the application shell. It deliberately does not
/// force navigation: a person must be able to save an in-progress operation
/// before requesting the one controlled reload.
class AppUpdateWatcher extends StatefulWidget {
  const AppUpdateWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateWatcher> createState() => _AppUpdateWatcherState();
}

class _AppUpdateWatcherState extends State<AppUpdateWatcher> {
  final AppUpdateService _service = AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _service.start();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final shouldShow = _service.isUpdateAvailable ||
            _service.state == AppUpdateState.offline ||
            _service.state == AppUpdateState.failed;
        return Stack(
          children: [
            widget.child,
            if (shouldShow)
              _UpdateNotice(
                service: _service,
                waitingForSave: !AppUpdateSafety.instance.canReload,
              ),
          ],
        );
      },
    );
  }
}

class _UpdateNotice extends StatelessWidget {
  const _UpdateNotice({required this.service, required this.waitingForSave});

  final AppUpdateService service;
  final bool waitingForSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final updateAvailable = service.isUpdateAvailable;
    final failed = service.state == AppUpdateState.failed;
    final offline = service.state == AppUpdateState.offline;
    final title = updateAvailable
        ? 'Atualização disponível'
        : offline
            ? 'Verificação de atualização indisponível'
            : 'Não foi possível verificar a atualização';
    final message = updateAvailable
        ? waitingForSave
            ? 'Salve ou conclua a operação em andamento antes de atualizar.'
            : 'Uma nova versão do AcademyHub está pronta. Atualize para continuar utilizando o sistema com segurança.'
        : offline
            ? 'O dispositivo está offline. A verificação será retomada quando a conexão voltar, sem apagar seus dados locais.'
            : 'A verificação falhou temporariamente. Você pode tentar novamente.';

    return Positioned(
      left: 12,
      right: 12,
      top: 12,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (failed || offline)
                      OutlinedButton.icon(
                        onPressed: service.isChecking
                            ? null
                            : () => service.checkNow(reason: 'user-retry'),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    if (updateAvailable)
                      FilledButton.icon(
                        onPressed: waitingForSave || service.isBusy
                            ? null
                            : service.reloadToUpdate,
                        icon: const Icon(Icons.system_update_alt),
                        label: Text(
                          waitingForSave
                              ? 'Aguardar conclusão do salvamento'
                              : 'Atualizar agora',
                        ),
                      ),
                  ],
                );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.system_update_alt, color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(message, style: Theme.of(context).textTheme.bodySmall),
                    if (service.remoteBuild != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Build disponível: ${service.remoteBuild!.buildId}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                    if (failed && service.lastError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        service.lastError!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [details, const SizedBox(height: 10), actions],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 14),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
