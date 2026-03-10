import 'package:flutter/material.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  final Color primaryGreen = const Color(0xFF00bf63);

  late AnimationController _animationController;
  int? _expandedIndex;

  static const List<Map<String, String>> _faqs = [
    {
      "question": "How does FoodNow work?",
      "answer":
          "Users buy surplus food from nearby shops at a discounted price and pick it up before the expiry time.",
      "icon": "🛍️",
    },
    {
      "question": "When should I pick up my order?",
      "answer":
          "You must collect the food before the expiry time shown in the item.",
      "icon": "⏰",
    },
    {
      "question": "What happens if I don't pick up the order?",
      "answer":
          "If the food is not collected before the expiry time, the order will automatically expire and cannot be refunded.",
      "icon": "⚠️",
    },
    {
      "question": "Can I cancel my order?",
      "answer":
          "Orders usually cannot be cancelled after payment because the food is reserved for you.",
      "icon": "❌",
    },
    {
      "question": "What if the seller cancels the order?",
      "answer":
          "If a seller cancels your order, the full amount will be refunded automatically.",
      "icon": "🔄",
    },
    {
      "question": "How are refunds processed?",
      "answer":
          "Refunds are processed through Razorpay and usually take 5–7 business days to reflect in your bank account.",
      "icon": "💳",
    },
    {
      "question": "Is online payment required?",
      "answer":
          "Yes. All orders must be paid online using secure payment methods.",
      "icon": "🔒",
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          "Help & Support",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),
            _buildFAQSection(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
              ),
            ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(36),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Icon with layered rings
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: primaryGreen,
                      size: 28,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                "How can we help you?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Find answers to common questions about\nusing the FoodNow app.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAQ Section ────────────────────────────────────────────────────────────

  Widget _buildFAQSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 18),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "FREQUENTLY ASKED QUESTIONS",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[500],
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // FAQ tiles
          ...List.generate(_faqs.length, (index) {
            final delay = (index * 0.08).clamp(0.0, 0.7);
            final end = (delay + 0.35).clamp(0.1, 1.0);

            return FadeTransition(
              opacity: CurvedAnimation(
                parent: _animationController,
                curve: Interval(delay, end, curve: Curves.easeOut),
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(delay, end, curve: Curves.easeOutCubic),
                      ),
                    ),
                child: _buildFAQTile(index),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFAQTile(int index) {
    final faq = _faqs[index];
    final isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () => setState(() {
        _expandedIndex = isExpanded ? null : index;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isExpanded
                ? primaryGreen.withOpacity(0.25)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isExpanded
                  ? primaryGreen.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isExpanded ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question row
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                child: Row(
                  children: [
                    // Emoji icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? primaryGreen.withOpacity(0.1)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          faq["icon"]!,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Question text
                    Expanded(
                      child: Text(
                        faq["question"]!,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isExpanded
                              ? const Color(0xFF111111)
                              : Colors.black87,
                          height: 1.3,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Chevron
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? primaryGreen.withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isExpanded ? primaryGreen : Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Answer (animated expand)
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    faq["answer"]!,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey[600],
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 280),
                sizeCurve: Curves.easeInOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
