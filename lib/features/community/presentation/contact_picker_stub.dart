class PickedContact {
  const PickedContact({required this.name, required this.phoneNumbers});

  final String name;
  final List<String> phoneNumbers;
}

bool get contactPickerSupported => false;

Future<PickedContact?> pickContact() async => null;
