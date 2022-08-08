package com.clv.nhacvo.clv_nhacvo_print;


import androidx.annotation.NonNull;

import android.Manifest;
import android.app.Activity;
import android.app.Application;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.IntentSender;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Build;
import android.os.ParcelUuid;
import android.os.Parcelable;
import android.provider.Settings;
import android.util.Log;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.*;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;

import com.clv.nhacvo.printer.EscPosPrinter;
import com.clv.nhacvo.printer.connection.bluetooth.BluetoothConnection;
import com.clv.nhacvo.printer.connection.bluetooth.BluetoothConnections;
import com.clv.nhacvo.printer.connection.bluetooth.BluetoothPrintersConnections;
import com.clv.nhacvo.printer.textparser.PrinterTextParserImg;
import com.clv.nhacvo.printer.exceptions.EscPosConnectionException;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.common.api.ResolvableApiException;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.LocationSettingsRequest;
import com.google.android.gms.location.LocationSettingsResponse;
import com.google.android.gms.location.LocationSettingsStatusCodes;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;


import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import android.widget.Toast;

/** ClvNhacvoPrintPlugin */
public class ClvNhacvoPrintPlugin implements FlutterPlugin, ActivityAware, MethodCallHandler, RequestPermissionsResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private static final String TAG = "BluetoothPrintPlugin";

  private MethodChannel channel;
  private MethodChannel channelPrint;
  private MethodChannel getListBluetoothPrinters;
  private MethodChannel checkState;
  private LocationRequest locationRequest;
  private static final int REQUEST_CHECK_SETTINGS = 10001;
  private ArrayList<String> mDeviceList = new ArrayList<String>();
  private BluetoothAdapter mBluetoothAdapter;
  Set<BluetoothDevice> pairedDevices;
  ArrayList<DevicesModel> devices = new ArrayList<DevicesModel>();
  public static final int PERMISSION_BLUETOOTH = 1;
  private Object initializationLock = new Object();
  private MethodChannel.Result globalChannelResult;
  private FlutterEngine flutterEngine;


  private FlutterPluginBinding pluginBinding;
  private ActivityPluginBinding activityBinding;
  private Application application;
  private Activity activity;
  private Application context;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    pluginBinding = flutterPluginBinding;

  }
  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }
  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    globalChannelResult = result;
    try {
      Map<String, Object> arguments = call.arguments();
      System.out.println("NHACVO_DEMO: "+ call.method);
      if (call.method.toString() == "getPlatformVersion") {
        result.success("Android ${android.os.Build.VERSION.RELEASE}");
      } else  if (call.method.equals("getMessage")) {
        String message = "Android say hi!";
        result.success(message);
      } else if (call.method.equals("getDevices")) {
        ArrayList<DevicesModel> arrDevice = onGetDevicesBluetooth();
        result.success(arrDevice);
      } else if (call.method.equals("onPrint")) {
        System.out.println("I am here onPrint");
        byte[] bitmapInput = (byte[]) arguments.get("bitmapInput");
        int printerDpi = (int) arguments.get("printerDpi");
        int heightMax = (int) arguments.get("heightMax");
        int widthMax = (int) arguments.get("widthMax");
        int countPage = (int) arguments.get("countPage");
        Map<String, Object> arrStatus = onPrint(bitmapInput, printerDpi, widthMax, heightMax, 0, countPage);
        result.success(arrStatus);
      }else if (call.method.equals("onBluetooth")) {
        turnOnBluetooth();
      }else if (call.method.equals("offBluetooth")) {
        turnOffBluetooth();
      }
      else if (call.method.equals("checkStateBluetooth")) {
        boolean checkbluetooth = checkState();
        result.success(checkbluetooth);
      }
      else if (call.method.equals("scanDeviceBluetooth")) {
        scanDevice();
      }
    } catch (Exception e) {
      result.error("500", "Server Error", e.getMessage());
    }
  }


  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channelPrint.setMethodCallHandler(null);
    channel.setMethodCallHandler(null);
    getListBluetoothPrinters.setMethodCallHandler(null);
    checkState.setMethodCallHandler(null);
    pluginBinding = null;

  }


  public ClvNhacvoPrintPlugin(){
  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding) {
    activityBinding = binding;
    setup(
            pluginBinding.getBinaryMessenger(),
            (Application) pluginBinding.getApplicationContext(),
            activityBinding.getActivity(),
            null,
            activityBinding);
    flutterEngine = new FlutterEngine(application);
  }

  @Override
  public void onDetachedFromActivity() {
    Log.i(TAG, "onDetachedFromActivity");
    context = null;
    activityBinding.removeRequestPermissionsResultListener(this);
    activityBinding = null;
    channel.setMethodCallHandler(null);
    channelPrint.setMethodCallHandler(null);
    getListBluetoothPrinters.setMethodCallHandler(null);
    checkState.setMethodCallHandler(null);
    channel = null;
    channelPrint = null;
    getListBluetoothPrinters = null;
    checkState = null;
    mBluetoothAdapter = null;
    application = null;
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  private void setup(
          final BinaryMessenger messenger,
          final Application application,
          final Activity activity,
          final PluginRegistry.Registrar registrar,
          final ActivityPluginBinding activityBinding) {
    synchronized (initializationLock) {
      Log.i(TAG, "setup");
      this.activity = activity;
      this.application = application;
      this.context = application;
      channel = new MethodChannel(messenger, "com.clv.demo/print");
      channelPrint = new MethodChannel(messenger, "com.clv.demo/print");
      getListBluetoothPrinters = new MethodChannel(messenger, "com.clv.demo/getListBluetoothPrinters");
      checkState = new MethodChannel(messenger, "com.clv.demo/checkState");
      channel.setMethodCallHandler(this);
      channelPrint.setMethodCallHandler(this);
      getListBluetoothPrinters.setMethodCallHandler(this);
      checkState.setMethodCallHandler(this);
      mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
      mBluetoothAdapter.startDiscovery();
      if (registrar != null) {
        // V1 embedding setup for activity listeners.
        registrar.addRequestPermissionsResultListener(this);
      } else {
        // V2 embedding setup for activity listeners.
        activityBinding.addRequestPermissionsResultListener(this);
      }
    }
  }


  private static final int REQUEST_FINE_LOCATION_PERMISSIONS = 1452;


  private ArrayList<DevicesModel> onGetDevicesBluetooth() {
    pairedDevices = mBluetoothAdapter.getBondedDevices();
    devices = new ArrayList<>();

    for (BluetoothDevice bt : pairedDevices) {
//      devices.add(new DevicesModel(bt.getName(), bt.getAddress()));
    }
    return devices;
  }

  private Map<String, Object> onPrint(
          byte[] bitmapInput,
          int printerDpi ,
          int heightMax ,
          int widthMax,
          int callback,
          int countPage){
    Map<String, Object>  dataMap = new HashMap<>();
    String _message = "";
    if(callback < 3){
      callback +=1;
    }else{
      _message = "Callback Function Error";
      dataMap.put("message",_message);
      return dataMap;
    }
    try {
      if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) != PackageManager.PERMISSION_GRANTED) {
        ActivityCompat.requestPermissions( activityBinding.getActivity(), new String[]{Manifest.permission.BLUETOOTH}, PERMISSION_BLUETOOTH);
      } else {
        BluetoothConnection connection = BluetoothPrintersConnections.selectFirstPaired();
        if (connection != null) {
          EscPosPrinter printer = new EscPosPrinter(connection, printerDpi, 80f, 32);

          byte[]  bitMapData = bitmapInput;// stream.toByteArray()
          Bitmap decodedByte = BitmapFactory.decodeByteArray(bitMapData, 0, bitMapData.length);
          int widthTemp = decodedByte.getWidth();
          int heightTemp = decodedByte.getHeight();


          widthTemp = widthMax < 580 ? 580 : widthMax;

//          if(heightTemp > 900){
//            heightTemp = 900; // 900
//          }else if(heightTemp <200){
//            heightTemp = 200; // 200
//          }
//          else
//          {
          heightTemp = 900 * countPage;
//          }

          System.out.println( "-----------------Start--------------------");
          System.out.println( "Input:  " + widthMax + " || " + heightMax);
          System.out.println( "Current:  " + widthTemp + " || " + heightTemp);
          System.out.println( "------------------End---------------------");

          Bitmap resizedBitmap = Bitmap.createScaledBitmap(decodedByte, widthTemp, heightTemp, false);
          decodedByte.recycle();
          int width = resizedBitmap.getWidth();
          int height = resizedBitmap.getHeight();

          StringBuilder textToPrint = new StringBuilder();
          for(int y = 0; y < height; y += 256) {
            Bitmap bitmap = Bitmap.createBitmap(resizedBitmap, 0, y, width, (y + 256 >= height) ? height - y : 256);
            textToPrint.append("[C]<img>" + PrinterTextParserImg.bitmapToHexadecimalString(printer, bitmap) + "</img>\n");
          }
          printer.printFormattedTextAndCut(textToPrint.toString());
          _message = "Success";
        } else {
          // println("\"No printer was connected!\"");
          _message = "\"No printer was connected!\"";
          Map<String, Object> arrStatus = onPrint(bitmapInput, printerDpi, widthMax, heightMax, callback, countPage);
        }
      }
    }
    catch (Exception e) {
      _message = "Error";
      // println(e.getMessage());
    }
    dataMap.put("message",_message);
    return dataMap;
  }

  private void turnOnBluetooth (){
    LocationManager manager = (LocationManager) context.getSystemService( Context.LOCATION_SERVICE );
    if (!manager.isProviderEnabled( LocationManager.GPS_PROVIDER ) ) {
      turnOnGPS();
      IntentFilter filter = new IntentFilter();
      filter.addAction(LocationManager.PROVIDERS_CHANGED_ACTION);
      context.registerReceiver(getReceiver, filter);
    }
    else{
      try {
        if(mBluetoothAdapter == null)
        {
          Toast.makeText(context,"Bluetooth Not Supported",Toast.LENGTH_SHORT).show();
        }
        else{
          if(!mBluetoothAdapter.isEnabled()){
            activity.startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),1);
            Toast.makeText(context,"Bluetooth Turned ON",Toast.LENGTH_SHORT).show();
            IntentFilter filter = new IntentFilter();
            filter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
            context.registerReceiver(mBroadcastReceiver1, filter);
          }
        }
      }catch (Exception ex){
        System.out.println(ex.getMessage());
      }
    }
  }

  private boolean checkState(){
    boolean check = false;
    if(mBluetoothAdapter.isEnabled()){
      System.out.println("State 1: Bluetooth turn on !!");
      check = true;
    }else{
      System.out.println("State 1: Bluetooth turn off !!");
      check = false;
    }
    return check;
  }

//  private final BroadcastReceiver brCheckState = new BroadcastReceiver() {
//
//    @Override
//    public void onReceive(Context context, Intent intent) {
//      final String action = intent.getAction();
//      if (action.equals(BluetoothAdapter.ACTION_STATE_CHANGED)) {
//        if(mBluetoothAdapter.isEnabled()){
//          System.out.println("State 1: Bluetooth turn on !!");
//        }else{
//          System.out.println("State 1: Bluetooth turn off !!");
//        }
//      }
//    }
//  };

  private final BroadcastReceiver getReceiver = new BroadcastReceiver() {
    @Override
    public void onReceive( Context context, Intent intent )
    {
      LocationManager manager = (LocationManager) context.getSystemService( Context.LOCATION_SERVICE );
      if (intent.getAction().matches(LocationManager.PROVIDERS_CHANGED_ACTION)) {
        try {
          if(mBluetoothAdapter == null)
          {
            Toast.makeText(context,"Bluetooth Not Supported",Toast.LENGTH_SHORT).show();
          }
          else{
            if(!mBluetoothAdapter.isEnabled() && manager.isProviderEnabled( LocationManager.GPS_PROVIDER )){
              activity.startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),1);
              Toast.makeText(context,"Bluetooth Turned ON",Toast.LENGTH_SHORT).show();
              context.unregisterReceiver(getReceiver);
              IntentFilter filter = new IntentFilter();
              filter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
              context.registerReceiver(mBroadcastReceiver1, filter);
            }
          }
        }catch (Exception ex){
          System.out.println(ex.getMessage());
        }
      }
    }
  };


  private void scanDevice(){
    bluetoothScanning();
  }


  private final BroadcastReceiver mBroadcastReceiver1 = new BroadcastReceiver() {

    @Override
    public void onReceive(Context context, Intent intent) {
      final String action = intent.getAction();

      if (action.equals(BluetoothAdapter.ACTION_STATE_CHANGED) && mBluetoothAdapter.isEnabled()) {
        globalChannelResult.success("scan");
        context.unregisterReceiver(mBroadcastReceiver1);
      }
    }
  };

  private void turnOffBluetooth (){
    devices = new ArrayList<>();
    try {
      mBluetoothAdapter.disable();
      Toast.makeText(context,"Bluetooth Turned OFF", Toast.LENGTH_SHORT).show();
    }catch (Exception ex){
      System.out.println(ex.getMessage());
    }
  }

  private void turnOnGPS(){
    locationRequest = LocationRequest.create();
    locationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
    locationRequest.setInterval(5000);
    locationRequest.setFastestInterval(2000);

    LocationSettingsRequest.Builder builder = new LocationSettingsRequest.Builder()
            .addLocationRequest(locationRequest);
    builder.setAlwaysShow(true);

    Task<LocationSettingsResponse> result = LocationServices.getSettingsClient(context.getApplicationContext())
            .checkLocationSettings(builder.build());

    result.addOnCompleteListener(new OnCompleteListener<LocationSettingsResponse>() {
      @Override
      public void onComplete(@NonNull Task<LocationSettingsResponse> task) {
        try {
          LocationSettingsResponse response = task.getResult(ApiException.class);
          Toast.makeText(context, "GPS is already tured on", Toast.LENGTH_SHORT).show();
        } catch (ApiException e) {
          switch (e.getStatusCode()) {
            case LocationSettingsStatusCodes.RESOLUTION_REQUIRED:
              try {
                ResolvableApiException resolvableApiException = (ResolvableApiException)e;
                resolvableApiException.startResolutionForResult(activity,REQUEST_CHECK_SETTINGS);
              } catch (IntentSender.SendIntentException ex) {
                ex.printStackTrace();
              }
              break;
            case LocationSettingsStatusCodes.SETTINGS_CHANGE_UNAVAILABLE:
              //Device does not have location
              break;
          }
        }
      }
    });
  }
  

  private void bluetoothScanning(){
    IntentFilter filter = new IntentFilter();
    checkPermission();
    String finalString = "";
    devices = new ArrayList<>();
    pairedDevices = mBluetoothAdapter.getBondedDevices();
    if(pairedDevices.size() > 0){
      for (BluetoothDevice bt : pairedDevices) {
        System.out.println("ID: " + bt.getBluetoothClass().getDeviceClass());
        if(bt.getBluetoothClass().getDeviceClass() == 1664){
          devices.add(new DevicesModel(bt.getName(), bt.getAddress()));
        }
      }
      if(devices.size()>0){
        for(int i=0;i<devices.size();i++){
          finalString = finalString + devices.get(i).toDescription() + "&";
        }
        finalString = finalString.substring(0, finalString.length() - 1);
        System.out.println("Device 2: " + finalString);
        globalChannelResult.success(finalString);
      }else{
        filter.addAction(BluetoothDevice.ACTION_FOUND);
        filter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
        context.registerReceiver(receiver, filter);
      }
    }
  }


  public void checkPermission() {
    if (Build.VERSION.SDK_INT >= 23) {
      if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED && context.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
        mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        mBluetoothAdapter.startDiscovery();
      } else {
        ActivityCompat.requestPermissions(activity, new String[]{
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,}, 1);
      }
    }
  }

  @Override
  public boolean onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
    if (requestCode == REQUEST_FINE_LOCATION_PERMISSIONS) {
      if (requestCode == 1 && grantResults[0] == PackageManager.PERMISSION_GRANTED && grantResults[1] == PackageManager.PERMISSION_GRANTED) {
        mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        mBluetoothAdapter.startDiscovery();
      } else {
        checkPermission();
      }
      onRequestPermissionsResult(requestCode, permissions, grantResults);
      return true;
    }
    return false;
  }

  private final BroadcastReceiver receiver = new BroadcastReceiver() {
    public void onReceive(Context context, Intent intent) {
      String action = intent.getAction();
      if (BluetoothDevice.ACTION_FOUND.equals(action)) {
        BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
        if(devices.size()!=0){
          boolean check = false;
          for (int i=0;i<devices.size();i++){
            if(devices.get(i).getDeviceAddress().equals(device.getAddress())){
              check = true;
              return;
            }
          }
          if(!check && device.getBluetoothClass().getDeviceClass() == 1664){
            devices.add(new DevicesModel(device.getName(),device.getAddress()));
            System.out.println("Printer: " + device.getName() + " | "+ device.getAddress() + " | " + device.getUuids() + " | " + device.getBluetoothClass().getDeviceClass());
          }
        }else{
          if(device.getBluetoothClass().getDeviceClass() == 1664){
            devices.add(new DevicesModel(device.getName(),device.getAddress()));
          }
        }
      }
      else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(action)) {
        String finalString = "";
        if(devices.size() > 0){
          for (int i=0;i<devices.size();i++){
            finalString = finalString + devices.get(i).toDescription() + "&";
          }
          finalString = finalString.substring(0, finalString.length() - 1);
          System.out.println("Device 3: " + finalString);
          globalChannelResult.success(finalString);
          context.unregisterReceiver(receiver);
        }else{
          System.out.println("Khong co may in !!!");
          globalChannelResult.success(finalString);
          context.unregisterReceiver(receiver);
        }
      }
    }
  };

}

class DevicesModel{
  //  val id: String?, val deviceName: String?, val deviceAddress: String?
  String id;

  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
  }

  public String getDeviceName() {
    return deviceName;
  }

  public void setDeviceName(String deviceName) {
    this.deviceName = deviceName;
  }

  public String getDeviceAddress() {
    return deviceAddress;
  }

  public void setDeviceAddress(String deviceAddress) {
    this.deviceAddress = deviceAddress;
  }


  String deviceName;
  String deviceAddress;


  DevicesModel(String deviceName, String deviceAddress){
    this.deviceName = deviceName;
    this.deviceAddress = deviceAddress;
  }
  String toDescription(){
    return deviceName + "|" + deviceAddress;
  }
}
