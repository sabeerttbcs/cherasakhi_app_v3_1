import 'dart:js_interop';

class PickedContact {
  const PickedContact({required this.name, required this.phoneNumbers});

  final String name;
  final List<String> phoneNumbers;
}

@JS()
extension type _ContactsManager._(JSObject _) implements JSObject {
  external JSPromise<JSArray<_Contact>> select(JSArray<JSString> properties);
}

@JS()
extension type _Contact._(JSObject _) implements JSObject {
  external JSArray<JSString>? get name;
  external JSArray<JSString>? get tel;
}

@JS('navigator.contacts')
external _ContactsManager? get _contacts;

bool get contactPickerSupported => _contacts != null;

Future<PickedContact?> pickContact() async {
  final contacts = _contacts;
  if (contacts == null) return null;

  try {
    // The browser receives only these two properties and returns only the
    // single contact deliberately selected by the admin.
    final properties = <JSString>['name'.toJS, 'tel'.toJS].toJS;
    final selected = (await contacts.select(properties).toDart).toDart;
    if (selected.isEmpty) return null;
    final contact = selected.first;
    return PickedContact(
      name: _strings(contact.name).firstOrNull ?? '',
      phoneNumbers: _strings(contact.tel),
    );
  } catch (_) {
    // Cancellation and unsupported browser implementations are both safe
    // fallbacks to the editable fields.
    return null;
  }
}

List<String> _strings(JSArray<JSString>? values) =>
    values?.toDart
        .map((value) => value.toDart.trim())
        .where((value) => value.isNotEmpty)
        .toList() ??
    const [];

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
