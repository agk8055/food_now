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

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;
  bool _canPop = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final db = FirebaseFirestore.instance;

      // 1. Add review doc
      await db.collection('reviews').add({
        'orderId': widget.orderId,
        'shopId': widget.shopId,
        'buyerId': widget.buyerId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update order to reviewed: true
      await db.collection('orders').doc(widget.orderId).update({
        'reviewed': true,
      });

      // 3. Update shop rating average and count
      final shopRef = db.collection('shops').doc(widget.shopId);

      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(shopRef);
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data != null) {
          // Use 'rating' instead of 'ratingAverage'
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
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
      }
    }
  }

  Future<void> _skipReview() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = FirebaseFirestore.instance;

      // Update order to reviewed: true
      await db.collection('orders').doc(widget.orderId).update({
        'reviewed': true,
      });

      if (mounted) {
        setState(() => _canPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to skip: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handling keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: _canPop,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: bottomInset > 0 ? bottomInset + 24 : 32,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF00bf63),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              "How was your food?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Rate your experience with\n${widget.shopName}",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: index < _rating ? Colors.amber : Colors.grey[300],
                      size: 40,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Comment Field
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: "Add a comment (optional)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00bf63)),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
              minLines: 1,
            ),

            const SizedBox(height: 24),

            // Buttons
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00bf63)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _rating > 0 ? _submitReview : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00bf63),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: const Text(
                          "Submit Review",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _skipReview,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          "Skip",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
