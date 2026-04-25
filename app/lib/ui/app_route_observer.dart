import 'package:flutter/material.dart';

/// Passed to [MaterialApp.navigatorObservers] so routes can use [RouteAware]
/// (e.g. refresh home when returning from profile / membership).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
