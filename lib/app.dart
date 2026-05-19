import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:http/http.dart' as http;
import 'package:midieval/app_localization.dart';
import 'package:midieval/midi/midi_models.dart';

part 'auth/app_shell.dart';
part 'profile/profile_settings_page.dart';
part 'home/home_page.dart';
part 'home/sketches/home_page_sketches.dart';
part 'home/audio/home_page_audio_playback.dart';
part 'home/view/home_page_view.dart';
part 'home/view/home_record_panel.dart';
part 'home/view/home_conversion_summary_panel.dart';
part 'home/view/home_sketches_header.dart';
part 'home/view/home_sketches_list.dart';
part 'home/tutorial/home_page_tutorial.dart';
part 'home/tutorial/home_page_tutorial_logic.dart';
part 'home/settings/home_page_settings.dart';
part 'home/random/home_page_random_melody.dart';
part 'home/conversion/home_page_conversion.dart';
part 'midi/editor/midi_editor_dialog.dart';
part 'home/tutorial/tutorial_callout.dart';

const String _brandLogoAsset = 'assets/branding/logo_concept.svg';
const String _brandLogoMarkAsset = 'assets/branding/logo_mark.svg';
