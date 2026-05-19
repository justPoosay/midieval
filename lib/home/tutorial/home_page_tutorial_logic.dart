// ignore_for_file: unused_element

part of 'package:midieval/app.dart';

extension _HomePageTutorialLogic on _MyHomePageState {
  void _startTutorial() {
    if (!mounted) return;
    _applyState(() {
      _tutorialActive = true;
      _tutorialStep = _MyHomePageState._tutorialStepRecord;
    });
  }

  void _finishTutorial() {
    if (!mounted) return;
    _applyState(() {
      _tutorialActive = false;
      _tutorialStep = 0;
    });
  }

  void _advanceTutorial() {
    if (!_tutorialActive) return;
    if (_tutorialStep >= _MyHomePageState._tutorialStepSettings) {
      _finishTutorial();
      return;
    }
    _applyState(() => _tutorialStep++);
  }

  String _tutorialHint() {
    switch (_tutorialStep) {
      case _MyHomePageState._tutorialStepRecord:
        return 'Record a melody here. Tap once to start and once to stop.';
      case _MyHomePageState._tutorialStepPlayRename:
        return 'Use these actions on a sketch card to rename and play clips.';
      case _MyHomePageState._tutorialStepConversion:
        return 'Open conversion settings to control tempo, meter, and key/scale.';
      case _MyHomePageState._tutorialStepTopActions:
        return 'Top actions: generate a random melody and refresh the list.';
      case _MyHomePageState._tutorialStepSettings:
        return 'Open profile/settings from here.';
      default:
        return '';
    }
  }

  GlobalKey? _tutorialTargetKey() {
    switch (_tutorialStep) {
      case _MyHomePageState._tutorialStepRecord:
        return _recordCardKey;
      case _MyHomePageState._tutorialStepPlayRename:
        return _firstSketchActionsKey;
      case _MyHomePageState._tutorialStepConversion:
        return _conversionCardKey;
      case _MyHomePageState._tutorialStepTopActions:
        return _topActionsKey;
      case _MyHomePageState._tutorialStepSettings:
        return _settingsIconKey;
      default:
        return null;
    }
  }
}
