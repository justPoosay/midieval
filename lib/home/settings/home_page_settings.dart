part of 'package:midieval/app.dart';

class _HomePageSettingsSheet {
  static Future<void> open(_MyHomePageState state) async {
    if (!state.mounted) return;
    await showModalBottomSheet<void>(
      context: state.context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10182B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              void sync(void Function() fn) {
                state._applyState(fn);
                setModalState(() {});
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conversion Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      buildBlock(
                        title: 'Tempo',
                        child: Row(
                          children: [
                            Switch(
                              value: state._lockTempo,
                              onChanged: (value) =>
                                  sync(() => state._lockTempo = value),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Tempo lock',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: state._tempoController,
                                keyboardType: TextInputType.number,
                                enabled: state._lockTempo,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  suffixText: 'BPM',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      buildBlock(
                        title: 'Meter',
                        child: Row(
                          children: [
                            Switch(
                              value: state._lockMeter,
                              onChanged: (value) =>
                                  sync(() => state._lockMeter = value),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Meter lock',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 56,
                              child: TextField(
                                controller: state._timeSigTopController,
                                keyboardType: TextInputType.number,
                                enabled: state._lockMeter,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('/'),
                            ),
                            SizedBox(
                              width: 56,
                              child: TextField(
                                controller: state._timeSigBottomController,
                                keyboardType: TextInputType.number,
                                enabled: state._lockMeter,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      buildBlock(
                        title: 'Key and Scale',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Switch(
                                  value: state._constrainToScale,
                                  onChanged: (value) => sync(
                                    () => state._constrainToScale = value,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Key/Scale constraint',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: state._selectedKey,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    items:
                                        const [
                                              'C',
                                              'C#',
                                              'D',
                                              'D#',
                                              'E',
                                              'F',
                                              'F#',
                                              'G',
                                              'G#',
                                              'A',
                                              'A#',
                                              'B',
                                            ]
                                            .map(
                                              (k) => DropdownMenuItem(
                                                value: k,
                                                child: Text(k),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: state._constrainToScale
                                        ? (value) {
                                            if (value == null) return;
                                            sync(
                                              () => state._selectedKey = value,
                                            );
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: state._selectedScale,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: const ['Major', 'Minor']
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: state._constrainToScale
                                        ? (value) {
                                            if (value == null) return;
                                            sync(
                                              () =>
                                                  state._selectedScale = value,
                                            );
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Widget buildBlock({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
