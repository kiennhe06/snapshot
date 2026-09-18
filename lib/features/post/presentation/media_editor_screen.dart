import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../core/services/image_edit_service.dart';

/// Full-screen editor for one image: crop/rotate, filter preset, and
/// brightness/contrast/saturation. Returns the edited [File] via Navigator.pop.
class MediaEditorScreen extends StatefulWidget {
  const MediaEditorScreen({super.key, required this.source});

  final File source;

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  final _service = ImageEditService();
  late File _working; // after crop
  File? _preview; // after tone/filter
  double _brightness = 1.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  PhotoFilter _filter = PhotoFilter.none;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _working = widget.source;
  }

  Future<void> _regenerate() async {
    setState(() => _processing = true);
    final result = await _service.apply(
      source: _working,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      filter: _filter,
    );
    if (mounted) {
      setState(() {
        _preview = result;
        _processing = false;
      });
    }
  }

  Future<void> _crop() async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: _working.path,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Cắt ảnh', lockAspectRatio: false),
        IOSUiSettings(title: 'Cắt ảnh'),
      ],
    );
    if (cropped != null) {
      _working = File(cropped.path);
      await _regenerate();
    }
  }

  void _done() {
    // Return the processed preview if any, else the (possibly cropped) working file.
    Navigator.of(context).pop(_preview ?? _working);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _preview ?? _working;
    // Near-black editor panel/canvas (acceptable dark surface for a photo editor).
    const panelBg = AppColors.textPrimary;
    return AppScaffold(
      topBar: AppTopBar(
        title: 'Chỉnh sửa',
        showBack: true,
        actions: [
          AppButton(
            label: 'Xong',
            variant: AppButtonVariant.ghost,
            fullWidth: false,
            height: 40,
            onPressed: _processing ? null : _done,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: panelBg,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(shown, fit: BoxFit.contain),
                  if (_processing)
                    const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ),
          Container(
            color: panelBg,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filter presets — small pill chips.
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: PhotoFilter.values.map((f) {
                      final selected = f == _filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _FilterChip(
                          label: f.label,
                          selected: selected,
                          onTap: () {
                            setState(() => _filter = f);
                            _regenerate();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _slider(
                  'Độ sáng',
                  _brightness,
                  0.5,
                  1.5,
                  (v) => _brightness = v,
                ),
                _slider(
                  'Tương phản',
                  _contrast,
                  0.5,
                  1.5,
                  (v) => _contrast = v,
                ),
                _slider(
                  'Màu sắc',
                  _saturation,
                  0.0,
                  2.0,
                  (v) => _saturation = v,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Cắt / Xoay',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.crop,
                  height: 48,
                  onPressed: _crop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChange,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: AppType.body,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.16),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (v) => setState(() => onChange(v)),
              onChangeEnd: (_) => _regenerate(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pill filter chip with press feedback (used on the dark editor panel).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: AppType.body,
            fontWeight: selected ? AppType.bold : AppType.medium,
          ),
        ),
      ),
    );
  }
}
