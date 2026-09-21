import 'package:intl/intl.dart';

import '../i18n/i18n.dart';

/// Compact count formatting shared across the app so a value renders the same
/// everywhere: 128400 -> "128.4K", 2_100_000 -> "2.1M", 890 -> "890".
String formatCount(int n) {
  if (n < 0) return '0';
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final s = (n / 1000).toStringAsFixed(n % 1000 >= 100 ? 1 : 0);
    return '${s}K';
  }
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

/// Relative time shared across feed / reels / inbox / chat.
/// [short] gives the terse form ("5 phút" / "5m") used in dense lists;
/// otherwise the full form ("5 phút trước" / "5m ago").
String relativeTime(DateTime t, {bool short = false}) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr('vừa xong', 'now');
  final suffixVi = short ? '' : ' trước';
  final suffixEn = short ? '' : ' ago';
  if (d.inMinutes < 60) {
    return tr('${d.inMinutes} phút$suffixVi', '${d.inMinutes}m$suffixEn');
  }
  if (d.inHours < 24) {
    return tr('${d.inHours} giờ$suffixVi', '${d.inHours}h$suffixEn');
  }
  if (d.inDays < 7) {
    return tr('${d.inDays} ngày$suffixVi', '${d.inDays}d$suffixEn');
  }
  return DateFormat(short ? 'dd/MM' : 'dd/MM/yyyy').format(t);
}
