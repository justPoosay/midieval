import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

class KeyScaleConstraint {
  const KeyScaleConstraint({required this.tonic, required this.isMinor});

  final int tonic;
  final bool isMinor;
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class PlayPreviewIntent extends Intent {
  const PlayPreviewIntent();
}

class EditableMidiNote {
  EditableMidiNote({
    required this.note,
    required this.startTick,
    required this.durationTicks,
    required this.velocity,
  });

  factory EditableMidiNote.copy(EditableMidiNote n) => EditableMidiNote(
    note: n.note,
    startTick: n.startTick,
    durationTicks: n.durationTicks,
    velocity: n.velocity,
  );

  int note;
  int startTick;
  int durationTicks;
  int velocity;
}

class ParsedMidi {
  ParsedMidi({
    required this.ticksPerQuarter,
    required this.tempoBpm,
    required this.beatsPerMeasure,
    required this.beatUnit,
    required this.notes,
  });

  final int ticksPerQuarter;
  final int tempoBpm;
  final int beatsPerMeasure;
  final int beatUnit;
  final List<EditableMidiNote> notes;

  static ParsedMidi? tryParse(Uint8List bytes) {
    if (bytes.length < 14 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'MThd') {
      return null;
    }
    final headerLength = _readUint32BE(bytes, 4);
    if (headerLength < 6 || bytes.length < 8 + headerLength) return null;
    final ticksPerQuarter = (bytes[12] << 8) | bytes[13];
    var tempoBpm = 120;
    var beatsPerMeasure = 4;
    var beatUnit = 4;
    final notes = <EditableMidiNote>[];

    var chunkOffset = 8 + headerLength;
    while (chunkOffset + 8 <= bytes.length) {
      final chunkType = String.fromCharCodes(
        bytes.sublist(chunkOffset, chunkOffset + 4),
      );
      final chunkLength = _readUint32BE(bytes, chunkOffset + 4);
      final chunkDataStart = chunkOffset + 8;
      final chunkDataEnd = chunkDataStart + chunkLength;
      if (chunkDataEnd > bytes.length) break;

      if (chunkType == 'MTrk') {
        var idx = chunkDataStart;
        var tick = 0;
        var runningStatus = 0;
        final active = <int, int>{};

        while (idx < chunkDataEnd) {
          final delta = _readVarLen(bytes, idx);
          idx = delta.next;
          tick += delta.value;
          if (idx >= chunkDataEnd) break;

          var status = bytes[idx];
          if (status < 0x80) {
            if (runningStatus == 0) {
              break;
            }
            status = runningStatus;
          } else {
            idx++;
            runningStatus = status;
          }

          if (status == 0xFF) {
            if (idx + 1 > chunkDataEnd) break;
            final metaType = bytes[idx++];
            final len = _readVarLen(bytes, idx);
            idx = len.next;
            if (metaType == 0x51 && len.value == 3 && idx + 2 < chunkDataEnd) {
              final mpq =
                  (bytes[idx] << 16) | (bytes[idx + 1] << 8) | bytes[idx + 2];
              if (mpq > 0) tempoBpm = (60000000 / mpq).round();
            } else if (metaType == 0x58 &&
                len.value >= 2 &&
                idx + 1 < chunkDataEnd) {
              beatsPerMeasure = bytes[idx].clamp(1, 12);
              final denominatorPower = bytes[idx + 1].clamp(0, 8);
              beatUnit = 1 << denominatorPower;
            }
            idx += len.value;
            continue;
          }

          if (status == 0xF0 || status == 0xF7) {
            final len = _readVarLen(bytes, idx);
            idx = len.next + len.value;
            continue;
          }

          final eventType = status & 0xF0;
          if (eventType == 0x90 || eventType == 0x80) {
            if (idx + 1 >= chunkDataEnd) break;
            final note = bytes[idx++];
            final velocity = bytes[idx++];
            final isOn = eventType == 0x90 && velocity > 0;
            if (isOn) {
              active[note] = tick;
            } else {
              final start = active.remove(note);
              if (start != null && tick > start) {
                notes.add(
                  EditableMidiNote(
                    note: note,
                    startTick: start,
                    durationTicks: tick - start,
                    velocity: math.max(1, velocity),
                  ),
                );
              }
            }
            continue;
          }

          if (eventType == 0xC0 || eventType == 0xD0) {
            idx += 1;
          } else {
            idx += 2;
          }
        }
      }
      chunkOffset = chunkDataEnd;
    }

    if (notes.isEmpty) return null;
    notes.sort((a, b) => a.startTick.compareTo(b.startTick));
    return ParsedMidi(
      ticksPerQuarter: ticksPerQuarter > 0 ? ticksPerQuarter : 480,
      tempoBpm: tempoBpm,
      beatsPerMeasure: beatsPerMeasure,
      beatUnit: beatUnit,
      notes: notes,
    );
  }

  Uint8List rebuild(
    List<EditableMidiNote> edited, {
    int? tempoOverrideBpm,
    int? beatsPerMeasureOverride,
    int? beatUnitOverride,
  }) {
    final track = <int>[];
    final effectiveTempo = math.max(1, tempoOverrideBpm ?? tempoBpm);
    final effectiveBeatsPerMeasure =
        (beatsPerMeasureOverride ?? beatsPerMeasure).clamp(1, 12);
    final allowedBeatUnits = {1, 2, 4, 8, 16, 32, 64, 128, 256};
    final candidateBeatUnit = beatUnitOverride ?? beatUnit;
    final effectiveBeatUnit = allowedBeatUnits.contains(candidateBeatUnit)
        ? candidateBeatUnit
        : 4;
    final mpq = (60000000 / effectiveTempo).round();
    final denominatorPower = (math.log(effectiveBeatUnit) / math.ln2)
        .round()
        .clamp(0, 8);
    track.addAll([
      0x00,
      0xFF,
      0x51,
      0x03,
      (mpq >> 16) & 0xFF,
      (mpq >> 8) & 0xFF,
      mpq & 0xFF,
      0x00,
      0xFF,
      0x58,
      0x04,
      effectiveBeatsPerMeasure,
      denominatorPower,
      0x18,
      0x08,
      0x00,
      0xC0,
      0x00,
    ]);

    final events = <_MidiEditEvent>[];
    for (final n in edited) {
      final start = math.max(0, n.startTick).toInt();
      final end = start + math.max(1, n.durationTicks).toInt();
      events.add(_MidiEditEvent(start, true, n.note, n.velocity.clamp(1, 127)));
      events.add(_MidiEditEvent(end, false, n.note, 0));
    }
    events.sort((a, b) {
      final t = a.tick.compareTo(b.tick);
      if (t != 0) return t;
      if (a.on == b.on) return 0;
      return a.on ? 1 : -1;
    });

    var prevTick = 0;
    for (final e in events) {
      track.addAll(_writeVarLen(math.max(0, e.tick - prevTick)));
      track.add(e.on ? 0x90 : 0x80);
      track.add(e.note.clamp(0, 127));
      track.add(e.velocity.clamp(0, 127));
      prevTick = e.tick;
    }
    track.addAll([0x00, 0xFF, 0x2F, 0x00]);

    return Uint8List.fromList([
      0x4D,
      0x54,
      0x68,
      0x64,
      0x00,
      0x00,
      0x00,
      0x06,
      0x00,
      0x00,
      0x00,
      0x01,
      (ticksPerQuarter >> 8) & 0xFF,
      ticksPerQuarter & 0xFF,
      0x4D,
      0x54,
      0x72,
      0x6B,
      (track.length >> 24) & 0xFF,
      (track.length >> 16) & 0xFF,
      (track.length >> 8) & 0xFF,
      track.length & 0xFF,
      ...track,
    ]);
  }

  static _VarResult _readVarLen(Uint8List bytes, int start) {
    var idx = start;
    var value = 0;
    int b;
    do {
      if (idx >= bytes.length) break;
      b = bytes[idx++];
      value = (value << 7) | (b & 0x7F);
    } while ((b & 0x80) != 0);
    return _VarResult(value, idx);
  }

  static List<int> _writeVarLen(int value) {
    var buffer = value & 0x7F;
    while ((value >>= 7) > 0) {
      buffer <<= 8;
      buffer |= ((value & 0x7F) | 0x80);
    }
    final out = <int>[];
    while (true) {
      out.add(buffer & 0xFF);
      if ((buffer & 0x80) != 0) {
        buffer >>= 8;
      } else {
        break;
      }
    }
    return out;
  }

  static int _readUint32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}

class _VarResult {
  const _VarResult(this.value, this.next);
  final int value;
  final int next;
}

class _MidiEditEvent {
  const _MidiEditEvent(this.tick, this.on, this.note, this.velocity);
  final int tick;
  final bool on;
  final int note;
  final int velocity;
}
