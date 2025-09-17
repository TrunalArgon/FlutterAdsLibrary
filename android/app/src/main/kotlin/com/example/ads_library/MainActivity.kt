package com.example.ads_library

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()


//package com.example.ads_library
//
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.content.IntentFilter
//import android.net.ConnectivityManager
//import io.flutter.embedding.android.FlutterActivity
//
//class MainActivity : FlutterActivity() {
//
//    private var receiverRegistered = false
//
//    private val receiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context, intent: Intent) {
//            // TODO: handle connectivity (or whatever you need)
//        }
//    }
//
//    override fun onStart() {
//        super.onStart()
//        if (!receiverRegistered) {
//            // Activity-scoped registration
//            registerReceiver(receiver, IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION))
//            receiverRegistered = true
//        }
//    }
//
//    override fun onStop() {
//        super.onStop()
//        if (receiverRegistered) {
//            unregisterReceiver(receiver)
//            receiverRegistered = false
//        }
//    }
//}