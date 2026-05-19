// ignore_for_file: unused_element

part of 'package:midieval/app.dart';

class _HomePageTutorialBuilders {
  static Widget buildOverlay(_MyHomePageState state, ColorScheme colorScheme) {
    return Positioned.fill(
      child: Builder(
        builder: (overlayContext) {
          final targetKey = state._tutorialTargetKey();
          final targetCenter = targetKey == null
              ? null
              : _targetCenterInOverlay(
                  overlayContext: overlayContext,
                  targetKey: targetKey,
                );
          final size = MediaQuery.of(overlayContext).size;
          final cardTop = targetCenter == null
              ? 88.0
              : targetCenter.dy < size.height * 0.5
              ? (size.height * 0.62).clamp(96.0, size.height - 190)
              : 86.0;
          final cardRect = Rect.fromLTWH(12, cardTop, size.width - 24, 124);

          return Stack(
            children: [
              AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.black.withValues(alpha: 0.48)),
              ),
              if (targetCenter != null)
                _TutorialCurvedArrow(
                  start: _anchorPointOnRect(cardRect, targetCenter),
                  end: targetCenter,
                ),
              Positioned(
                top: cardTop,
                left: 12,
                right: 12,
                child: buildCard(state, colorScheme),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget buildCard(_MyHomePageState state, ColorScheme colorScheme) {
    return Material(
      color: const Color(0xEE111A2D),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state._tutorialHint(),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: state._advanceTutorial,
              child: const Text('Next ->'),
            ),
            TextButton(
              onPressed: state._finishTutorial,
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}
