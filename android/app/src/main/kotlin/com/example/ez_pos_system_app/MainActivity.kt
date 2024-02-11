package com.example.ez_pos_system_app

import io.flutter.embedding.android.FlutterActivity

import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

import com.squareup.sdk.pos.ChargeRequest;
import com.squareup.sdk.pos.CurrencyCode;
import com.squareup.sdk.pos.PosClient;
import com.squareup.sdk.pos.PosSdk;
import com.squareup.sdk.pos.PosApi;
import java.util.concurrent.TimeUnit;
import android.content.Intent;
import android.net.Uri;
import android.app.Activity
import android.util.Log

class MainActivity: FlutterActivity() {
  private val CHARGE_REQUEST_CODE = 0xCAFE;
  private var posClient: PosClient? = null;
  private var fResult: MethodChannel.Result? = null;
  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ezpos/square")
    channel.setMethodCallHandler { methodCall: MethodCall, result: MethodChannel.Result ->
      if (methodCall.method == "openSquare") {
        fResult = result
        val args = methodCall.arguments as Map<String, Any>
        if (args["price"] is Int && args["memo"] is String) {
          val price = args["price"] as Int
          val memo = args["memo"] as String
          posClient = PosSdk.createClient(this, "sq0idp-vhCe_equHTU89J3kaC5Z3Q")
          openSquare(price, memo)
        } else {
          result.error("INVALID_ARGUMENT", "Invalid arguments", null)
        }
      } else {
        result.notImplemented()
      }
    }
  }

  private fun openSquare(price: Int, memo: String) {
    val chargeRequest: ChargeRequest.Builder = ChargeRequest.Builder(price, CurrencyCode.JPY)
      .note(memo)
      .autoReturn(PosApi.AUTO_RETURN_TIMEOUT_MIN_MILLIS, TimeUnit.MILLISECONDS)
    try {
      val chargeIntent = posClient!!.createChargeIntent(chargeRequest.build())
      startActivityForResult(chargeIntent, CHARGE_REQUEST_CODE)
    } catch (e: Exception) {
      fResult!!.error("ACTIVITY_FAILED", e.message, null)
    }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode == CHARGE_REQUEST_CODE) {
      if (data == null) {
        // handle error
        fResult!!.error("INVALID_RESULT", "Invalid result", null)
        return
      }
      if (resultCode == Activity.RESULT_OK) {
        val res = posClient!!.parseChargeSuccess(data)
        fResult!!.success(res.clientTransactionId)
      } else {
        val error = posClient!!.parseChargeError(data)
        fResult!!.error("CHARGE_FAILED", "Charge failed", error.debugDescription)
      }
    }
  }
}
