import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/offline_sync_provider.dart';

class OfflineSyncBanner extends StatelessWidget {
  final Widget child;
  const OfflineSyncBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<OfflineSyncProvider>();
    String? text;
    Color color = const Color(0xFF455A64);
    if (!sync.isOnline) {
      text = 'Offline — alterações salvas neste dispositivo';
    } else if (sync.conflictCount > 0) {
      text = '${sync.conflictCount} chamada(s) aguardando revisão';
      color = const Color(0xFF8D6E00);
    } else if (sync.pendingCount > 0) {
      text = sync.isSyncing
          ? 'Sincronizando ${sync.pendingCount} chamada(s)…'
          : '${sync.pendingCount} chamada(s) aguardando sincronização';
    } else if (sync.confirmation != null) {
      text = sync.confirmation;
      color = const Color(0xFF2E7D32);
    }

    return Stack(
      children: [
        child,
        if (text != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 8,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
