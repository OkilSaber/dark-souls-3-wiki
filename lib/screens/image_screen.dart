import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../motion.dart';
import '../theme.dart';

class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key, required this.assetPath, this.caption});

  final String assetPath;
  final String? caption;

  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen>
    with SingleTickerProviderStateMixin {
  final _view = TransformationController();
  late final AnimationController _return = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() => _dy = _return.value));

  double _dy = 0;
  bool _dragging = false;

  static const _travel = 260.0;

  bool get _zoomed => _view.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _return.dispose();
    _view.dispose();
    super.dispose();
  }

  void _start(DragStartDetails _) {
    if (_zoomed) return;
    _return.stop();
    _dragging = true;
  }

  void _update(DragUpdateDetails d) {
    if (!_dragging) return;
    setState(() => _dy += d.delta.dy);
  }

  void _end(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final v = d.velocity.pixelsPerSecond.dy;

    final projected = _dy + _project(v);
    if (projected.abs() > _travel * 0.55) {
      Navigator.of(context).maybePop();
      return;
    }

    _return.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 500, damping: 34),
      _dy,
      0,
      v,
    ));
  }

  static double _project(double velocity, {double deceleration = 0.998}) =>
      (velocity / 1000) * deceleration / (1 - deceleration);

  @override
  Widget build(BuildContext context) {
    final progress = (_dy.abs() / _travel).clamp(0.0, 1.0);
    final caption = widget.caption?.trim() ?? '';
    final reduced = Motion.reduced(context);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1 - progress * 0.82),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Opacity(
          opacity: 1 - progress,
          child: Text(
            caption.isNotEmpty ? caption : 'Image',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: GestureDetector(
        onVerticalDragStart: reduced ? null : _start,
        onVerticalDragUpdate: reduced ? null : _update,
        onVerticalDragEnd: reduced ? null : _end,
        child: Center(
          child: Transform.translate(
            offset: Offset(0, _dy),
            child: Transform.scale(
              scale: 1 - progress * 0.08,
              child: InteractiveViewer(
                transformationController: _view,
                minScale: 1,
                maxScale: 6,
                onInteractionEnd: (_) => setState(() {}),
                child: Image.asset(
                  widget.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text(
                    'Image unavailable',
                    style: TextStyle(color: AppTheme.textDim),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: caption.isEmpty
          ? null
          : Opacity(
              opacity: 1 - progress,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
                color: Colors.black.withValues(alpha: 0.45),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12.5, height: 1.4),
                ),
              ),
            ),
    );
  }
}
