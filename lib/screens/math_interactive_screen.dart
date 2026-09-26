// math_interactive_screen.dart
//
// ANVAYA — Math Interactive Scene: two "Equal Sharing" drag-and-drop
// division manipulatives, stacked on one scrollable screen (9 ÷ 3 apples,
// then 8 ÷ 4 pastries). Entirely offline, local widget state only.
//
// LAYOUT-SHIFT FIX: each pool item's visibility is tracked individually
// (appleVisible/pastryVisible, one bool per pool slot, keyed by that
// slot's fixed index) rather than the pool simply shrinking by a
// remaining-count. A placed item renders as a same-sized SizedBox instead
// of being removed from the Wrap, so every other item — and the basket/
// plate targets below — never jump position when one is dropped.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MathInteractiveScreen extends StatefulWidget {
  const MathInteractiveScreen({super.key});

  @override
  State<MathInteractiveScreen> createState() => _MathInteractiveScreenState();
}

class _MathInteractiveScreenState extends State<MathInteractiveScreen> {
  static const int totalApples = 9;
  static const int basketCount = 3;
  static const int totalPastries = 8;
  static const int plateCount = 4;

  // --- Problem 1: Apples ----------------------------------------------------
  List<bool> appleVisible = List.filled(totalApples, true);
  List<int> basketContents = [0, 0, 0];

  // --- Problem 2: Pastries ---------------------------------------------------
  List<bool> pastryVisible = List.filled(totalPastries, true);
  List<int> plateContents = [0, 0, 0, 0];

  void _handleAppleDrop(int basketIndex, int poolIndex) {
    if (!appleVisible[poolIndex]) return;
    setState(() {
      appleVisible[poolIndex] = false;
      basketContents[basketIndex]++;
    });
    if (appleVisible.every((visible) => !visible)) {
      _evaluate(
        contents: basketContents,
        expectedPerTarget: totalApples / basketCount,
        equation: '$totalApples ÷ $basketCount = ${(totalApples / basketCount).round()}',
        targetLabel: 'basket',
        onReset: _resetApples,
      );
    }
  }

  void _handlePastryDrop(int plateIndex, int poolIndex) {
    if (!pastryVisible[poolIndex]) return;
    setState(() {
      pastryVisible[poolIndex] = false;
      plateContents[plateIndex]++;
    });
    if (pastryVisible.every((visible) => !visible)) {
      _evaluate(
        contents: plateContents,
        expectedPerTarget: totalPastries / plateCount,
        equation: '$totalPastries ÷ $plateCount = ${(totalPastries / plateCount).round()}',
        targetLabel: 'plate',
        onReset: _resetPastries,
      );
    }
  }

  void _evaluate({
    required List<int> contents,
    required double expectedPerTarget,
    required String equation,
    required String targetLabel,
    required VoidCallback onReset,
  }) {
    final isEqual = contents.every((count) => count == expectedPerTarget);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => isEqual
          ? _buildSuccessDialog(dialogContext, equation: equation, targetLabel: targetLabel, onReset: onReset)
          : _buildErrorDialog(dialogContext, targetLabel: targetLabel, onReset: onReset),
    );
  }

  void _resetApples() {
    setState(() {
      appleVisible = List.filled(totalApples, true);
      basketContents = List.filled(basketCount, 0);
    });
  }

  void _resetPastries() {
    setState(() {
      pastryVisible = List.filled(totalPastries, true);
      plateContents = List.filled(plateCount, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Equal Sharing')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildInstruction('1. Share $totalApples apples equally among $basketCount baskets.'),
              _buildPool(visible: appleVisible, assetPath: 'assets/images/apple.png'),
              _buildTargetRow(
                count: basketCount,
                contents: basketContents,
                baseAssetPath: 'assets/images/basket.png',
                baseWidth: 90,
                miniAssetPath: 'assets/images/apple.png',
                onAccept: _handleAppleDrop,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(thickness: 2, height: 60),
              ),
              _buildInstruction('2. Share $totalPastries pastries equally among $plateCount plates.'),
              _buildPool(visible: pastryVisible, assetPath: 'assets/images/pastry.png'),
              _buildTargetRow(
                count: plateCount,
                contents: plateContents,
                baseAssetPath: 'assets/images/plate.png',
                baseWidth: 70,
                miniAssetPath: 'assets/images/pastry.png',
                onAccept: _handlePastryDrop,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.skyContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
      ),
    );
  }

  /// The pool of loose, still-unplaced items. Each slot's `Draggable` data
  /// is that slot's own pool index (not a fixed quantity) — the
  /// `DragTarget` that accepts it uses this index to flip the matching
  /// [visible] entry to false, which is what lets a placed item collapse
  /// to a same-sized [SizedBox] here instead of the whole Wrap reflowing.
  Widget _buildPool({required List<bool> visible, required String assetPath}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: List.generate(visible.length, (index) {
          if (!visible[index]) {
            return const SizedBox(width: 45, height: 45);
          }
          return Draggable<int>(
            data: index,
            feedback: _DragFeedback(assetPath: assetPath),
            childWhenDragging: const SizedBox(width: 45, height: 45),
            child: Image.asset(assetPath, width: 45, height: 45),
          );
        }),
      ),
    );
  }

  /// A `Row` of [count] `Expanded` targets (baskets or plates), so they
  /// divide the screen width perfectly regardless of phone width.
  Widget _buildTargetRow({
    required int count,
    required List<int> contents,
    required String baseAssetPath,
    required double baseWidth,
    required String miniAssetPath,
    required void Function(int targetIndex, int poolIndex) onAccept,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: List.generate(count, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                // A fixed, generous hit-area for the whole column — not
                // just the basket/plate image's own bounds — so dropping
                // anywhere in that column registers.
                width: double.infinity,
                height: 150,
                child: DragTarget<int>(
                  onAcceptWithDetails: (details) => onAccept(index, details.data),
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: isHovering ? AppTheme.mintContainer : Colors.transparent,
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Image.asset(baseAssetPath, fit: BoxFit.contain, width: baseWidth),
                          // Slightly above dead-bottom so the mini items
                          // read as sitting inside the basket/plate rather
                          // than beneath it.
                          Align(
                            alignment: const Alignment(0, 0.55),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 2,
                              runSpacing: 2,
                              children: List.generate(
                                contents[index],
                                (_) => Image.asset(miniAssetPath, width: 20, height: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSuccessDialog(
    BuildContext dialogContext, {
    required String equation,
    required String targetLabel,
    required VoidCallback onReset,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
        child: Icon(Icons.celebration_rounded, color: Colors.green.shade700, size: 34),
      ),
      title: Text(
        'Great Job!',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w800, fontSize: 22),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            equation,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.green.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Every $targetLabel has an equal share!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green.shade600, fontSize: 14),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onReset();
            },
            child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorDialog(
    BuildContext dialogContext, {
    required String targetLabel,
    required VoidCallback onReset,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
        child: Icon(Icons.sentiment_dissatisfied_rounded, color: Colors.red.shade400, size: 34),
      ),
      title: Text(
        'Oops!',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w800, fontSize: 22),
      ),
      content: Text(
        "The ${targetLabel}s aren't equal yet. Let's try again.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.red.shade400, fontSize: 15),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onReset();
            },
            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// The Draggable's `feedback` widget — the item image that follows the
/// finger while dragging. Slightly larger than the resting image, with a
/// drop shadow, so it visibly "lifts" off the screen.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Image.asset(assetPath, width: 58, height: 58),
      ),
    );
  }
}
