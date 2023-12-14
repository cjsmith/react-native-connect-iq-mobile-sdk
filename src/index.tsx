import { NativeModules, Platform, NativeEventEmitter } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-connect-iq-mobile-sdk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const ConnectIqMobileSdk = NativeModules.ConnectIqMobileSdk
  ? NativeModules.ConnectIqMobileSdk
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export type CIQDevice = {
  deviceIdentifier: string;
  friendlyName: string;
  status: CIQDeviceStatus;
};

export type CIQAppInfo = {
  status: string;
  version: string;
  displayName: string;
};

export type CIQDeviceStatusChangedEvent = {
  deviceId: string;
  status: CIQDeviceStatus;
};

export enum CIQDeviceStatus {
  NOT_PAIRED = 'NOT_PAIRED',
  NOT_CONNECTED = 'NOT_CONNECTED',
  CONNECTED = 'CONNECTED',
  UNKNOWN = 'UNKNOWN',
}

export enum CIQMessageStatus {
  SUCCESS = 'SUCCESS',
  FAILURE_UNKNOWN = 'FAILURE_UNKNOWN',
  FAILURE_INVALID_FORMAT = 'FAILURE_INVALID_FORMAT',
  FAILURE_MESSAGE_TOO_LARGE = 'FAILURE_MESSAGE_TOO_LARGE',
  FAILURE_UNSUPPORTED_TYPE = 'FAILURE_UNSUPPORTED_TYPE',
  FAILURE_DURING_TRANSFER = 'FAILURE_DURING_TRANSFER',
  FAILURE_INVALID_DEVICE = 'FAILURE_INVALID_DEVICE',
  FAILURE_DEVICE_NOT_CONNECTED = 'FAILURE_DEVICE_NOT_CONNECTED',
}

export enum CIQNativeEvent {
  MESSAGE_RECEIVED = 'messageReceived',
  DEVICE_STATUS_CHANGED = 'deviceStatusChanged',
}

export type CIQMessage = {
  message: any;
  status: CIQMessageStatus;
  appId: string;
};

const ConnectIqMobileSdkEventEmitter = new NativeEventEmitter(
  ConnectIqMobileSdk
);

export function init(options: {
  urlScheme: string;
  storeId?: string;
}): Promise<void> {
  const { urlScheme, storeId } = options;
  return ConnectIqMobileSdk.init(storeId, urlScheme);
}

export function getConnectedDevices(): Promise<CIQDevice[]> {
  return ConnectIqMobileSdk.getConnectedDevices();
}

export function getKnownDevices(): Promise<CIQDevice[]> {
  return ConnectIqMobileSdk.getKnownDevices();
}

export function setDevice(device: CIQDevice): Promise<void> {
  console.log('calling setDevice with ' + device.deviceIdentifier);
  return ConnectIqMobileSdk.setDevice(device);
}

export function openStore(appId: string): Promise<void> {
  return ConnectIqMobileSdk.openStore(appId);
}

export function addMessageRecievedListener(
  onMessageReceived: (message: CIQMessage) => void
) {
  ConnectIqMobileSdkEventEmitter.removeAllListeners(
    CIQNativeEvent.MESSAGE_RECEIVED
  );
  ConnectIqMobileSdkEventEmitter.addListener(
    CIQNativeEvent.MESSAGE_RECEIVED,
    onMessageReceived
  );
}

export function addDeviceStatusChangedListener(
  onDeviceStatusChanged: (
    deviceStatusChangedEvent: CIQDeviceStatusChangedEvent
  ) => void
) {
  ConnectIqMobileSdkEventEmitter.removeAllListeners(
    CIQNativeEvent.DEVICE_STATUS_CHANGED
  );
  ConnectIqMobileSdkEventEmitter.addListener(
    CIQNativeEvent.DEVICE_STATUS_CHANGED,
    onDeviceStatusChanged
  );
}

export function getApplicationInfo(appId: string): Promise<CIQAppInfo> {
  return ConnectIqMobileSdk.getApplicationInfo(appId);
}

export function registerForAppMessages(appId: string): Promise<void> {
  return ConnectIqMobileSdk.registerForAppMessages(appId);
}

export function sendMessage(
  message: string | object,
  appId: string
): Promise<string> {
  if (typeof message === 'string') {
    return ConnectIqMobileSdk.sendMessage(message, appId);
  } else {
    return ConnectIqMobileSdk.sendMessageDictionary(message, appId);
  }
}
