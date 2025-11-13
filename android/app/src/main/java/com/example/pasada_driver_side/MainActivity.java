package com.example.pasada_driver_side;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "app.minimize";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (MethodCall call, MethodChannel.Result result) -> {
                            if ("moveTaskToBack".equals(call.method)) {
                                boolean moved = moveTaskToBack(true);
                                result.success(moved);
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }
}
