import 'package:academyhub_mobile/model/app_notification_model.dart';
import 'package:academyhub_mobile/providers/app_notification_provider.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

Future<void> showAppNotificationCenterSheet({
  required BuildContext context,
  required ValueChanged<AppNotificationItem> onNotificationTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (_) => _AppNotificationCenterSheet(
      onNotificationTap: onNotificationTap,
    ),
  );
}

class _AppNotificationCenterSheet extends StatefulWidget {
  final ValueChanged<AppNotificationItem> onNotificationTap;

  const _AppNotificationCenterSheet({
    required this.onNotificationTap,
  });

  @override
  State<_AppNotificationCenterSheet> createState() =>
      _AppNotificationCenterSheetState();
}

class _AppNotificationCenterSheetState
    extends State<_AppNotificationCenterSheet> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF223042) : const Color(0xFFE5E7EB);
    final softSurface =
        isDark ? const Color(0xFF121A23) : const Color(0xFFF8FAFC);

    return SafeArea(
      child: Consumer<AppNotificationProvider>(
        builder: (context, provider, _) {
          final notifications = provider.items;
          final token = context.read<AuthProvider>().token;
          if (notifications.isNotEmpty && provider.unreadCount > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context
                  .read<AppNotificationProvider>()
                  .markDisplayedAsRead(notifications, token);
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 0.72.sh),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44.w,
                      height: 5.h,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notificações',
                              style: GoogleFonts.inter(
                                color: textPrimary,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Atualizações recentes do portal.',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (provider.unreadCount > 0)
                        TextButton(
                          onPressed: () => provider.markAllAsRead(token),
                          child: const Text('Marcar lidas'),
                        ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  if (notifications.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(18.r),
                      decoration: BoxDecoration(
                        color: softSurface,
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            PhosphorIcons.bell_simple_slash_fill,
                            color: textSecondary,
                            size: 28.sp,
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            'Nada novo por enquanto',
                            style: GoogleFonts.inter(
                              color: textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Quando a escola atualizar documentos, atividades ou avisos, aparecerá aqui.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 12.sp,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          return _NotificationTile(
                            item: item,
                            softSurface: softSurface,
                            border: border,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () => widget.onNotificationTap(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationItem item;
  final Color softSurface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.softSurface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _priorityColor(item.priority);
    final history = item.history;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: item.isUnread
              ? accent.withValues(alpha: 0.08)
              : softSurface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: item.isUnread ? accent.withValues(alpha: 0.26) : border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _domainIcon(item.domain),
                color: accent,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (item.isUnread)
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    item.summary,
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  if (history.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    _NotificationThreadHistory(
                      history: history,
                      accent: accent,
                      border: border,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Text(
                    DateFormat('dd/MM HH:mm', 'pt_BR')
                        .format(item.createdAt.toLocal()),
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              PhosphorIcons.caret_right_bold,
              color: textSecondary,
              size: 14.sp,
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(AppNotificationPriority priority) {
    switch (priority) {
      case AppNotificationPriority.success:
        return const Color(0xFF00A859);
      case AppNotificationPriority.warning:
        return const Color(0xFFF59E0B);
      case AppNotificationPriority.critical:
        return const Color(0xFFEF4444);
      case AppNotificationPriority.info:
        return const Color(0xFF2F80ED);
    }
  }

  IconData _domainIcon(AppNotificationDomain domain) {
    switch (domain) {
      case AppNotificationDomain.documents:
        return PhosphorIcons.files_fill;
      case AppNotificationDomain.activities:
        return PhosphorIcons.clipboard_text_fill;
      case AppNotificationDomain.finance:
        return PhosphorIcons.receipt_fill;
      case AppNotificationDomain.academic:
        return PhosphorIcons.student_fill;
      case AppNotificationDomain.system:
        return PhosphorIcons.bell_fill;
    }
  }
}

class _NotificationThreadHistory extends StatelessWidget {
  final List<AppNotificationHistoryEntry> history;
  final Color accent;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const _NotificationThreadHistory({
    required this.history,
    required this.accent,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final visibleHistory = history.take(2).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: border.withValues(alpha: 0.78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${history.length} atualização${history.length == 1 ? '' : 'es'} anterior${history.length == 1 ? '' : 'es'} neste contexto',
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 10.8.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          for (final entry in visibleHistory)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Text(
                '${entry.title} · ${DateFormat('dd/MM HH:mm', 'pt_BR').format(entry.occurredAt.toLocal())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
