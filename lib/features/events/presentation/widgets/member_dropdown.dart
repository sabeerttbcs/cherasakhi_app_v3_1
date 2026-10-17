import 'package:flutter/material.dart';

import '../../../kuri/domain/entities/member.dart';

class MemberDropdown extends StatelessWidget {
  const MemberDropdown({
    super.key,
    required this.label,
    required this.members,
    required this.value,
    required this.onChanged,
    this.icon = Icons.person_rounded,
  });

  final String label;
  final List<Member> members;
  final String? value;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: members.any((m) => m.id == value) ? value : null,
      isExpanded: true,
      menuMaxHeight: 420,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final m in members)
          DropdownMenuItem(value: m.id, child: Text('#${m.seatNo}  ${m.name}', overflow: TextOverflow.ellipsis)),
      ],
      validator: (v) => v == null ? 'Select a member' : null,
      onChanged: onChanged,
    );
  }
}
