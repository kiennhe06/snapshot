import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Chỉnh sửa'),
        actions: [
          TextButton(
            onPressed: _processing ? null : _done,
            child: const Text('Xong', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.file(shown, fit: BoxFit.contain),
                if (_processing)
                  const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
          Container(
            color: Colors.grey.shade900,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filter presets.
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: PhotoFilter.values.map((f) {
                      final selected = f == _filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.label),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _filter = f);
                            _regenerate();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _crop,
                        icon: const Icon(Icons.crop, color: Colors.white),
                        label: const Text(
                          'Cắt / Xoay',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
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
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChange(v)),
            onChangeEnd: (_) => _regenerate(),
          ),
        ),
      ],
    );
  }
}
