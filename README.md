# react-native-connect-iq-mobile-sdk

This package provides a React Native wrapper around the Android and iOS Garmin Connect IQ Mobile SDKs

## Installation

```sh
npm install react-native-connect-iq-mobile-sdk
```

## Usage

Please see the example project for usage. It provides Android and iOS examples of all functionality in the SDK.

Also see the Garmin docs for background on the functionality.

# iOS

https://developer.garmin.com/connect-iq/core-topics/mobile-sdk-for-ios/

Note the XCode project setup required, which is also required for using this in react native. Please see the iOS example.

In particular, you need to handle the openURL method in your AppDelegate

```objective-c
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSString* sourceApp = options[UIApplicationOpenURLOptionsSourceApplicationKey];
    NSLog(@"Received URL from '%@': %@", sourceApp, url);

   RCTBridge *bridge = [RCTBridge currentBridge];

   ConnectIqMobileSdk * connectIqMobileSdk = [bridge moduleForName:@"ConnectIqMobileSdk"];

   return [connectIqMobileSdk handleOpenURL:url sourceApplication:sourceApp];
}
```

# Android

https://developer.garmin.com/connect-iq/core-topics/mobile-sdk-for-android/

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
