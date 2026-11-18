import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Clock in the suite. Not in the core's `ZtSuite` list yet, so the other
/// apps don't link to it before it's released.
const ZtSuiteApp clockSuiteApp = ZtSuiteApp(
  appId: 'clock',
  name: 'Clock',
  tagline: 'Alarms, timer, stopwatch and world clock',
  icon: Icons.alarm,
  accent: Color(0xFF6366F1), // indigo
  androidPackage: 'dev.sagron.zerotrustclock',
);

const ZtAppConfig clockAppConfig = ZtAppConfig(
  appId: 'clock',
  displayName: 'Zero-Trust Clock',
  accent: Color(0xFF6366F1),
);
