/// Display-safe masking of credentials in text the app shows, copies or
/// shares (AGENTS.md security invariants: provider keys must never reach
/// logs, diagnostics, notification copy or the clipboard).
///
/// A secret becomes "•••". Where a key's prefix is public (it only names the
/// provider), the prefix stays as a hint: `sk-ant-•••`, `ghp_•••`, `AIza•••`.
///
/// Masked:
/// - provider keys: `sk-`, `sk-ant-`, `sk-proj-`, `AIza`, `ghp_`/`gho_`/
///   `ghs_`/`ghu_`/`ghr_`, `github_pat_`, `xoxa-`/`xoxb-`/`xoxp-`/`xoxr-`;
/// - `Bearer <token>`;
/// - the value of an `Authorization` or `Proxy-Authorization` header, written
///   `Authorization: x` or `Authorization=x`;
/// - the value after `api_key`, `apikey`, `token`, `secret`, `password` or
///   `passwd` (also as the tail of a longer name such as `client_secret`)
///   and `=` or `:`, quoted or not;
/// - URL user-info: `https://user:pass@host` → `https://•••@host`;
/// - JWTs (three base64url segments, the first starting `eyJ`).
///
/// Never touched: file paths, git SHAs, UUIDs, ordinary long words.
abstract final class KitRedact {
  /// What a secret is replaced with.
  static const String mask = '\u2022\u2022\u2022';

  static final RegExp _authHeader = RegExp(
    r'\b((?:Proxy-)?Authorization)(["\x27]?\s*[:=]\s*)(["\x27]?)([^\r\n"\x27,;&]+)',
    caseSensitive: false,
  );

  static final RegExp _bearer = RegExp(
    r'\b(Bearer)\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );

  static final RegExp _namedValue = RegExp(
    r'(?<![A-Za-z0-9])([A-Za-z0-9_\-]*?(?:api[_\-]?key|apikey|token|secret|password|passwd))'
    r'(["\x27]?\s*[:=]\s*)(["\x27]?)([^\s"\x27,;&<>]+)',
    caseSensitive: false,
  );

  static final RegExp _urlUserInfo = RegExp(
    r'\b([A-Za-z][A-Za-z0-9+.\-]*://)[^\s/?#@]+@',
  );

  static final RegExp _jwt = RegExp(
    r'(?<![A-Za-z0-9_\-])eyJ[A-Za-z0-9_\-]{4,}\.[A-Za-z0-9_\-]{4,}\.[A-Za-z0-9_\-]+',
  );

  /// Provider keys, most specific prefix first. Group 1 is the public
  /// prefix that stays as a hint.
  static final List<RegExp> _providerKeys = [
    RegExp(r'(?<![A-Za-z0-9_\-])(sk-ant-)[A-Za-z0-9_\-]{8,}'),
    RegExp(r'(?<![A-Za-z0-9_\-])(sk-proj-)[A-Za-z0-9_\-]{8,}'),
    RegExp(r'(?<![A-Za-z0-9_\-])(sk-)[A-Za-z0-9_\-]{16,}'),
    RegExp(r'(?<![A-Za-z0-9_\-])(AIza)[A-Za-z0-9_\-]{30,}'),
    RegExp(r'(?<![A-Za-z0-9_\-])(github_pat_)[A-Za-z0-9_]{20,}'),
    RegExp(r'(?<![A-Za-z0-9_\-])(gh[pousr]_)[A-Za-z0-9]{20,}'),
    RegExp(r'(?<![A-Za-z0-9_\-])(xox[abpr]-)[A-Za-z0-9\-]{10,}'),
  ];

  /// [s] with every recognised secret replaced by [mask].
  static String text(String s) {
    if (s.isEmpty) return s;
    var out = s.replaceAllMapped(
      _authHeader,
      (m) => '${m[1]}${m[2]}${m[3]}$mask',
    );
    out = out.replaceAllMapped(_bearer, (m) => '${m[1]} $mask');
    out = out.replaceAllMapped(
      _namedValue,
      (m) => '${m[1]}${m[2]}${m[3]}$mask',
    );
    out = out.replaceAllMapped(_urlUserInfo, (m) => '${m[1]}$mask@');
    for (final key in _providerKeys) {
      out = out.replaceAllMapped(key, (m) => '${m[1]}$mask');
    }
    return out.replaceAll(_jwt, mask);
  }

  /// Whether [text] would change [s]: it holds something that looks like a
  /// secret.
  static bool containsSecret(String s) => text(s) != s;
}
