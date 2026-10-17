import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gold_button.dart';
import '../../../community/domain/community_models.dart';
import '../../../community/presentation/community_providers.dart';
import '../../../kuri/domain/entities/member.dart';
import '../../../kuri/presentation/providers/kuri_providers.dart';
import '../../data/event_split_repository.dart';
import '../../domain/entities/event_models.dart';
import '../../domain/split/split_engine.dart';
import '../../domain/split/trip_participant.dart';
import '../controllers/event_split_controller.dart';
import 'event_split_dashboard.dart';
import 'split_format.dart';

/// Admin: who is on the trip. Adding / removing people re-splits every bill.
Future<void> showParticipantsSheet(BuildContext context, EventFund event) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ParticipantsSheet(event: event),
    );

class ParticipantsSheet extends ConsumerStatefulWidget {
  const ParticipantsSheet({super.key, required this.event});

  final EventFund event;

  @override
  ConsumerState<ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends ConsumerState<ParticipantsSheet> {
  final _search = TextEditingController();
  final _guest = TextEditingController();
  final Map<String, ParticipantDraft> _picked = {};
  final List<ParticipantDraft> _guests = [];
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    _guest.dispose();
    super.dispose();
  }

  int get _pendingCount => _picked.length + _guests.length;

  Future<void> _add(EventSplitController controller) async {
    if (_pendingCount == 0) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.addParticipants([..._picked.values, ..._guests]);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$_pendingCount added — all bills re-split')));
      setState(() {
        _picked.clear();
        _guests.clear();
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not add: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final split = ref.watch(eventSplitControllerProvider(widget.event.id));
    final controller = ref.read(eventSplitControllerProvider(widget.event.id).notifier);
    final listed = {for (final p in split.participants) p.id};
    final q = _search.text.trim().toLowerCase();

    final kuri = (ref.watch(membersProvider).valueOrNull ?? const <Member>[])
        .where((m) => m.isActive && !listed.contains(m.id))
        .where((m) => q.isEmpty || m.name.toLowerCase().contains(q));
    final community = (ref.watch(communityRosterProvider).valueOrNull ?? const <CommunityPerson>[])
        .where((c) => !listed.contains(c.id))
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q));

    final n = split.summary.activeCount;
    final previewN = n + _pendingCount;
    final total = split.summary.totalCostPaise;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text('Trip participants', style: theme.textTheme.titleLarge),
                Text('$n sharing · ${formatPaise(split.summary.perPersonPaise, exact: true)} each',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                for (final p in sortedParticipants(split.participants))
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: p.active,
                    activeColor: AppColors.blossom,
                    title: Text(p.name),
                    subtitle: Text(_balanceLine(split.summary.balanceOf(p.id), p)),
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      controller.setActive(p.id, v);
                    },
                  ),
                const Divider(height: 28),
                Text('Add people', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Search roster', prefixIcon: Icon(Icons.search_rounded)),
                ),
                const SizedBox(height: 6),
                for (final m in kuri)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _picked.containsKey(m.id),
                    title: Text(m.name),
                    subtitle: const Text('Kuri member'),
                    onChanged: (v) => setState(() => v == true
                        ? _picked[m.id] = ParticipantDraft(name: m.name, kind: ParticipantKind.kuri, rosterId: m.id)
                        : _picked.remove(m.id)),
                  ),
                for (final c in community)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _picked.containsKey(c.id),
                    title: Text(c.name),
                    subtitle: const Text('Community member'),
                    onChanged: (v) => setState(() => v == true
                        ? _picked[c.id] = ParticipantDraft(name: c.name, kind: ParticipantKind.community, rosterId: c.id)
                        : _picked.remove(c.id)),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _guest,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Guest (not in the app)',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () {
                        final name = _guest.text.trim();
                        if (name.length < 2) return;
                        setState(() {
                          _guests.add(ParticipantDraft(name: name, kind: ParticipantKind.guest));
                          _guest.clear();
                        });
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                if (_guests.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final g in _guests)
                        InputChip(label: Text(g.name), onDeleted: () => setState(() => _guests.remove(g))),
                    ],
                  ),
              ],
            ),
          ),
          if (_pendingCount > 0)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    Text(
                      'Share becomes ${formatPaise(previewN == 0 ? 0 : total / previewN, exact: true)} '
                      'per person (÷ $previewN)',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.berry, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    GoldButton(
                      label: 'ADD $_pendingCount ${_pendingCount == 1 ? 'PERSON' : 'PEOPLE'}',
                      icon: Icons.group_add_rounded,
                      loading: _saving,
                      expand: true,
                      onPressed: () => _add(controller),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _balanceLine(ParticipantBalance? b, TripParticipant p) {
    final kind = switch (p.kind) {
      ParticipantKind.kuri => 'Kuri',
      ParticipantKind.community => 'Community',
      ParticipantKind.guest => 'Guest',
    };
    if (b == null) return kind;
    return '$kind · paid ${formatPaise(b.paidUpfrontPaise)} · ${p.active ? 'share ${formatPaise(b.shareDuePaise, exact: true)}' : 'not sharing'}';
  }
}
