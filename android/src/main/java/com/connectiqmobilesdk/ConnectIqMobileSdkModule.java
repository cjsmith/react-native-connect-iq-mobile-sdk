package com.connectiqmobilesdk;

import android.content.Context;
import android.os.Build;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;

import com.garmin.android.connectiq.ConnectIQ;
import com.garmin.android.connectiq.ConnectIQ.ConnectIQListener;
import com.garmin.android.connectiq.ConnectIQ.IQApplicationEventListener;
import com.garmin.android.connectiq.ConnectIQ.IQApplicationInfoListener;
import com.garmin.android.connectiq.ConnectIQ.IQConnectType;
import com.garmin.android.connectiq.ConnectIQ.IQDeviceEventListener;
import com.garmin.android.connectiq.ConnectIQ.IQMessageStatus;
import com.garmin.android.connectiq.ConnectIQ.IQSdkErrorStatus;
import com.garmin.android.connectiq.ConnectIQ.IQSendMessageListener;
import com.garmin.android.connectiq.IQApp;
import com.garmin.android.connectiq.IQDevice;
import com.garmin.android.connectiq.IQDevice.IQDeviceStatus;
import com.garmin.android.connectiq.exception.InvalidStateException;
import com.garmin.android.connectiq.exception.ServiceUnavailableException;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@ReactModule(name = ConnectIqMobileSdkModule.NAME)
public class ConnectIqMobileSdkModule extends ReactContextBaseJavaModule implements IQDeviceEventListener, IQApplicationEventListener, IQSendMessageListener {
  public static final String NAME = "ConnectIqMobileSdk";

  // Connect IQ variables
  private boolean mSdkReady;
  private ConnectIQ mConnectIQ;
  private IQDevice mDevice;
  private IQApp mMyApp;
  private String mStoreId;

  private String mAppId;
  private Promise messageStatusPromise;

  public ConnectIqMobileSdkModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  private int listenerCount = 0;

  @ReactMethod
  public void addListener(String eventName) {
    if (listenerCount == 0) {
      // Set up any upstream listeners or background tasks as necessary
    }
    listenerCount += 1;
  }

  @ReactMethod
  public void removeListeners(Integer count) {
    listenerCount -= count;
    if (listenerCount == 0) {
      // Remove upstream listeners, stop unnecessary background tasks
    }
  }

  // Example method
  // See https://reactnative.dev/docs/native-modules-android
  @ReactMethod
  public void init(String appId, String storeId, String urlScheme/*only used on iOS*/, Promise promise) {
    System.out.println("Calling init with " + appId);
    mMyApp = new IQApp(appId);
    mStoreId = storeId;
    Context context = this.getCurrentActivity().getWindow().getContext();
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      if (context.isUiContext()) {
        mConnectIQ = ConnectIQ.getInstance(context, IQConnectType.WIRELESS);
        mConnectIQ.initialize(context, true, new ConnectIQListener() {
          @Override
          public void onSdkReady() {
            promise.resolve(null);
          }

          @Override
          public void onInitializeError(IQSdkErrorStatus iqSdkErrorStatus) {
            promise.reject(new Exception(iqSdkErrorStatus.name()));
          }

          @Override
          public void onSdkShutDown() {
            mConnectIQ = null;
          }
        });
        promise.resolve(null);
      } else {
        promise.reject(new Exception("init must be called after UI has rendered"));
      }
    } else {
      promise.reject(new Exception("Requires Android API version >= 31"));
    }
  }

  @ReactMethod
  public void setDevice(String deviceId, Promise promise) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      try {
        List<IQDevice> knownDevices = mConnectIQ.getKnownDevices();
        Optional<IQDevice> optionalDevice = knownDevices.stream().filter(device -> device.getDeviceIdentifier() == Long.valueOf(deviceId)).findFirst();
        if (optionalDevice.isPresent()) {
          mDevice = optionalDevice.get();
          mConnectIQ.registerForDeviceEvents(mDevice, this);
        } else {
          promise.reject(new Exception("No matching device with device id" + deviceId));
        }
        promise.resolve(null);
      } catch (Exception e) {
        promise.reject(e);
      }
    } else {
      promise.reject(new Exception("Requires Android API version >= 24"));
    }
  }



  @ReactMethod
  public void getConnectedDevices(Promise promise) {
    try {
      List<IQDevice> connectedDevices = mConnectIQ.getConnectedDevices();
      WritableArray connectedDevicesNativeArray = getDevicesAsNativeArray(connectedDevices);
      promise.resolve(connectedDevicesNativeArray);
    } catch(Exception e) {
      promise.reject(e);
    }
  }

  @ReactMethod
  public void getKnownDevices(Promise promise) {
    try {
      List<IQDevice> connectedDevices = mConnectIQ.getKnownDevices();
      WritableArray connectedDevicesNativeArray = getDevicesAsNativeArray(connectedDevices);
      promise.resolve(connectedDevicesNativeArray);
    } catch(Exception e) {
      promise.reject(e);
    }
  }

  @ReactMethod
  public void getApplicationInfo(Promise promise) {

    IQApplicationEventListener eventListener = this;
    try {
      mConnectIQ.getApplicationInfo(mAppId, mDevice, new IQApplicationInfoListener() {
        @Override
        public void onApplicationInfoReceived( IQApp app ) {
          if (app != null) {
            mMyApp = app;
            try {
              mConnectIQ.registerForAppEvents(mDevice, mMyApp, eventListener);
            } catch (Exception e) {
              promise.reject(new Exception("no app to get app info from"));
              return;
            }
            WritableNativeMap appInfo = new WritableNativeMap();
            appInfo.putString("status", app.getStatus().name());
            appInfo.putString("version", String.valueOf(app.version()));
            appInfo.putString("displayName", app.getDisplayName());
            promise.resolve(appInfo);
          } else {
            promise.reject(new Exception("no app to get app info from"));
          }
        }

        @Override
        public void onApplicationNotInstalled(String applicationId) {
          promise.reject(new Exception("Connect IQ application with appId " + appId + " not installed on device with deviceId " + mDevice.getDeviceIdentifier()));
        }
      });
    } catch (Exception e) {
      promise.reject(e);
    }
  }

  @NonNull
  private static WritableArray getDevicesAsNativeArray(List<IQDevice> connectedDevices) {
    WritableArray connectedDevicesNativeArray = new WritableNativeArray();
    for (IQDevice device : connectedDevices) {
      WritableNativeMap deviceMap = new WritableNativeMap();
      deviceMap.putString("deviceIdentifier", String.valueOf(device.getDeviceIdentifier()));
      deviceMap.putString("friendlyName", device.getFriendlyName());
      deviceMap.putString("status", device.getStatus().name());
      connectedDevicesNativeArray.pushMap(deviceMap);
    }
    return connectedDevicesNativeArray;
  }

  @ReactMethod
  public void openStore(Promise promise) {
    try {
      mConnectIQ.openStore(mStoreId);
      promise.resolve(null);
    } catch (Exception e) {
      promise.reject(e);
    }
  }

  @ReactMethod
  public void sendMessage(String message, Promise promise) {
    try {
      if (mDevice != null) {
        messageStatusPromise = promise;
        mConnectIQ.sendMessage(mDevice, mMyApp, message, this);
      } else {
        promise.reject(new Exception("No device connected"));
      }
    } catch (Exception e) {
      promise.reject(e);
    }
  }
  @Override
  public void onMessageReceived(IQDevice iqDevice, IQApp iqApp, List<Object> list, IQMessageStatus iqMessageStatus) {
    WritableNativeMap messageReceivedEvent = new WritableNativeMap();
    WritableNativeArray messageList = new WritableNativeArray();

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      // flatten all messages to a string
      String message =  list.stream().map((item) -> { return item.toString(); }). collect(Collectors.joining());
      messageReceivedEvent.putString("message", message);
      messageReceivedEvent.putString("status", iqMessageStatus.name());
      this.getReactApplicationContext().emitDeviceEvent("messageReceived", messageReceivedEvent);
    }
  }

  @Override
  public void onDeviceStatusChanged(IQDevice iqDevice, IQDeviceStatus iqDeviceStatus) {
    WritableNativeMap deviceStatusEvent = new WritableNativeMap();

    deviceStatusEvent.putString("deviceId", String.valueOf(iqDevice.getDeviceIdentifier()));
    deviceStatusEvent.putString("status", iqDeviceStatus.name());

    this.getReactApplicationContext().emitDeviceEvent("deviceStatusChanged", deviceStatusEvent);
  }

  @Override
  public void onMessageStatus(IQDevice iqDevice, IQApp iqApp, IQMessageStatus iqMessageStatus) {
    if (messageStatusPromise != null) {
      messageStatusPromise.resolve(iqMessageStatus.name());
      messageStatusPromise = null;
    } else {
      System.out.println("Unexpected message status:" + iqMessageStatus.name());
    }
  }
}
