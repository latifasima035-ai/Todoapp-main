package com.example.habit_tracker

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "habit_tracker/timezone"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "getLocalTimezone") {
				try {
					val tz = java.util.TimeZone.getDefault().id
					result.success(tz)
				} catch (e: Exception) {
					result.error("UNAVAILABLE", "Could not get timezone", null)
				}
			} else {
				result.notImplemented()
			}
		}
	}
}
