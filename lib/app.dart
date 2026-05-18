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
import 'package:midieval/midi_models.dart';

part 'app_shell.dart';
part 'profile_settings_page.dart';
part 'home_page.dart';
part 'midi_editor_dialog.dart';
part 'tutorial_callout.dart';

const String _brandLogoAsset = 'assets/branding/logo_concept.svg';
const String _brandLogoMarkAsset = 'assets/branding/logo_mark.svg';
