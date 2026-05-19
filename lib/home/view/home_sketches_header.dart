part of 'package:midieval/app.dart';

class _HomeSketchesHeaderBuilder {
  static Widget build(_MyHomePageState state, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        key: state._topActionsKey,
        children: [
          Text(
            context.tr('sketches'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Generate random melody',
            onPressed: state._generateRandomMelodySketch,
            icon: const Icon(Icons.casino_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: state._refreshSketches,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
