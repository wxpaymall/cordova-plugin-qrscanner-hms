package com.tryvon2017.cordova;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.widget.Toast;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.PermissionHelper;

import com.huawei.hms.hmsscankit.ScanUtil;
import com.huawei.hms.ml.scan.HmsScan;
import com.huawei.hms.ml.scan.HmsScanAnalyzerOptions;

import org.json.JSONArray;
import org.json.JSONException;

import android.util.Log;
import java.util.Arrays;


public class QrScanner extends CordovaPlugin {
    private static final String TAG = "QrScanner";
    private final int PERMISSION_REQUEST_CODE = 2017; // 用于检查权限
    private final int REQUEST_CODE_SCAN = 2018; // 用于接收扫码结果
    private final int SCAN_RESULT_OK = -1;
    private final int PERMISSIONS_LENGTH = 2;

    private String[] permissions = {
            Manifest.permission.CAMERA,
            Manifest.permission.READ_EXTERNAL_STORAGE};

    private CallbackContext scanCallBack;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        Log.d(TAG, "execute called with action: " + action);
        if (action.equals("startScan")) {
            Log.d(TAG, "Starting QR scan process");
            scanCallBack = callbackContext;
            if(!hasPermisssion()){
                Log.d(TAG, "Permissions not granted, requesting permissions");
                requestPermissions(PERMISSION_REQUEST_CODE);
            } else {
                Log.d(TAG, "Permissions already granted, starting scan directly");
                scan(scanCallBack);
            }
            return true;
        }
        Log.w(TAG, "Unknown action: " + action);
        return false;
    }

    private void scan(CallbackContext callbackContext) {
        Log.d(TAG, "scan method called, setting up camera scan");
        try {
            cordova.setActivityResultCallback(this);
            Log.d(TAG, "Starting HMS ScanUtil with request code: " + REQUEST_CODE_SCAN);
            ScanUtil.startScan(cordova.getActivity(), REQUEST_CODE_SCAN, new HmsScanAnalyzerOptions.Creator().setHmsScanTypes(HmsScan.ALL_SCAN_TYPE).create());
            Log.d(TAG, "ScanUtil.startScan called successfully");
        } catch (Exception e) {
            Log.e(TAG, "Error starting scan: " + e.getMessage(), e);
            callbackContext.error("Failed to start scan: " + e.getMessage());
        }
    }

     @Override
     public void onActivityResult(int requestCode, int resultCode, Intent data) {
        Log.d(TAG, "onActivityResult called - requestCode: " + requestCode + ", resultCode: " + resultCode);
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode == SCAN_RESULT_OK && requestCode == REQUEST_CODE_SCAN && data != null) {
            Log.d(TAG, "Scan completed successfully, processing result");
            try {
                HmsScan hmsScan = data.getParcelableExtra(ScanUtil.RESULT);
                if (hmsScan != null) {
                    String codeResult = hmsScan.getOriginalValue();
                    Log.d(TAG, "Scan result: " + codeResult);
                    scanCallBack.success(codeResult);
                } else {
                    Log.e(TAG, "HmsScan result is null");
                    scanCallBack.error("Scan result is null");
                }
            } catch (Exception e) {
                Log.e(TAG, "Error processing scan result: " + e.getMessage(), e);
                scanCallBack.error("Error processing scan result: " + e.getMessage());
            }
        } else {
            Log.w(TAG, "Scan cancelled or failed - requestCode: " + requestCode + ", resultCode: " + resultCode + ", data: " + (data != null ? "not null" : "null"));
        }
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) {
        Log.d(TAG, "onRequestPermissionResult called - requestCode: " + requestCode);
        Log.d(TAG, "Permissions requested: " + Arrays.toString(permissions));
        Log.d(TAG, "Grant results: " + Arrays.toString(grantResults));
        
        if (requestCode == PERMISSION_REQUEST_CODE && grantResults.length == PERMISSIONS_LENGTH && grantResults[0] == PackageManager.PERMISSION_GRANTED && grantResults[1] == PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "All permissions granted, proceeding with scan");
            scan(scanCallBack);
        } else {
            Log.e(TAG, "Permission denied - requestCode: " + requestCode + ", expected: " + PERMISSION_REQUEST_CODE);
            Log.e(TAG, "Grant results length: " + grantResults.length + ", expected: " + PERMISSIONS_LENGTH);
            if (grantResults.length > 0) {
                Log.e(TAG, "Camera permission result: " + grantResults[0] + " (0=GRANTED, -1=DENIED)");
                if (grantResults.length > 1) {
                    Log.e(TAG, "Storage permission result: " + grantResults[1] + " (0=GRANTED, -1=DENIED)");
                }
            }
            scanCallBack.error("permission denied");
        }
    }

    /**
     * 检查权限
     * @return
     */
    public boolean hasPermisssion() {
        Log.d(TAG, "Checking permissions: " + Arrays.toString(permissions));
        for (String p : permissions) {
            boolean hasPermission = PermissionHelper.hasPermission(this, p);
            Log.d(TAG, "Permission " + p + ": " + (hasPermission ? "GRANTED" : "DENIED"));
            if (!hasPermission) {
                Log.w(TAG, "Permission " + p + " is missing");
                return false;
            }
        }
        Log.d(TAG, "All permissions are granted");
        return true;
    }

    public void requestPermissions(int requestCode) {
        Log.d(TAG, "Requesting permissions with code: " + requestCode);
        Log.d(TAG, "Permissions to request: " + Arrays.toString(permissions));
        PermissionHelper.requestPermissions(this, requestCode, permissions);
    }

}
