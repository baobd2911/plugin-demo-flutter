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
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;

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
import com.google.android.gms.tasks.Task;


import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
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
  private MethodChannel _channel;
  private MethodChannel channelConnect;
  private MethodChannel channelPrint;
  private EventChannel stateChannel;
  private static final int REQUEST_CHECK_SETTINGS = 10001;
  private BluetoothAdapter mBluetoothAdapter;
  Set<BluetoothDevice> pairedDevices;
  public static final int PERMISSION_BLUETOOTH = 1;
  private final Object initializationLock = new Object();
  private MethodChannel.Result globalChannelResult;
  private ThreadPool threadPool;
  private static final String ACTION_NEW_DEVICE = "action_new_device";
  private static final String ACTION_NO_PRINTER = "action_no_printer";
  private boolean checkDevice = false;
  private static final int REQUEST_FINE_LOCATION_PERMISSIONS = 1452;


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
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }
  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    checkPermission();
    globalChannelResult = result;
    try {
      Map<String, Object> arguments = call.arguments();
      System.out.println("NHACVO_DEMO: "+ call.method);
      if (call.method.toString().equals("getPlatformVersion")) {
        result.success("Android ${android.os.Build.VERSION.RELEASE}");
      } else  if (call.method.equals("getMessage")) {
        String message = "Android say hi!";
        result.success(message);
      } else if (call.method.equals("onPrint")) {
        System.out.println("I am here onPrint");
        byte[] bitmapInput = (byte[]) arguments.get("bitmapInput");
        int printerDpi = (int) arguments.get("printerDpi");
        int heightMax = (int) arguments.get("heightMax");
        int widthMax = (int) arguments.get("widthMax");
        int countPage = (int) arguments.get("countPage");
        Map<String, Object> arrStatus = onPrint(bitmapInput, printerDpi, widthMax, heightMax, countPage);
        result.success(arrStatus);
      }else if (call.method.equals("onBluetooth")) {
        turnOnBluetooth();
      }else if (call.method.equals("offBluetooth")) {
        turnOffBluetooth();
      }
      else if (call.method.equals("scanDevice")) {
        scanDevice(result);
      }
      else if (call.method.equals("connectDevice")) {
        connect(result,arguments);
      }
      else if (call.method.equals("stateBluetooth")) {
        state(result);
      }
      else if (call.method.equals("isConnected")) {
        result.success(threadPool != null);
      }
    } catch (Exception e) {
      result.error("500", "Server Error", e.getMessage());
    }
  }


  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channelPrint.setMethodCallHandler(null);
    channel.setMethodCallHandler(null);
    _channel.setMethodCallHandler(null);
    channelConnect.setMethodCallHandler(null);
    pluginBinding = null;

  }


  public ClvNhacvoPrintPlugin(){
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    setup(
            pluginBinding.getBinaryMessenger(),
            (Application) pluginBinding.getApplicationContext(),
            activityBinding.getActivity(),
            null,
            activityBinding);
    FlutterEngine flutterEngine = new FlutterEngine(application);
  }

  @Override
  public void onDetachedFromActivity() {
    Log.i(TAG, "onDetachedFromActivity");
    context = null;
    activityBinding.removeRequestPermissionsResultListener(this);
    activityBinding = null;
    channel.setMethodCallHandler(null);
    _channel.setMethodCallHandler(null);
    channelPrint.setMethodCallHandler(null);
    channelConnect.setMethodCallHandler(null);
    stateChannel.setStreamHandler(null);
    channel = null;
    _channel = null;
    channelPrint = null;
    channelConnect = null;
    stateChannel = null;
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
      _channel = new MethodChannel(messenger, "flutter_scan_bluetooth");
      channelPrint = new MethodChannel(messenger, "com.clv.demo/print");
      channelConnect = new MethodChannel(messenger, "com.clv.demo/connect");
      stateChannel = new EventChannel(messenger, "com.clv.demo/stateBluetooth");
      stateChannel.setStreamHandler(stateHandler);
      channel.setMethodCallHandler(this);
      _channel.setMethodCallHandler(this);
      channelPrint.setMethodCallHandler(this);
      channelConnect.setMethodCallHandler(this);
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



  private Map<String, Object> onPrint(
          byte[] bitmapInput,
          int printerDpi ,
          int heightMax ,
          int widthMax,
          int countPage){
    Map<String, Object>  dataMap = new HashMap<>();
    String _message = "";
    for(int i = 0 ; i < 3 ; i++){
      try {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) != PackageManager.PERMISSION_GRANTED) {
          ActivityCompat.requestPermissions( activityBinding.getActivity(), new String[]{Manifest.permission.BLUETOOTH}, PERMISSION_BLUETOOTH);
        } else {
          BluetoothConnection connection = BluetoothPrintersConnections.selectFirstPaired();
          if (connection != null) {
            EscPosPrinter printer = new EscPosPrinter(connection, printerDpi, 80f, 32);

            Bitmap decodedByte = BitmapFactory.decodeByteArray(bitmapInput, 0, bitmapInput.length);
            double widthSreenshot = decodedByte.getWidth();
            double heightSreenshot = decodedByte.getHeight();
            System.out.println(widthSreenshot);
            System.out.println(heightSreenshot);
            double widthTemp = 570;
            double heightTemp = 570.0/(widthSreenshot/heightSreenshot);
            System.out.println(widthTemp);
            System.out.println(heightTemp);

            System.out.println( "-----------------Start--------------------");
            System.out.println( "Input:  " + widthMax + " || " + heightMax);
            System.out.println( "Current:  " + (int)widthTemp + " || " + (int)heightTemp);
            System.out.println( "------------------End---------------------");

            Bitmap resizedBitmap = Bitmap.createScaledBitmap(decodedByte, (int)widthTemp, (int)heightTemp, false);
            decodedByte.recycle();
            int width = resizedBitmap.getWidth();
            int height = resizedBitmap.getHeight();

            StringBuilder textToPrint = new StringBuilder();
            for(int y = 0; y < height; y += 256) {
              Bitmap bitmap = Bitmap.createBitmap(resizedBitmap, 0, y, width, (y + 256 >= height) ? height - y : 256);
              textToPrint.append("[C]<img>" + PrinterTextParserImg.bitmapToHexadecimalString(printer, bitmap) + "</img>\n");
            }
            printer.printFormattedTextAndCut(textToPrint.toString());
            _message = "Success !!!";
            break;
          } else {
            // println("\"No printer was connected!\"");
            _message = "No printer was connected !!!";
//          onPrint(bitmapInput, printerDpi, widthMax, heightMax, callback, countPage);
          }
        }
      }
      catch (Exception e) {
        _message = "Error";
      }
    }
    dataMap.put("message",_message);
    return dataMap;
  }

  // Check if permissions have been granted
  public void checkPermission() {
    if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED && context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
      mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
      mBluetoothAdapter.startDiscovery();
    } else {
      ActivityCompat.requestPermissions(activity, new String[]{
              Manifest.permission.ACCESS_FINE_LOCATION,
              Manifest.permission.ACCESS_COARSE_LOCATION,}, 1);
    }
  }

  // Permission must be granted
  @Override
  public boolean onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
    if (requestCode == REQUEST_FINE_LOCATION_PERMISSIONS) {
      checkPermission();
      return true;
    }
    return false;
  }

  private void turnOnBluetooth (){
    LocationManager manager = (LocationManager) context.getSystemService( Context.LOCATION_SERVICE );
    if (!manager.isProviderEnabled( LocationManager.GPS_PROVIDER ) ) {
      turnOnGPS();
      IntentFilter filter = new IntentFilter();
      filter.addAction(LocationManager.PROVIDERS_CHANGED_ACTION);
      context.registerReceiver(mReceiverGpsChanged, filter);
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
            context.registerReceiver(mReceiverBluetoothChanged, filter);
          }
        }
      }catch (Exception ex){
        System.out.println(ex.getMessage());
      }
    }
  }


  // If Gps switches off to on, it will turn on bluetooth
  private final BroadcastReceiver mReceiverGpsChanged = new BroadcastReceiver() {
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
              context.unregisterReceiver(mReceiverGpsChanged);
              IntentFilter filter = new IntentFilter();
              filter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
              context.registerReceiver(mReceiverBluetoothChanged, filter);
            }
          }
        }catch (Exception ex){
          System.out.println(ex.getMessage());
        }
      }
    }
  };

  // check if bluetooth is on then send message "scan" to flutter
  private final BroadcastReceiver mReceiverBluetoothChanged = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
      final String action = intent.getAction();

      if (action.equals(BluetoothAdapter.ACTION_STATE_CHANGED) && mBluetoothAdapter.isEnabled()) {
        globalChannelResult.success("scan");
        context.unregisterReceiver(mReceiverBluetoothChanged);
      }
    }
  };

  private void turnOffBluetooth (){
    try {
      mBluetoothAdapter.disable();
      Toast.makeText(context,"Bluetooth Turned OFF", Toast.LENGTH_SHORT).show();
    }catch (Exception ex){
      System.out.println(ex.getMessage());
    }
  }

  private void turnOnGPS(){
    LocationRequest locationRequest = LocationRequest.create();
    locationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
    locationRequest.setInterval(5000);
    locationRequest.setFastestInterval(2000);

    LocationSettingsRequest.Builder builder = new LocationSettingsRequest.Builder()
            .addLocationRequest(locationRequest);
    builder.setAlwaysShow(true);

    Task<LocationSettingsResponse> result = LocationServices.getSettingsClient(context.getApplicationContext())
            .checkLocationSettings(builder.build());

    result.addOnCompleteListener(task -> {
      try {
        task.getResult(ApiException.class);
        Toast.makeText(context, "GPS is already turned on", Toast.LENGTH_SHORT).show();
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
    });
  }

  // Scan devices recent
  private final BroadcastReceiver mReceiverScanDevice = new BroadcastReceiver() {
    public void onReceive(Context context, Intent intent) {
      String action = intent.getAction();
      BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
      if (BluetoothDevice.ACTION_FOUND.equals(action)) {
        if(device != null){
          if(device.getBluetoothClass().getDeviceClass() == 1664){
            _channel.invokeMethod(ACTION_NEW_DEVICE,toMap(device));
            checkDevice = true;
          }
        }
      }else if(BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(action)){
        if(!checkDevice){
          _channel.invokeMethod(ACTION_NO_PRINTER,null);
        }
        checkDevice = false;
        context.unregisterReceiver(mReceiverScanDevice);
      }
    }
  };

  // save name and address to map
  private Map<String, String> toMap(BluetoothDevice device) {
    Map<String, String> map = new HashMap<>();
    String name = device.getName();
    String address = device.getAddress();
    map.put("name", name);
    map.put("address",address);
    return map;
  }

  // scan devices recent and devices paired
  private void scanDevice(Result result) {
    if(!mBluetoothAdapter.isDiscovering()){
      mBluetoothAdapter.cancelDiscovery();
    }
    mBluetoothAdapter.startDiscovery();

    IntentFilter filter = new IntentFilter();
    filter.addAction(BluetoothDevice.ACTION_FOUND);
    filter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
    context.registerReceiver(mReceiverScanDevice, filter);

    pairedDevices = mBluetoothAdapter.getBondedDevices();
    List<Map<String,String>> mapList = new ArrayList<>();
    for (BluetoothDevice bt : pairedDevices) {
      if(bt.getBluetoothClass().getDeviceClass() == 1664){
        Map<String, String> map = new HashMap<>();
        map.put("name", bt.getName());
        map.put("address",bt.getAddress());
        mapList.add(map);
        toMap(bt);
        System.out.println(bt);
      }
    }
    result.success(mapList);
  }

  // connect to device
  private void connect(final Result result, Map<String, Object> args) {
    if (args.containsKey("address")) {
      String address = (String) args.get("address");
      BluetoothDevice device;
      device = mBluetoothAdapter.getRemoteDevice(address);
      BluetoothConnection connection = new BluetoothConnection(device);
      try {
        connection.connect();
      }catch (Exception e){
        Log.d(TAG, "connect: " + e);
      }
      boolean checkState = connection.isCheck();
      if(checkState){
        result.success(true);
      }else{
        result.success(false);
      }
    }
  }

  // state bluetooth
  private void state(Result result){
    try {
      switch(mBluetoothAdapter.getState()) {
        case BluetoothAdapter.STATE_OFF:
          result.success(BluetoothAdapter.STATE_OFF);
          break;
        case BluetoothAdapter.STATE_ON:
          result.success(BluetoothAdapter.STATE_ON);
          break;
        case BluetoothAdapter.STATE_TURNING_OFF:
          result.success(BluetoothAdapter.STATE_TURNING_OFF);
          break;
        case BluetoothAdapter.STATE_TURNING_ON:
          result.success(BluetoothAdapter.STATE_TURNING_ON);
          break;
        default:
          result.success(0);
          break;
      }
    } catch (SecurityException e) {
      result.error("invalid_argument", "argument 'address' not found", null);
    }

  }

  // catch event when bluetooth changed
  private final StreamHandler stateHandler = new StreamHandler() {
    private EventSink sink;

    private final BroadcastReceiver mReceiverState = new BroadcastReceiver() {
      @Override
      public void onReceive(Context context, Intent intent) {
        final String action = intent.getAction();
        Log.d(TAG, "stateStreamHandler, current action: " + action);

        if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action)) {
          threadPool = null;
          sink.success(intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1));
        } else if (BluetoothDevice.ACTION_ACL_CONNECTED.equals(action)) {
          sink.success(1);
        } else if (BluetoothDevice.ACTION_ACL_DISCONNECTED.equals(action)) {
          threadPool = null;
          sink.success(0);
        }
      }
    };

    @Override
    public void onListen(Object o, EventSink eventSink) {
      sink = eventSink;
      IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
      filter.addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED);
      filter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
      filter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
      context.registerReceiver(mReceiverState, filter);
    }

    @Override
    public void onCancel(Object o) {
      sink = null;
      context.unregisterReceiver(mReceiverState);
    }
  };

}

