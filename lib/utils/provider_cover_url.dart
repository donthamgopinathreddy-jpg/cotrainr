/// Canonical public cover field is `profiles.cover_url`.
/// Never substitute [avatarUrl] when cover is missing.
String? resolveProviderCoverUrl({
  String? coverUrl,
  String? avatarUrl,
}) {
  final cover = coverUrl?.trim();
  if (cover == null || cover.isEmpty) return null;

  final avatar = avatarUrl?.trim();
  if (avatar != null && avatar.isNotEmpty && cover == avatar) {
    return null;
  }

  final uri = Uri.tryParse(cover);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return cover;
}

/// Busts CachedNetworkImage keys after cover upsert to the same storage path.
String cacheBustedMediaUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return url;
  final params = Map<String, String>.from(uri.queryParameters);
  params['v'] = DateTime.now().millisecondsSinceEpoch.toString();
  return uri.replace(queryParameters: params).toString();
}
