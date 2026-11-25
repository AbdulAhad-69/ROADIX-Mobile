import 'package:flutter/material.dart';

/// Tactile press-scale wrapper (`0.97` over `120ms`, ease-out cubic) that
/// respects platform reduced-motion preferences.
class RoadixPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final BorderRadius? borderRadius;

  const RoadixPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.borderRadius,
  });

  @override
  State<RoadixPressable> createState() => _RoadixPressableState();
}

class _RoadixPressableState extends State<RoadixPressable> {
  static const Curve _easeOutQuintish = Cubic(0.23, 1, 0.32, 1);
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    if (mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onTap != null;
    final targetScale = (_pressed && enabled && !disableAnimations)
        ? widget.pressedScale
        : 1.0;

    return Listener(
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: targetScale,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: _easeOutQuintish,
        child: widget.onTap == null
            ? widget.child
            : Material(
                color: Colors.transparent,
                borderRadius: widget.borderRadius,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: widget.borderRadius,
                  child: widget.child,
                ),
              ),
      ),
    );
  }
}
