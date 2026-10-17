import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/member_avatar.dart';
import '../../domain/entities/member.dart';

/// Fixed-height (78px) row — used with SliverFixedExtentList for 60 items.
class MemberPaymentTile extends StatelessWidget {
  const MemberPaymentTile({
    super.key,
    required this.member,
    required this.paid,
    required this.isAdmin,
    required this.onToggle,
    required this.onRemind,
    this.onLongPress,
    this.isWinner = false,
  });

  final Member member;
  final bool paid;
  final bool isAdmin;
  final bool isWinner;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemind;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Opacity(
        opacity: member.isActive ? 1 : 0.45,
        child: GlassCard(
          blur: false,
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onLongPress: onLongPress,
          onTap: isAdmin && member.isActive ? () => onToggle(!paid) : null,
          borderColor: paid ? AppColors.blossom.withOpacity(0.35) : null,
          child: Row(
            children: [
              MemberAvatar(name: member.name, highlight: paid),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(member.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                        ),
                        if (isWinner)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.roseGoldLight),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${member.seatNo.toString().padLeft(2, '0')} · ${member.phone}'
                      '${member.isActive ? '' : ' · inactive'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!paid && member.isActive)
                IconButton(
                  tooltip: 'WhatsApp reminder',
                  onPressed: onRemind,
                  icon: const Icon(Icons.chat_rounded, color: AppColors.whatsapp),
                ),
              if (isAdmin && member.isActive)
                Switch.adaptive(
                  value: paid,
                  activeColor: AppColors.blossom,
                  onChanged: onToggle,
                )
              else
                _StatusPill(paid: paid),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.blossom : AppColors.roseGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(
        paid ? 'PAID' : 'DUE',
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8),
      ),
    );
  }
}
