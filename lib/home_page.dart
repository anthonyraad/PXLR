import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'mosaic_engine.dart';
import 'mosaic_painter.dart';
import 'outlined_title.dart';
import 'theme.dart';

/// Background used to pad the mosaic sample when zooming out beyond the
/// image's native bounds — a neutral tone that fits the dark theme.
const _padColor = Color(0xFF211F3F);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _sourceBytes;
  ui.Image? _sourceImage;
  List<List<Color>>? _cellColors;

  double _zoom = 1.0; // 0.5 - 2.0, matches the 50%-200% web slider
  bool _showLines = true;
  bool _showSource = false;
  bool _flipHorizontal = false;
  bool _isProcessing = false;
  String? _readout;

  /// When set, the mosaic view shows only this 9×9 ninth (col/row in 0..2).
  (int col, int row)? _expandedNinth;

  static const _ninthNames = [
    ['top-left', 'top-middle', 'top-right'],
    ['center-left', 'center', 'center-right'],
    ['bottom-left', 'bottom-middle', 'bottom-right'],
  ];

  String _ninthName((int col, int row) ninth) => _ninthNames[ninth.$2][ninth.$1];

  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    setState(() {
      _sourceBytes = bytes;
      _sourceImage = frame.image;
      _readout = null;
      _expandedNinth = null;
      _showSource = false;
      _flipHorizontal = false;
    });
    await _process();
  }

  Future<void> _process() async {
    final image = _sourceImage;
    if (image == null) return;
    setState(() => _isProcessing = true);
    final colors = await MosaicEngine.computeCellColors(
      image: image,
      zoom: _zoom,
      padColor: _padColor,
    );
    if (!mounted) return;
    setState(() {
      _cellColors = colors;
      _isProcessing = false;
      _expandedNinth = null;
    });
  }

  void _nudgeZoom(double delta) {
    final next = (((_zoom + delta) * 100).round() / 100).clamp(0.5, 2.0);
    if (next == _zoom) return;
    setState(() => _zoom = next);
    _process();
  }

  /// Cell colors currently shown in the mosaic panel (full 27×27 or one ninth).
  List<List<Color>>? get _displayColors {
    final colors = _cellColors;
    if (colors == null) return null;
    final ninth = _expandedNinth;
    late final List<List<Color>> view;
    if (ninth == null) {
      view = colors;
    } else {
      const s = MosaicEngine.ninthSize;
      final ox = ninth.$1 * s;
      final oy = ninth.$2 * s;
      view = List.generate(s, (y) => List.generate(s, (x) => colors[oy + y][ox + x]));
    }
    return _flipHorizontal ? _flipRows(view) : view;
  }

  List<List<Color>> _flipRows(List<List<Color>> colors) =>
      [for (final row in colors) row.reversed.toList()];

  (int gx, int gy) _cellAt(Offset localPosition, double canvasSize) {
    final display = _displayColors!;
    final n = display.length;
    var lx = (localPosition.dx / canvasSize * n).floor().clamp(0, n - 1);
    final ly = (localPosition.dy / canvasSize * n).floor().clamp(0, n - 1);
    // Display may be mirrored; map visual x back into unflipped cell space.
    if (_flipHorizontal) lx = n - 1 - lx;
    final ninth = _expandedNinth;
    if (ninth == null) return (lx, ly);
    const s = MosaicEngine.ninthSize;
    return (ninth.$1 * s + lx, ninth.$2 * s + ly);
  }

  void _toggleFlipHorizontal() {
    setState(() => _flipHorizontal = !_flipHorizontal);
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    final vy = details.velocity.pixelsPerSecond.dy;
    // Quick left/right flick — ignore mostly-vertical pans used for inspect.
    if (vx.abs() < 450) return;
    if (vy.abs() > vx.abs() * 0.75) return;
    _toggleFlipHorizontal();
  }

  void _onCanvasInspect(Offset localPosition, double canvasSize) {
    final colors = _cellColors;
    if (colors == null) return;
    final (gx, gy) = _cellAt(localPosition, canvasSize);
    final c = colors[gy][gx];
    final hex = '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
    final ninth = _expandedNinth;
    final zoomHint = ninth == null ? '' : ' · ${_ninthName(ninth)}';
    setState(() => _readout = 'cell (${gx + 1}, ${gy + 1})$zoomHint — $hex');
  }

  void _onMosaicTap(Offset localPosition, double canvasSize) {
    final colors = _cellColors;
    if (colors == null) return;

    // Resolve the cell under the finger in the *current* view, then toggle.
    final (gx, gy) = _cellAt(localPosition, canvasSize);
    final c = colors[gy][gx];
    final hex = '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

    if (_expandedNinth != null) {
      setState(() {
        _expandedNinth = null;
        _readout = 'cell (${gx + 1}, ${gy + 1}) — $hex';
      });
      return;
    }

    final ninth = (gx ~/ MosaicEngine.ninthSize, gy ~/ MosaicEngine.ninthSize);
    setState(() {
      _expandedNinth = ninth;
      _readout = 'cell (${gx + 1}, ${gy + 1}) · ${_ninthName(ninth)} — $hex';
    });
  }

  Future<void> _exportAndShare() async {
    final colors = _cellColors;
    if (colors == null) return;
    final exportColors = _flipHorizontal ? _flipRows(colors) : colors;
    final bytes = await MosaicEngine.renderToPng(cellColors: exportColors, showLines: _showLines);
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'pxlr-mosaic.png', mimeType: 'image/png')],
      text: 'My 27×27 PXLR mosaic',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _sourceImage != null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: PxlrColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
            child: Center(
              child: Column(
                children: [
                  const OutlinedTitle('PXLR'),
                  const SizedBox(height: 10),
                  _Subtitle(),
                  const SizedBox(height: 32),
                  if (!hasImage) _Dropzone(onTap: _pickImage) else _buildStage(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    const canvasSize = 300.0;
    final mosaicLabel = _expandedNinth == null
        ? 'MOSAIC'
        : 'MOSAIC · ${_ninthName(_expandedNinth!).toUpperCase()}';

    return Column(
      children: [
        _FramedPanel(
          label: _showSource ? 'SOURCE' : mosaicLabel,
          borderColor: _showSource ? PxlrColors.line : PxlrColors.pink,
          glow: !_showSource,
          size: canvasSize,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final scale = Tween<double>(begin: 0.94, end: 1).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: _showSource
                ? (_sourceBytes == null
                    ? const SizedBox.shrink(key: ValueKey('source-empty'))
                    : GestureDetector(
                        key: ValueKey('source-$_flipHorizontal'),
                        onPanEnd: _onHorizontalSwipe,
                        child: Transform.flip(
                          flipX: _flipHorizontal,
                          child: Image.memory(
                            _sourceBytes!,
                            fit: BoxFit.contain,
                            width: canvasSize,
                            height: canvasSize,
                          ),
                        ),
                      ))
                : (_displayColors == null
                    ? const Center(
                        key: ValueKey('loading'),
                        child: CircularProgressIndicator(color: PxlrColors.pink),
                      )
                    : GestureDetector(
                        key: ValueKey('mosaic-$_expandedNinth-$_flipHorizontal'),
                        onPanUpdate: (d) => _onCanvasInspect(d.localPosition, canvasSize),
                        onPanEnd: _onHorizontalSwipe,
                        onTapDown: (d) => _onMosaicTap(d.localPosition, canvasSize),
                        child: CustomPaint(
                          size: const Size(canvasSize, canvasSize),
                          painter: MosaicPainter(
                            cellColors: _displayColors!,
                            showLines: _showLines,
                            // Full mosaic: bold every 9. Expanded ninth: bold
                            // every 3 so the 9×9 itself reads as a 3×3 of ninths.
                            boldEvery: _expandedNinth == null
                                ? MosaicEngine.ninthSize
                                : MosaicEngine.subNinthSize,
                          ),
                        ),
                      )),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 16,
          child: Text(_showSource ? '' : (_readout ?? ''), style: PxlrText.mono()),
        ),
        const SizedBox(height: 18),
        _ControlsPanel(
          showSource: _showSource,
          showLines: _showLines,
          zoom: _zoom,
          isProcessing: _isProcessing,
          dominantColors: _displayColors == null
              ? const []
              : MosaicEngine.dominantColors(_displayColors!),
          onShowSourceChanged: (v) => setState(() => _showSource = v),
          onShowLinesChanged: (v) => setState(() => _showLines = v),
          onZoomOut: () => _nudgeZoom(-0.05),
          onZoomIn: () => _nudgeZoom(0.05),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _PxlrButton(
              label: 'Change Image',
              color: PxlrColors.cyan,
              onTap: _pickImage,
            ),
            _PxlrButton(
              label: 'Share',
              color: PxlrColors.pink,
              filled: true,
              onTap: _cellColors == null ? null : _exportAndShare,
            ),
          ],
        ),
      ],
    );
  }
}

class _Subtitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: PxlrText.body(),
        children: [
          const TextSpan(text: 'Convert an image to a '),
          TextSpan(
            text: '27×27',
            style: PxlrText.body(color: PxlrColors.cyan).copyWith(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' pixel mosaic'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _Dropzone extends StatelessWidget {
  const _Dropzone({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: PxlrColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PxlrColors.line, width: 2),
        ),
        child: Text.rich(
          TextSpan(
            style: PxlrText.body(),
            children: [
              TextSpan(
                text: 'Choose Image',
                style: PxlrText.body(color: PxlrColors.text).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FramedPanel extends StatelessWidget {
  const _FramedPanel({
    required this.label,
    required this.borderColor,
    required this.size,
    required this.child,
    this.glow = false,
  });

  final String label;
  final Color borderColor;
  final double size;
  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: PxlrText.label()),
        const SizedBox(height: 10),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: PxlrColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              const BoxShadow(color: Colors.black45, offset: Offset(0, 8)),
              if (glow) BoxShadow(color: borderColor.withOpacity(0.35), blurRadius: 24),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.showSource,
    required this.showLines,
    required this.zoom,
    required this.isProcessing,
    required this.dominantColors,
    required this.onShowSourceChanged,
    required this.onShowLinesChanged,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  final bool showSource;
  final bool showLines;
  final double zoom;
  final bool isProcessing;
  final List<Color> dominantColors;
  final ValueChanged<bool> onShowSourceChanged;
  final ValueChanged<bool> onShowLinesChanged;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    final canZoomOut = zoom > 0.5;
    final canZoomIn = zoom < 2.0;

    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: PxlrColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PxlrColors.line, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Source', style: PxlrText.body()),
              const Spacer(),
              Switch(
                value: showSource,
                activeThumbColor: PxlrColors.cyan,
                onChanged: onShowSourceChanged,
              ),
            ],
          ),
          Row(
            children: [
              Text('Grid lines', style: PxlrText.body()),
              const Spacer(),
              Switch(
                value: showLines,
                activeThumbColor: PxlrColors.pink,
                onChanged: onShowLinesChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Zoom', style: PxlrText.body()),
              const Spacer(),
              if (isProcessing) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: PxlrColors.cyan),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${(zoom * 100).round()}%',
                style: PxlrText.mono(color: PxlrColors.gold, weight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              _ZoomButton(
                label: '−',
                enabled: canZoomOut && !isProcessing,
                onTap: onZoomOut,
              ),
              const SizedBox(width: 8),
              _ZoomButton(
                label: '+',
                enabled: canZoomIn && !isProcessing,
                onTap: onZoomIn,
              ),
            ],
          ),
          if (dominantColors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < dominantColors.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: dominantColors[i],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: PxlrColors.line, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PxlrColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PxlrColors.pink, width: 2),
          ),
          child: Text(
            label,
            style: PxlrText.label(size: 18, color: PxlrColors.pink),
          ),
        ),
      ),
    );
  }
}

class _PxlrButton extends StatelessWidget {
  const _PxlrButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: filled ? color : PxlrColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.4), offset: const Offset(0, 4)),
            ],
          ),
          child: Text(
            label,
            style: PxlrText.label(size: 13, color: filled ? const Color(0xFF1A0A12) : color),
          ),
        ),
      ),
    );
  }
}
