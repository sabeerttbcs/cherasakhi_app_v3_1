// PLACEHOLDER — this file is REPLACED when you run:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// See README.md, step 3.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured yet. Run `flutterfire configure` '
        'in the project root to generate lib/firebase_options.dart.',
      );
}
