import 'dart:html' as html;

String? webGetString(String key) => html.window.localStorage[key];

void webSetString(String key, String value) => html.window.localStorage[key] = value;

