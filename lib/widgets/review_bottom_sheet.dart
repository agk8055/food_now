import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReviewBottomSheet extends StatefulWidget {
  final String orderId;
  final String shopId;
  final String shopName;
  final String buyerId;

  const ReviewBottomSheet({
    super.key,
    required this.orderId,
    required this.shopId,
    required this.shopName,
    required this.buyerId,
  });

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();

  static void show(
    BuildContext context, {
    required String orderId,
    required String shopId,
    required String shopName,
    required String buyerId,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewBottomSheet(
        orderId: orderId,
        shopId: shopId,
        shopName: shopName,
        buyerId: buyerId,
      ),
    );
  }
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet>
    with TickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;
  bool _canPop = false;

  // Animation controllers
  late AnimationController _sheetEntryController;
  late AnimationController _iconPulseController;
  late AnimationController _starBounceController;
  late AnimationController _buttonShimmerController;

  late Animation<double> _sheetSlide;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _starsFade;
  late Animation<Offset> _starsSlide;
  late Animation<double> _fieldFade;
  late Animation<Offset> _fieldSlide;
  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;
  late Animation<double> _iconPulse;
  late Animation<double> _shimmer;

  // Per-star bounce animations
  late List<AnimationController> _starControllers;
  late List<Animation<double>> _starScales;

  @override
  void initState() {
    super.initState();

    // Sheet entry
    _sheetEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sheetSlide = CurvedAnimation(
      parent: _sheetEntryController,
      curve: Curves.easeOutCubic,
    );

    // Icon entrance
    _iconFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _iconScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Title
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    // Stars
    _starsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
      ),
    );
    _starsSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
      ),
    );

    // Comment field
    _fieldFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );
    _fieldSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );

    // Buttons
    _buttonsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sheetEntryController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    // Icon idle pulse
    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _iconPulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _iconPulseController, curve: Curves.easeInOut),
    );

    // Per-star bounce controllers
    _starControllers = List.generate(
      5,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _starScales = _starControllers
        .map(
          (c) => TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 1.5),
              weight: 40,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 1.5, end: 0.9),
              weight: 30,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.9, end: 1.0),
              weight: 30,
            ),
          ]).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();

    // Button shimmer
    _buttonShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _buttonShimmerController, curve: Curves.easeInOut),
    );

    _sheetEntryController.forward();
  }

  @override
  void dispose() {
    _sheetEntryController.dispose();
    _iconPulseController.dispose();
    _buttonShimmerController.dispose();
    for (final c in _starControllers) {
      c.dispose();
    }
    _commentController.dispose();
    super.dispose();
  }

  void _onStarTap(int index) {
    setState(() => _rating = index + 1);
    // Bounce all stars up to and including tapped
    for (int i = 0; i <= index; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (mounted) {
          _starControllers[i].forward(from: 0);
        }
      });
    }
  }

  // ─── Label for rating ───────────────────────────────────────────────────────
  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return 'Terrible 😞';
      case 2:
        return 'Poor 😕';
      case 3:
        return 'Okay 😐';
      case 4:
        return 'Good 😊';
      case 5:
        return 'Excellent! 🤩';
      default:
        return 'Tap to rate';
    }
  }

  // ─── Business logic (unchanged) ─────────────────────────────────────────────

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;

      await db.collection('reviews').add({
        'orderId': widget.orderId,
        'shopId': widget.shopId,
        'buyerId': widget.buyerId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await db.collection('orders').doc(widget.orderId).update({
        'reviewed': true,
      });

      final shopRef = db.collection('shops').doc(widget.shopId);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(shopRef);
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data != null) {
          double oldAverage = (data['rating'] ?? 0.0).toDouble();
          int oldCount = data['ratingCount'] ?? 0;
          double newAverage =
              ((oldAverage * oldCount) + _rating) / (oldCount + 1);
          transaction.update(shopRef, {
            'rating': newAverage,
            'ratingCount': oldCount + 1,
          });
        }
      });

      if (mounted) {
        setState(() => _canPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thank you for your review!')),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    }
  }

  Future<void> _skipReview() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'reviewed': true});

      if (mounted) {
        setState(() => _canPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to skip: $e')),
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: _canPop,
      child: AnimatedBuilder(
        animation: _sheetSlide,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(0, 1 - _sheetSlide.value),
          child: child,
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 8,
            bottom: bottomInset > 0 ? bottomInset + 24 : 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 40,
                spreadRadius: 0,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Animated icon ────────────────────────────────────────────
              FadeTransition(
                opacity: _iconFade,
                child: ScaleTransition(
                  scale: _iconScale,
                  child: AnimatedBuilder(
                    animation: _iconPulse,
                    builder: (context, child) => Transform.scale(
                      scale: _iconPulse.value,
                      child: child,
                    ),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00bf63), Color(0xFF00e676)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00bf63).withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Title & subtitle ─────────────────────────────────────────
              FadeTransition(
                opacity: _titleFade,
                child: SlideTransition(
                  position: _titleSlide,
                  child: Column(
                    children: [
                      const Text(
                        'How was your food?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'Share your experience with '),
                            TextSpan(
                              text: widget.shopName,
                              style: const TextStyle(
                                color: Color(0xFF00bf63),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Star rating ──────────────────────────────────────────────
              FadeTransition(
                opacity: _starsFade,
                child: SlideTransition(
                  position: _starsSlide,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final filled = index < _rating;
                          return GestureDetector(
                            onTap: () => _onStarTap(index),
                            child: AnimatedBuilder(
                              animation: _starScales[index],
                              builder: (context, child) => Transform.scale(
                                scale: _starScales[index].value,
                                child: child,
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                    scale: anim,
                                    child: child,
                                  ),
                                  child: Icon(
                                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                    key: ValueKey('$index-$filled'),
                                    color: filled
                                        ? const Color(0xFFFFC107)
                                        : const Color(0xFFDDDDDD),
                                    size: 44,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 10),

                      // Rating label
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _ratingLabel,
                          key: ValueKey(_ratingLabel),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _rating > 0
                                ? const Color(0xFF00bf63)
                                : Colors.grey[400],
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Comment field ────────────────────────────────────────────
              FadeTransition(
                opacity: _fieldFade,
                child: SlideTransition(
                  position: _fieldSlide,
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment (optional)',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFF0F0F0),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF00bf63),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Buttons ──────────────────────────────────────────────────
              FadeTransition(
                opacity: _buttonsFade,
                child: SlideTransition(
                  position: _buttonsSlide,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: _LoadingDots(),
                          )
                        : _ActionsSection(
                            rating: _rating,
                            shimmer: _shimmer,
                            onSubmit: _submitReview,
                            onSkip: _skipReview,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Loading dots indicator ──────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _anims = _controllers
        .map(
          (c) => Tween<double>(begin: 0, end: -10).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut),
          ),
        )
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (context, _) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00bf63),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00bf63).withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Actions section ─────────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  final int rating;
  final Animation<double> shimmer;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  const _ActionsSection({
    required this.rating,
    required this.shimmer,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Submit button with shimmer
        _SubmitButton(
          enabled: rating > 0,
          shimmer: shimmer,
          onTap: onSubmit,
        ),

        const SizedBox(height: 10),

        // Skip
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            overlayColor: Colors.grey.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Maybe later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Submit button with shimmer ──────────────────────────────────────────────

class _SubmitButton extends StatefulWidget {
  final bool enabled;
  final Animation<double> shimmer;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.enabled,
    required this.shimmer,
    required this.onTap,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pressScale, widget.shimmer]),
      builder: (context, _) {
        return Transform.scale(
          scale: _pressScale.value,
          child: GestureDetector(
            onTapDown: widget.enabled
                ? (_) => _pressController.forward()
                : null,
            onTapUp: widget.enabled
                ? (_) {
                    _pressController.reverse();
                    widget.onTap();
                  }
                : null,
            onTapCancel: widget.enabled
                ? () => _pressController.reverse()
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: widget.enabled
                    ? const LinearGradient(
                        colors: [Color(0xFF00bf63), Color(0xFF00d96e)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: widget.enabled ? null : const Color(0xFFEEEEEE),
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00bf63).withOpacity(0.40),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shimmer sweep (only when enabled)
                    if (widget.enabled)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: widget.shimmer,
                          builder: (context, _) => CustomPaint(
                            painter: _ShimmerPainter(widget.shimmer.value),
                          ),
                        ),
                      ),
                    // Label
                    Text(
                      'Submit Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.enabled
                            ? Colors.white
                            : Colors.grey[400],
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Shimmer painter ─────────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  final double progress;
  _ShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final x = progress * size.width;
    final gradient = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.18),
        Colors.white.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final rect = Rect.fromLTWH(x - size.width * 0.4, 0, size.width * 0.8, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}