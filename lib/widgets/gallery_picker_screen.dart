import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/design/tokens.dart';
import '../core/i18n/i18n.dart';
import 'components/components.dart';

/// A picked item resolved to a local file plus whether it is a video.
class PickedMedia {
  const PickedMedia(this.file, this.isVideo);
  final File file;
  final bool isVideo;
}

/// A reusable in-app gallery grid (like Instagram/Facebook): recent device
/// photos/videos with a camera tile first. In [multi] mode items get an
/// ordered number badge and a "Done" action; otherwise the first tap resolves
/// and returns immediately. Pops a `List<PickedMedia>` (or null if cancelled).
class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({
    super.key,
    this.multi = false,
    this.requestType = RequestType.common,
    this.title,
  });

  final bool multi;
  final RequestType requestType;
  final String? title;

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  bool _loading = true;
  bool _resolving = false;
  PermissionState? _perm;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    _perm = ps;
    if (ps.isAuth || ps.hasAccess) {
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: widget.requestType,
      );
      if (albums.isNotEmpty) {
        final recent = await albums.first.getAssetListPaged(page: 0, size: 120);
        if (mounted) setState(() => _assets = recent);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onTapAsset(AssetEntity asset) async {
    if (!widget.multi) {
      final f = await asset.file;
      if (f != null && mounted) {
        Navigator.of(context).pop([
          PickedMedia(f, asset.type == AssetType.video),
        ]);
      }
      return;
    }
    setState(() {
      _selected.contains(asset)
          ? _selected.remove(asset)
          : _selected.add(asset);
    });
  }

  Future<void> _done() async {
    if (_selected.isEmpty) return;
    setState(() => _resolving = true);
    final out = <PickedMedia>[];
    for (final a in _selected) {
      final f = await a.file;
      if (f != null) out.add(PickedMedia(f, a.type == AssetType.video));
    }
    if (mounted) Navigator.of(context).pop(out);
  }

  Future<void> _camera() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (x != null && mounted) {
      Navigator.of(context).pop([PickedMedia(File(x.path), false)]);
    }
  }

  Future<void> _systemFallback() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1440,
    );
    if (x != null && mounted) {
      Navigator.of(context).pop([PickedMedia(File(x.path), false)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDone = widget.multi && _selected.isNotEmpty;
    return AppScaffold(
      topBar: AppTopBar(
        title: widget.title ?? tr('Chọn ảnh/video', 'Pick photo/video'),
        showBack: true,
        actions: [
          if (widget.multi)
            PressScale(
              onTap: canDone && !_resolving ? _done : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Center(
                  child: Text(
                    canDone
                        ? tr('Xong (${_selected.length})', 'Done (${_selected.length})')
                        : tr('Xong', 'Done'),
                    style: AppText.h3.copyWith(
                      color: canDone
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      fontWeight: AppType.bold,
                    ),
                  ),
                ),
              ),
            )
          else
            AppIconButton(
              icon: Icons.photo_camera_rounded,
              tooltip: tr('Chụp ảnh', 'Take a photo'),
              onTap: _camera,
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _body(),
    );
  }

  Widget _body() {
    final ps = _perm;
    if (ps != null && !ps.isAuth && !ps.hasAccess) return _denied();
    return Column(
      children: [
        if (ps != null && !ps.isAuth && ps.hasAccess) _limitedBanner(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: _assets.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return _cameraTile();
              final asset = _assets[i - 1];
              final selIndex = _selected.indexOf(asset);
              return _AssetThumb(
                key: ValueKey(asset.id),
                asset: asset,
                selectionNumber: selIndex >= 0 ? selIndex + 1 : null,
                onTap: () => _onTapAsset(asset),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cameraTile() {
    return PressScale(
      onTap: _camera,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBright, AppColors.primary],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_camera_rounded,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(height: 6),
            Text(
              tr('Camera', 'Camera'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppType.label,
                fontWeight: AppType.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _limitedBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.layer2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(
                'Chỉ một số ảnh được chia sẻ với ứng dụng.',
                'Only some photos are shared with the app.',
              ),
              style: AppText.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          PressScale(
            onTap: () async {
              await PhotoManager.presentLimited();
              setState(() => _loading = true);
              _loadAssets();
            },
            child: Text(
              tr('Quản lý', 'Manage'),
              style: AppText.label.copyWith(
                color: AppColors.primary,
                fontWeight: AppType.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _denied() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tr(
              'Cho phép truy cập ảnh để chọn\nảnh/video ngay trong ứng dụng.',
              'Allow photo access to pick media\nright inside the app.',
            ),
            textAlign: TextAlign.center,
            style: AppText.h3.copyWith(
              color: AppColors.textSecondary,
              fontWeight: AppType.regular,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: tr('Mở cài đặt', 'Open settings'),
            fullWidth: false,
            onPressed: () => PhotoManager.openSetting(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: tr('Chọn từ thư viện', 'Pick from library'),
            variant: AppButtonVariant.ghost,
            fullWidth: false,
            onPressed: _systemFallback,
          ),
        ],
      ),
    );
  }
}

/// One gallery cell: the thumbnail, a video duration badge, and (in multi mode)
/// an ordered selection number with a highlight ring.
class _AssetThumb extends StatefulWidget {
  const _AssetThumb({
    super.key,
    required this.asset,
    required this.onTap,
    this.selectionNumber,
  });

  final AssetEntity asset;
  final VoidCallback onTap;
  final int? selectionNumber;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(300),
    );
    if (mounted) setState(() => _bytes = data);
  }

  String _dur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.type == AssetType.video;
    final selected = widget.selectionNumber != null;
    return PressScale(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.layer2,
            child: _bytes == null
                ? const SizedBox.shrink()
                : Image.memory(_bytes!, fit: BoxFit.cover),
          ),
          if (selected)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                border: Border.all(color: AppColors.primary, width: 3),
              ),
            ),
          if (isVideo)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _dur(widget.asset.videoDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppType.small,
                        fontWeight: AppType.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '${widget.selectionNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppType.small,
                    fontWeight: AppType.heavy,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
