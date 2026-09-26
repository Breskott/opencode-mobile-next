// KitRedact: secrets are masked for display and copy; technical values that
// merely look long (paths, SHAs, UUIDs, words) pass through untouched.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

const m = KitRedact.mask;

void main() {
  group('masks', () {
    final cases = <String, String>{
      'key sk-ant-api03-AbCdEfGhIjKlMnOpQrSt done': 'key sk-ant-$m done',
      'sk-proj-AbCdEfGhIjKlMnOpQrStUv': 'sk-proj-$m',
      'OPENAI=sk-AbCdEfGhIjKlMnOpQrSt12': 'OPENAI=sk-$m',
      'AIzaSyA1234567890abcdefghijklmnopqrstu': 'AIza$m',
      'ghp_0123456789abcdefghijABCDEFGHIJ': 'ghp_$m',
      'gho_0123456789abcdefghijABCDEFGHIJ': 'gho_$m',
      'ghs_0123456789abcdefghijABCDEFGHIJ': 'ghs_$m',
      'github_pat_11ABCDEFG0123456789_abcdefghijklmnop': 'github_pat_$m',
      'slack xoxb-1234567890-abcdefghij': 'slack xoxb-$m',
      'xoxp-1234567890-abcdefghij': 'xoxp-$m',
      'curl -H Bearer abc.def-ghi_123': 'curl -H Bearer $m',
      'Authorization: Basic b3BlbmNvZGU6cGFzcw==': 'Authorization: $m',
      'authorization=Token xyz123': 'authorization=$m',
      'Proxy-Authorization: Basic Zm9vOmJhcg==': 'Proxy-Authorization: $m',
      '{"Authorization": "Bearer abc"}': '{"Authorization": "$m"}',
      'api_key=abc123': 'api_key=$m',
      'apikey: abc123': 'apikey: $m',
      'API-KEY=abc123': 'API-KEY=$m',
      'token=abc123&x=1': 'token=$m&x=1',
      'client_secret: s3cr3t': 'client_secret: $m',
      'password=hunter2 user=me': 'password=$m user=me',
      'passwd: hunter2': 'passwd: $m',
      '{"password":"hunter2"}': '{"password":"$m"}',
      "secret = 'abc'": "secret = '$m'",
      'https://user:pass@example.com/x': 'https://$m@example.com/x',
      'git clone https://ghtoken@github.com/o/r':
          'git clone https://$m@github.com/o/r',
      'jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig-nat_ure end': 'jwt $m end',
    };
    for (final e in cases.entries) {
      test(e.key, () {
        expect(KitRedact.text(e.key), e.value);
        expect(KitRedact.containsSecret(e.key), isTrue);
      });
    }

    test('is idempotent', () {
      for (final input in cases.keys) {
        final once = KitRedact.text(input);
        expect(KitRedact.text(once), once);
      }
    });
  });

  group('leaves alone', () {
    const untouched = [
      '',
      '/home/eslam/Storage/Code/oc_app/lib/ui/kit/kit_secret_field.dart',
      r'C:\Users\me\token\notes.txt',
      'b72cf95f3a1e9c0d4b5a6f7e8d9c0b1a2f3e4d5c',
      'b72cf95f',
      '123e4567-e89b-12d3-a456-426614174000',
      'Pneumonoultramicroscopicsilicovolcanoconiosis',
      'the task-abcdefghijklmnopqrstu finished',
      'risk-assessment-document-version-two',
      'Tokens: 1,234 input, 56 output',
      'max_tokens=4096',
      'Enter your password below',
      'https://example.com/path?q=1',
      'git@github.com:owner/repo.git',
      'The Authorization header is missing',
      'Bearer',
      'sk-short',
      'ghp_short',
      'eyJhbGciOi only one segment',
    ];
    for (final s in untouched) {
      test(s.isEmpty ? '(empty)' : s, () {
        expect(KitRedact.text(s), s);
        expect(KitRedact.containsSecret(s), isFalse);
      });
    }
  });
}
