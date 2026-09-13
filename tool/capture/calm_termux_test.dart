// Real fonts for the existing synthetic running-server capture scenarios.
import 'package:flutter_test/flutter_test.dart';
import '../../test/termux_running_server_test.dart' as scenarios;
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  scenarios.main();
}
