// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<void> initWebStorage() async {}

String? webGetString(String key) => html.window.localStorage[key];

void webSetString(String key, String value) =>
    html.window.localStorage[key] = value;
