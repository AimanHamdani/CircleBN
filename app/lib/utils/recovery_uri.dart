/// Appwrite recovery links append `userId`, `secret`, and `expire` to your redirect URL.
///
/// On **Flutter web**, older hash routing can put `?userId=…` inside [Uri.fragment] instead of
/// [Uri.queryParameters]. This merges both so **Chrome** and **native** builds share one code path.
///
/// **Android / iOS:** Opening the app from an email link usually requires **App Links / Universal Links**
/// (and matching intent filters). Until then, users can open **Reset password → I have reset code**.
Map<String, String> recoveryLinkQueryParameters() {
  final uri = Uri.base;
  final out = Map<String, String>.from(uri.queryParameters);

  void mergeQueryString(String? qs) {
    if (qs == null || qs.isEmpty) {
      return;
    }
    out.addAll(Uri.splitQueryString(qs));
  }

  final fragment = uri.fragment;
  if (fragment.contains('?')) {
    mergeQueryString(fragment.substring(fragment.indexOf('?') + 1));
  }

  return out;
}

bool recoveryLinkHasCredentials(Map<String, String> qp) {
  return qp['userId']?.isNotEmpty == true && qp['secret']?.isNotEmpty == true;
}
