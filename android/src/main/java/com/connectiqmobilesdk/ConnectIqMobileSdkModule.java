package com.connectiqmobilesdk;

import android.content.Context;
import android.os.Build;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.JavaOnlyArray;
import com.facebook.react.bridge.JavaOnlyMap;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
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

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@ReactModule(name = ConnectIqMobileSdkModule.NAME)
public class ConnectIqMobileSdkModule extends ReactContextBaseJavaModule implements IQDeviceEventListener, IQApplicationEventListener, IQSendMessageListener {
  public static final String NAME = "ConnectIqMobileSdk";

  // Connect IQ variables
  private boolean mSdkReady;
  private ConnectIQ mConnectIQ;
  private IQDevice mDevice;
  private String mStoreId;
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
  public void init(String storeId, String urlScheme/*only used on iOS*/, Promise promise) {
    System.out.println("Calling init with " + storeId);
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
  public void registerForAppMessages(String appId, Promise promise) {
    try {
      mConnectIQ.registerForAppEvents(mDevice, new IQApp(appId), this);
      promise.resolve(null);
    } catch (Exception e) {
      promise.reject(new Exception("failed to register for app events " + e.getMessage()));
      return;
    }
  }

  @ReactMethod
  public void setDevice(ReadableMap device, Promise promise) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      try {
        mDevice = new IQDevice(Long.parseLong(device.getString("deviceIdentifier")), device.getString("friendlyName"));
        mConnectIQ.registerForDeviceEvents(mDevice, this);

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
  public void getApplicationInfo(String appId, Promise promise) {

    try {
      mConnectIQ.getApplicationInfo(appId, mDevice, new IQApplicationInfoListener() {
        @Override
        public void onApplicationInfoReceived( IQApp app ) {
          if (app != null) {

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
          promise.reject(new Exception("Connect IQ application with appId " + applicationId + " not installed on device with deviceId " + mDevice.getDeviceIdentifier()));
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
  public void openStore(String appId, Promise promise) {
    try {
      mConnectIQ.openStore(appId);
      promise.resolve(null);
    } catch (Exception e) {
      promise.reject(e);
    }
  }

  private void sendMessageInternal(String appId, Object message, Promise promise) {

    try {
      if (mDevice == null) {
        promise.reject(new Exception("No device connected"));
      } else if (appId == null) {
        promise.reject(new Exception("No app set"));
      } else {
        mConnectIQ.sendMessage(mDevice, new IQApp(appId), message, new IQSendMessageListener() {
          @Override
          public void onMessageStatus(IQDevice iqDevice, IQApp iqApp, IQMessageStatus iqMessageStatus) {
            promise.resolve(iqMessageStatus.name());
          }
        });
      }
    } catch (Exception e) {
      promise.reject(e);
    }
  }

    @ReactMethod
  public void sendMessage( String message, String appId, Promise promise) {
      sendMessageInternal(appId, message, promise);
  }

  @ReactMethod
  public void sendMessageDictionary(ReadableMap message, String appId, Promise promise) {
      Map<String, Object> javaMap = message.toHashMap();
      sendMessageInternal(appId, javaMap, promise);
  }

  public ReadableArray convertListToReadableArray(List<Object> list) {
    WritableArray writableArray = Arguments.createArray();

    for (Object value : list) {
      if (value instanceof Boolean) {
        writableArray.pushBoolean((Boolean) value);
      } else if (value instanceof Integer) {
        writableArray.pushInt((Integer) value);
      } else if (value instanceof Float) {
        writableArray.pushDouble(Double.valueOf(((Float) value).floatValue()));
      } else if (value instanceof Double) {
        writableArray.pushDouble((Double) value);
      } else if (value instanceof String) {
        writableArray.pushString((String) value);
      } else if (value instanceof Map) {
        writableArray.pushMap(convertHashMapToReadableMap((HashMap<String, Object>) value));
      } else if (value instanceof List) {
        writableArray.pushArray(convertListToReadableArray((List<Object>) value));
      }
      // ... handle other types as needed
    }

    return writableArray;
  }
  private ReadableMap convertHashMapToReadableMap(Map<String, Object> map) {
    WritableMap writableMap = Arguments.createMap();

    for (Map.Entry<String, Object> entry : map.entrySet()) {
      String key = entry.getKey();
      Object value = entry.getValue();

      // You'll need to check the instance of each value to call the correct put method
      if (value instanceof Boolean) {
        writableMap.putBoolean(key, (Boolean) value);
      } else if (value instanceof Integer) {
        writableMap.putInt(key, (Integer) value);
      } else if (value instanceof Float) {
        writableMap.putDouble(key, Double.valueOf(((Float) value).floatValue()));
      } else if (value instanceof Double) {
        writableMap.putDouble(key, (Double) value);
      } else if (value instanceof String) {
        writableMap.putString(key, (String) value);
      } else if (value instanceof Map) {
        // Recursive call for nested maps
        writableMap.putMap(key, convertHashMapToReadableMap((HashMap<String, Object>) value));
      } else if (value instanceof List) {
        // Convert List to ReadableArray
        writableMap.putArray(key, convertListToReadableArray((List<Object>) value));
      }
      // ... handle other types as needed
    }

    return writableMap;
  }
  public void onMessageReceived(IQDevice iqDevice, IQApp iqApp, List<Object> list, IQMessageStatus iqMessageStatus) {

    WritableNativeMap messageReceivedEvent = new WritableNativeMap();

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      try {
        messageReceivedEvent.putString("status", iqMessageStatus.name());
        messageReceivedEvent.putString("appId", iqApp.getApplicationId());
        if(list.size() > 1) {
          messageReceivedEvent.putArray("message", convertListToReadableArray(list));
        } else if (list.size() == 0){
          messageReceivedEvent.putString("status", "Message array length is zero");
        } else if (list.get(0) instanceof Map) {
          messageReceivedEvent.putMap("message", convertHashMapToReadableMap((Map) list.get(0)));
        } else if (list.get(0) instanceof String) {
          messageReceivedEvent.putString("message", (String) list.get(0));
        } else {
          messageReceivedEvent.putString("status", "Unknown message type " + list.get(0).getClass().getName());
        }
      } catch (Exception e) {
        messageReceivedEvent.putString("status", e.getMessage());
        e.printStackTrace();
      }
    }
    this.getReactApplicationContext().emitDeviceEvent("messageReceived", messageReceivedEvent);
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
