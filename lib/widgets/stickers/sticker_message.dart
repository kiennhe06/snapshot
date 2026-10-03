import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/i18n/i18n.dart';
import '../components/components.dart';
import 'glossy_stickers.dart';

/// Stickers travel inside ordinary text comments/messages as a compact
/// sentinel — `[[sticker:heart]]` — so no model, repository or Firestore
/// schema has to change. The send path writes the token; the render path
/// detects it and draws the animated [GlossyStickerView] instead of text.
///
/// Keeping it a plain text payload also means replies, pins and the inbox
/// preview keep working unchanged — they just show a friendly label.
const _prefix = '[[sticker:';
const _suffix = ']]';

/// Encodes a sticker as its text payload, e.g. `[[sticker:boba]]`.
String stickerToken(GlossySticker s) => '$_prefix${s.name}$_suffix';

/// Returns the sticker a message/comment carries, or null for normal text.
/// The whole trimmed body must be exactly one sticker token.
GlossySticker? parseSticker(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (!t.startsWith(_prefix) || !t.endsWith(_suffix)) return null;
  final name = t.substring(_prefix.length, t.length - _suffix.length);
  for (final s in GlossySticker.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// A short label for preview surfaces (inbox row, reply banner, pinned bar)
/// where a live sticker would not fit — converts a token to "🧸 Sticker",
/// leaves ordinary text untouched.
String stickerPreviewOr(String? raw) {
  if (parseSticker(raw) != null) return '🧸 ${tr('Nhãn dán', 'Sticker')}';
  return raw ?? '';
}

/// Opens the sticker keyboard and resolves to the chosen sticker (or null if
/// dismissed). Shared by the comments and chat composers.
Future<GlossySticker?> showStickerPicker(BuildContext context) {
  return showAppSheet<GlossySticker>(
    context,
    builder: (sheetCtx) => AppSheetSurface(
      title: tr('Nhãn dán', 'Stickers'),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        children: [
          for (final s in GlossySticker.values)
            PressScale(
              onTap: () => Navigator.of(sheetCtx).pop(s),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlossyStickerView(s, size: 64),
                  const SizedBox(height: 2),
                  Text(
                    glossyStickerLabel(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
