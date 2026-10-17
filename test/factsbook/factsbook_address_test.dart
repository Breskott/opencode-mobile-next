// A FactsBook node is reached only over a private path: the bearer token
// travels in clear text.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_address.dart';

void main() {
  test('private addresses parse, with the default port', () {
    expect(
      FactsBookAddress.parse('127.0.0.1'),
      Uri.parse('http://127.0.0.1:8787'),
    );
    expect(
      FactsBookAddress.parse('http://192.168.1.20:9000'),
      Uri.parse('http://192.168.1.20:9000'),
    );
    expect(
      FactsBookAddress.parse(' phone.local:8787 '),
      Uri.parse('http://phone.local:8787'),
    );
    expect(FactsBookAddress.parse('10.0.0.4')!.host, '10.0.0.4');
    expect(FactsBookAddress.parse('172.20.1.1')!.host, '172.20.1.1');
    expect(FactsBookAddress.parse('100.101.102.103')!.host, '100.101.102.103');
    expect(
      FactsBookAddress.parse('node.tail1234.ts.net')!.host,
      'node.tail1234.ts.net',
    );
    expect(FactsBookAddress.parse('localhost:1')!.port, 1);
  });

  test('anything public, odd or carrying credentials is refused', () {
    for (final bad in [
      '',
      '   ',
      '8.8.8.8',
      'example.com',
      '172.32.0.1',
      '100.128.0.1',
      '192.169.0.1',
      'ftp://127.0.0.1',
      'http://user:pass@127.0.0.1',
      'http://127.0.0.1?x=1',
      'http://127.0.0.1/#frag',
      '999.1.1.1',
      'a' * 300,
    ]) {
      expect(FactsBookAddress.parse(bad), isNull, reason: bad);
    }
  });
}
