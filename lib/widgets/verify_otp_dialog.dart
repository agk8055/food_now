import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyOTPDialog extends StatefulWidget {
  final String orderId;
  final String correctOtp;
  final String buyerName;
  final Color primaryGreen;

  const VerifyOTPDialog({
    super.key,
    required this.orderId,
    required this.correctOtp,
    required this.buyerName,
    required this.primaryGreen,
  });

  @override
  State<VerifyOTPDialog> createState() => _VerifyOTPDialogState();
}

class _VerifyOTPDialogState extends State<VerifyOTPDialog> {
  final TextEditingController otpController = TextEditingController();
  bool isError = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header Icon ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: widget.primaryGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            // --- Title & Subtitle ---
            const Text(
              "Verify Pickup",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the 4-digit code from ${widget.buyerName}'s app to complete this order.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // --- Animated OTP Input ---
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: isError ? Colors.red.withOpacity(0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isError 
                      ? Colors.redAccent 
                      : widget.primaryGreen.withOpacity(0.3),
                  width: isError ? 2 : 1.5,
                ),
                boxShadow: isError
                    ? [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : [
                        BoxShadow(
                          color: widget.primaryGreen.withOpacity(0.05),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ],
              ),
              child: TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  letterSpacing: 24, // Keeps the digits spaced nicely
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: "0000",
                  hintStyle: TextStyle(
                    color: Colors.grey[300],
                    letterSpacing: 24,
                  ),
                  counterText: "",
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onChanged: (val) {
                  if (isError) {
                    setState(() => isError = false);
                  }
                },
              ),
            ),

            // --- Smooth Error Message ---
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isError ? 1.0 : 0.0,
                child: isError
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Incorrect OTP. Please try again.",
                              style: TextStyle(
                                color: Colors.redAccent[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 32),

            // --- Action Buttons ---
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (otpController.text == widget.correctOtp) {
                        // Original Business Logic
                        FirebaseFirestore.instance
                            .collection('orders')
                            .doc(widget.orderId)
                            .update({
                              'status': 'completed',
                              'completedAt': FieldValue.serverTimestamp(),
                            });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ Order Verified & Completed!"),
                            backgroundColor: Color(0xFF00bf63),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        setState(() => isError = true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Verify",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
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