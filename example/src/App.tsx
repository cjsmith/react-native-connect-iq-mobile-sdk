import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, Button, TextInput, ScrollView } from 'react-native';
import {
  init,
  getConnectedDevices,
  getKnownDevices,
  setDevice,
  sendMessage,
  getApplicationInfo,
  type CIQAppInfo,
  type CIQDevice,
  addMessageRecievedListener,
  type CIQMessage,
  addDeviceStatusChangedListener,
  type CIQDeviceStatusChangedEvent,
  openStore,
  registerForAppMessages,
} from 'react-native-connect-iq-mobile-sdk';

const APP_ID = 'c815f36d-d28a-464f-bc23-12190792a2be';
const STORE_ID = 'c815f36d-d28a-464f-bc23-12190792a2be';
const URL_SCHEME = 'ciqsdkexample-12345';

const isJson = (str: string) => {
  try {
    JSON.parse(str);
  } catch (e) {
    return false;
  }
  return true;
};

export default function App() {
  const [initResult, setInitResult] = useState<string | undefined>();
  const [getConnectedDevicesResult, setGetConnectedDevicesResult] = useState<
    string | undefined
  >();
  const [getKnownDevicesResult, setGetKnownDevicesResult] = useState<
    string | undefined
  >();
  const [sendMessageResult, setSendMessageResult] = useState<
    string | undefined
  >();
  const [setDeviceResult, setSetDeviceResult] = useState<string | undefined>();
  const [getApplicationInfoResult, setGetApplicationInfoResult] = useState<
    string | undefined
  >();
  const [registerForAppMessagesResult, setRegisterForAppMessagesResult] =
    useState<string | undefined>();
  const [openStoreResult, setOpenStoreResult] = useState<string | undefined>();
  const [devices, setDevices] = useState<CIQDevice[]>([]);
  const [currentDevice, setCurrentDevice] = useState<CIQDevice | undefined>(
    undefined
  );
  const [storeId, setStoreId] = useState<string>('');
  const [message, setMessage] = useState<string>('');
  const [receivedMessage, setReceivedMessage] = useState<string>('');
  const [deviceStatus, setDeviceStatus] = useState<string>('');

  const callInit = () => {
    setInitResult('');
    init({
      storeId: STORE_ID,
      urlScheme: URL_SCHEME,
    })
      .then(() => {
        setInitResult('initialized');
      })
      .catch((e) => {
        setInitResult(`failed: ${e}`);
      });
  };

  const callGetConnectedDevices = () => {
    setGetConnectedDevicesResult('');
    getConnectedDevices()
      .then((connectedDevices: CIQDevice[]) => {
        setGetConnectedDevicesResult(
          `got connected devices: ${JSON.stringify(connectedDevices)}`
        );
        setDevices(connectedDevices);
      })
      .catch((e: any) => {
        setGetConnectedDevicesResult(`failed: ${e}`);
      });
  };

  const callGetKnownDevices = () => {
    setGetKnownDevicesResult('');
    getKnownDevices()
      .then((knownDevices: CIQDevice[]) => {
        setGetKnownDevicesResult(
          `got known devices: ${JSON.stringify(knownDevices)}`
        );
        setDevices(knownDevices);
      })
      .catch((e: any) => {
        setGetKnownDevicesResult(`failed: ${e}`);
      });
  };

  const callGetApplicationInfo = () => {
    setGetApplicationInfoResult('');
    getApplicationInfo(APP_ID)
      .then((applicationInfo: CIQAppInfo) => {
        setGetApplicationInfoResult(
          `got app info: ${JSON.stringify(applicationInfo)}`
        );
      })
      .catch((e: any) => {
        setGetApplicationInfoResult(`failed: ${e}`);
      });
  };

  const callOpenStore = () => {
    setOpenStoreResult('');
    openStore(APP_ID)
      .then(() => {
        setOpenStoreResult('open store succeeded');
      })
      .catch((e: any) => {
        setOpenStoreResult(`failed: ${e}`);
      });
  };

  const callRegisterForAppMessages = () => {
    setRegisterForAppMessagesResult('');
    registerForAppMessages(APP_ID)
      .then(() => {
        setRegisterForAppMessagesResult('register for app messages succeeded');
      })
      .catch((e: any) => {
        setRegisterForAppMessagesResult(`failed: ${e}`);
      });
  };

  const callSetDevice = (device: CIQDevice) => {
    setCurrentDevice(device);
    setSetDeviceResult('');
    setDevice(device)
      .then(() => {
        setSetDeviceResult(`set device succeeded`);
      })
      .catch((e: any) => {
        setSetDeviceResult(`failed: ${e}`);
      });
  };

  const populateJsonMessage = () => {
    setMessage(
      // eslint-disable-next-line prettier/prettier
      JSON.stringify({ string_field: "hello world", number_field: 1234 }),
    );
  };
  const callSendMessage = () => {
    setSendMessageResult('');
    const messageObj = isJson(message) ? JSON.parse(message) : message;
    sendMessage(messageObj, APP_ID)
      .then((status) => {
        setSendMessageResult(`send message succeeded ${status}`);
        setMessage('');
      })
      .catch((e: any) => {
        setSendMessageResult(`failed: ${e}`);
      });
  };

  useEffect(() => {
    callInit();
    addMessageRecievedListener((messageEvent: CIQMessage) => {
      setReceivedMessage(JSON.stringify(messageEvent));
    });
    addDeviceStatusChangedListener(
      (changedDeviceStatus: CIQDeviceStatusChangedEvent) => {
        setDeviceStatus(JSON.stringify(changedDeviceStatus));
      }
    );
  }, []);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Button title="Call Init" onPress={callInit} />
      {initResult ? <Text>Result: {initResult}</Text> : null}
      <Button
        title="Call Get Connected Devices"
        onPress={callGetConnectedDevices}
      />
      {getConnectedDevicesResult ? (
        <Text>Result: {getConnectedDevicesResult}</Text>
      ) : null}
      <Button title="Call Get Known Devices" onPress={callGetKnownDevices} />
      {getKnownDevicesResult ? (
        <Text>Result: {getKnownDevicesResult}</Text>
      ) : null}
      <Text>Devices:</Text>
      {devices.map((device: CIQDevice) => (
        <Button
          key={device.deviceIdentifier}
          title={`Use ${device.friendlyName}(${device.deviceIdentifier})`}
          onPress={() => {
            callSetDevice(device);
          }}
        />
      ))}
      {setDeviceResult ? <Text>Result: {setDeviceResult}</Text> : null}
      <Button
        title="Call Get Application Info"
        disabled={!currentDevice}
        onPress={callGetApplicationInfo}
      />
      {getApplicationInfoResult ? (
        <Text>Result: {getApplicationInfoResult}</Text>
      ) : null}
      <Button
        title="Register Message Events"
        disabled={!currentDevice}
        onPress={callRegisterForAppMessages}
      />
      {registerForAppMessagesResult ? (
        <Text>Result: {registerForAppMessagesResult}</Text>
      ) : null}
      <Text>Message</Text>
      <TextInput
        style={styles.textInput}
        value={message}
        onChangeText={setMessage}
      />
      <Button title="Use JSON message" onPress={populateJsonMessage} />
      <Button title="Send Message" onPress={callSendMessage} />
      {sendMessageResult ? <Text>Result: {sendMessageResult}</Text> : null}
      <Text>Message Received:</Text>
      <Text>{receivedMessage}</Text>
      <Text>Device Status:</Text>
      <Text>{deviceStatus}</Text>
      <Text>Store Id</Text>
      <TextInput
        style={styles.textInput}
        value={storeId}
        onChangeText={setStoreId}
      />
      <Button title="Open Store" onPress={callOpenStore} />
      {openStoreResult ? <Text>Result: {openStoreResult}</Text> : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
  textInput: {
    borderWidth: 1,
    borderColor: 'black',
    width: 300,
  },
});
