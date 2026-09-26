import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import 'tr.dart';

/// Crop (drag and pinch), rotate, filters and adjustments for the CV photo.
/// What you see inside the square is exactly what is saved: the square is
/// rendered to an image (400x400 JPEG). Pops with the JPEG bytes, or null.
class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  static const double _side = 300;
  static const int _outputPx = 400;

  final _boundaryKey = GlobalKey();
  final _tc = TransformationController();

  Size? _imgSize;
  int _turns = 0;
  int _filter = 0;
  double _brightness = 0; // -1..1
  double _contrast = 1; // 0.6..1.6
  double _saturation = 1; // 0..2
  bool _saving = false;

  static const _filterKeys = [
    'f_original',
    'f_bw',
    'f_sepia',
    'f_warm',
    'f_cool',
    'f_vivid',
    'f_fade',
  ];

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _loadSize() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    if (!mounted) return;
    setState(() {
      _imgSize = size;
      _fit();
    });
  }

  /// Scales and centers the picture so it fills the square.
  void _fit() {
    final size = _imgSize;
    if (size == null) return;
    final w = _turns.isOdd ? size.height : size.width;
    final h = _turns.isOdd ? size.width : size.height;
    final s = w >= h ? w / h : h / w;
    final o = (_side * s - _side) / 2;
    // Scale by s, then shift so the enlarged picture stays centered.
    _tc.value = Matrix4.diagonal3Values(s, s, 1.0)..setTranslationRaw(-o, -o, 0.0);
  }

  void _reset() {
    setState(() {
      _turns = 0;
      _filter = 0;
      _brightness = 0;
      _contrast = 1;
      _saturation = 1;
      _fit();
    });
  }

  void _rotate() {
    setState(() {
      _turns = (_turns + 1) % 4;
      _fit();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _outputPx / _side);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final h = image.height;
      image.dispose();
      if (data == null) throw StateError('no image data');

      final decoded = img.Image.fromBytes(
        width: w,
        height: h,
        bytes: data.buffer,
        numChannels: 4,
      );
      final jpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
      if (mounted) Navigator.of(context).pop(jpg);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------ color maths
  // 4x5 color matrices (Flutter ColorFilter.matrix), offsets in 0..255.

  static const _identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Applies [b] first, then [a].
  static List<double> _mul(List<double> a, List<double> b) {
    final r = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var s = 0.0;
        for (var k = 0; k < 4; k++) {
          s += a[i * 5 + k] * b[k * 5 + j];
        }
        if (j == 4) s += a[i * 5 + 4];
        r[i * 5 + j] = s;
      }
    }
    return r;
  }

  static List<double> _sat(double s) => [
        0.2126 + 0.7874 * s, 0.7152 - 0.7152 * s, 0.0722 - 0.0722 * s, 0, 0,
        0.2126 - 0.2126 * s, 0.7152 + 0.2848 * s, 0.0722 - 0.0722 * s, 0, 0,
        0.2126 - 0.2126 * s, 0.7152 - 0.7152 * s, 0.0722 + 0.9278 * s, 0, 0,
        0, 0, 0, 1, 0,
      ];

  static List<double> _con(double c) {
    final o = 128 * (1 - c);
    return [
      c, 0, 0, 0, o, //
      0, c, 0, 0, o,
      0, 0, c, 0, o,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> _bri(double b) {
    final o = b * 100;
    return [
      1, 0, 0, 0, o, //
      0, 1, 0, 0, o,
      0, 0, 1, 0, o,
      0, 0, 0, 1, 0,
    ];
  }

  static const _sepia = <double>[
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const _warm = <double>[
    1.1, 0, 0, 0, 10, //
    0, 1.0, 0, 0, 0,
    0, 0, 0.9, 0, -10,
    0, 0, 0, 1, 0,
  ];

  static const _cool = <double>[
    0.9, 0, 0, 0, -10, //
    0, 1.0, 0, 0, 0,
    0, 0, 1.1, 0, 10,
    0, 0, 0, 1, 0,
  ];

  List<double> _preset() {
    switch (_filter) {
      case 1:
        return _mul(_con(1.25), _sat(0));
      case 2:
        return _sepia;
      case 3:
        return _warm;
      case 4:
        return _cool;
      case 5:
        return _mul(_con(1.1), _sat(1.4));
      case 6:
        return _mul(_bri(0.12), _con(0.85));
      default:
        return _identity;
    }
  }

  List<double> _matrix() {
    var m = _preset();
    m = _mul(_sat(_saturation), m);
    m = _mul(_con(_contrast), m);
    m = _mul(_bri(_brightness), m);
    return m;
  }

  // --------------------------------------------------------------------- ui

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final picture = RotatedBox(
      quarterTurns: _turns,
      child: Image.memory(
        widget.bytes,
        width: _side,
        height: _side,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );

    final viewer = RepaintBoundary(
      key: _boundaryKey,
      child: SizedBox(
        width: _side,
        height: _side,
        child: ColoredBox(
          color: Colors.white,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_matrix()),
            child: InteractiveViewer(
              transformationController: _tc,
              minScale: 0.5,
              maxScale: 8,
              boundaryMargin: const EdgeInsets.all(_side),
              child: picture,
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('editPhoto')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('apply')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                viewer,
                const Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: _CircleMask())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('cropHint'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _rotate,
                icon: const Icon(Icons.rotate_right),
                label: Text(context.tr('rotate')),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: _reset, child: Text(context.tr('reset'))),
            ],
          ),
          const SizedBox(height: 12),
          Text(context.tr('filters'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _filterKeys.length; i++)
                ChoiceChip(
                  label: Text(context.tr(_filterKeys[i])),
                  selected: _filter == i,
                  onSelected: (_) => setState(() => _filter = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _slider(context.tr('brightness'), _brightness, -1, 1,
              (v) => _brightness = v),
          _slider(context.tr('contrast'), _contrast, 0.6, 1.6,
              (v) => _contrast = v),
          _slider(context.tr('saturation'), _saturation, 0, 2,
              (v) => _saturation = v),
        ],
      ),
    );
  }
}

/// Dims everything outside the circle that will show on the CV.
class _CircleMask extends CustomPainter {
  const _CircleMask();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Rect.fromCircle(
      center: rect.center,
      radius: size.shortestSide / 2 - 2,
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(circle);
    canvas.drawPath(path, Paint()..color = const Color(0x99000000));
    canvas.drawOval(
      circle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
