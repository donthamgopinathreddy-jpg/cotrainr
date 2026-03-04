package com.example.cotrainr_flutter

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity required for Health Connect permission flow on Android 14+
// (registerForActivityResult needs ComponentActivity)
class MainActivity : FlutterFragmentActivity()
