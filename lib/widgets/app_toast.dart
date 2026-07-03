import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart' show rootNavigatorKey;

/// Show a toast at the bottom of the screen with optional Undo action.
///
/// Uses an [OverlayEntry] inserted into the root [Navigator]'s overlay
/// rather than `ScaffoldMessenger.showSnackBar`, because ScaffoldMessenger
/// snackbars don't reliably auto-dismiss in this app's nested-Scaffold +
/// FAB layout (the snackbar's animation status never reaches `completed`,
/// so its internal timer never arms). Owning the timer + animation here
/// makes the lifecycle self-contained and predictable.
void showAppToast(
  String message, {
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  final overlay = navigator.overlay;
  if (overlay == null) return;

  // Dismiss any toast currently showing so we don't stack.
  _AppToastController.instance.dismissCurrent();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AppToast(
      message: message,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      onClosed: () {
        if (entry.mounted) entry.remove();
        _AppToastController.instance.clear(entry);
      },
    ),
  );

  _AppToastController.instance.register(entry);
  overlay.insert(entry);
}

/// Tracks the currently-visible toast so `showAppToast` can replace it.
class _AppToastController {
  _AppToastController._();
  static final _AppToastController instance = _AppToastController._();

  OverlayEntry? _current;
  final ValueNotifier<int> _dismissTrigger = ValueNotifier(0);
  ValueNotifier<int> get dismissTrigger => _dismissTrigger;

  // ignore: use_setters_to_change_properties — registration, not a property
  void register(OverlayEntry entry) {
    _current = entry;
  }

  void dismissCurrent() {
    if (_current != null) {
      _dismissTrigger.value++;
    }
  }

  void clear(OverlayEntry entry) {
    if (identical(_current, entry)) {
      _current = null;
    }
  }
}

class _AppToast extends StatefulWidget {
  const _AppToast({
    required this.message,
    required this.duration,
    required this.onClosed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Duration duration;
  final VoidCallback onClosed;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _autoDismissTimer;
  bool _isClosing = false;
  int _lastDismissTick = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _autoDismissTimer = Timer(widget.duration, _close);
    _lastDismissTick = _AppToastController.instance.dismissTrigger.value;
    _AppToastController.instance.dismissTrigger.addListener(_onDismissSignal);
  }

  void _onDismissSignal() {
    final tick = _AppToastController.instance.dismissTrigger.value;
    if (tick != _lastDismissTick) {
      _lastDismissTick = tick;
      _close();
    }
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    _autoDismissTimer?.cancel();
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onClosed();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _AppToastController.instance.dismissTrigger.removeListener(_onDismissSignal);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    // Sit above the bottom-nav (NavigationBar height ~70 + safe area).
    final bottom = mediaQuery.padding.bottom + 88;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Opacity(
              opacity: _animation.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _animation.value) * 12),
                child: child,
              ),
            );
          },
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.inverseSurface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                widget.actionLabel != null ? 8 : 16,
                14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        widget.onAction?.call();
                        _close();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.inversePrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(
                        widget.actionLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
