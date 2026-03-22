import 'package:flutter/material.dart';
import '../animations/animation_config.dart';

/// Reusable wrapper widget for animated bottom sheets with consistent styling and animations.
/// Slides from bottom and fades in automatically.
class AnimatedBottomSheet extends StatefulWidget {
  final Widget child;
  final String? title;
  final VoidCallback? onClose;
  final double maxHeight;
  final bool isDismissible;
  final bool enableDrag;
  final Color backgroundColor;
  final EdgeInsets padding;

  const AnimatedBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.onClose,
    this.maxHeight = 0.9,
    this.isDismissible = true,
    this.enableDrag = true,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  State<AnimatedBottomSheet> createState() => _AnimatedBottomSheetState();
}

class _AnimatedBottomSheetState extends State<AnimatedBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: AnimationConfig.kDefaultDuration,
      vsync: this,
    );

    // Slide animation: from bottom (0.0) to top (1.0)
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AnimationConfig.kEntryCurve,
          ),
        );

    // Fade animation: from transparent (0.0) to opaque (1.0)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AnimationConfig.kEntryCurve,
      ),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismissModal() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isDismissible ? _dismissModal : null,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) =>
            Opacity(opacity: _fadeAnimation.value, child: child),
        child: SlideTransition(
          position: _slideAnimation,
          child: GestureDetector(
            onTap: () {}, // Prevent tap propagation to dismiss gesture
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
              ),
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * widget.maxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Container(
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),

                  // Title (if provided)
                  if (widget.title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.title!,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (widget.isDismissible)
                            IconButton(
                              onPressed: _dismissModal,
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: widget.padding,
                        child: widget.child,
                      ),
                    ),
                  ),

                  // Bottom padding for safe area
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension method on BuildContext for easy modal invocation
Future<T?> showAnimatedBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  String? title,
  VoidCallback? onClose,
  double maxHeight = 0.9,
  bool isDismissible = true,
  bool enableDrag = true,
  Color backgroundColor = Colors.white,
  EdgeInsets padding = const EdgeInsets.all(16.0),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => AnimatedBottomSheet(
      title: title,
      onClose: onClose,
      maxHeight: maxHeight,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      padding: padding,
      child: child,
    ),
  );
}
