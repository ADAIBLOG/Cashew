package com.budget.tracker_app

import io.flutter.embedding.android.FlutterFragmentActivity
import androidx.activity.OnBackPressedCallback

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle back press to move task to back
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Instead of finishing the activity, move the app to background
                moveTaskToBack(true)
            }
        })
    }
}
