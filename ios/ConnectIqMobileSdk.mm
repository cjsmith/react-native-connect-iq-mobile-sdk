#import "ConnectIqMobileSdk.h"
#import <ConnectIQ/ConnectIQ.h>

NSString * const kDevicesFileName = @"devices";

@interface ConnectIqMobileSdk() <IQDeviceEventDelegate,IQAppMessageDelegate>

@property (nonatomic, readwrite) NSMutableDictionary *devices;
@property (nonatomic, readwrite) IQDevice* device;
@property (nonatomic, readwrite) RCTPromiseResolveBlock connectedDevicesPromise;
@property (nonatomic, readwrite) IQApp* app;
@property (nonatomic, readwrite) NSString* urlScheme;
@property (nonatomic, readwrite) NSUUID* storeId;
@property (nonatomic, readwrite) NSUUID* appId;
@end

@implementation ConnectIqMobileSdk {
    bool hasListeners;
}

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents {
    return @[@"deviceStatusChanged", @"messageReceived"];
}

- (NSArray*) getDevicesAsDictArray
{
    NSMutableArray *dictDevices = [NSMutableArray new];
    [[_devices allValues] enumerateObjectsUsingBlock:^(id device, NSUInteger idx, BOOL *stop) {
        [dictDevices addObject:@{@"deviceIdentifier":[[device uuid] UUIDString], @"friendlyName": [device friendlyName]}];
    }];
    return dictDevices;
}

- (BOOL)handleOpenURL:(NSURL *) url sourceApplication:(NSString *)sourceApplication {
    NSLog(@"handling open url %@ from source application %@", url.absoluteString, sourceApplication);
    if ([url.scheme isEqualToString:_urlScheme]) {
        NSArray *devices = [[ConnectIQ sharedInstance] parseDeviceSelectionResponseFromURL:url];
        if (devices != nil) {
            NSLog(@"Forgetting %d known devices.", (int)_devices.count);
            [_devices removeAllObjects];
            
            for (IQDevice *device in devices) {
                NSLog(@"Received device: [%@, %@, %@]", device.uuid, device.modelName, device.friendlyName);
                _devices[device.uuid] = device;
            }
            
            if (_connectedDevicesPromise != nil) {
                _connectedDevicesPromise([self getDevicesAsDictArray]);
            }
            [self saveDevicesToFileSystem];
            return YES;
        }
    } else {
        NSLog(@"url scheme %@ doesn't match expected scheme %@; not handled", url.scheme, _urlScheme);
    }
    return NO;
}

// Will be called when this module's first listener is added.
-(void)startObserving {
    hasListeners = YES;
    // Set up any upstream listeners or background tasks as necessary
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
    hasListeners = NO;
    // Remove upstream listeners, stop unnecessary background tasks
}



- (void)saveDevicesToFileSystem {
    NSLog(@"Saving known devices.");
    NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:_devices requiringSecureCoding:NO error:nil];
    if (![archivedData writeToFile:[self devicesFilePath] atomically:YES]) {
        NSLog(@"Failed to save devices file.");
    }
}

- (void)restoreDevicesFromFileSystem {
    NSData *unarchivedData = [NSData dataWithContentsOfFile:[self devicesFilePath]];
    NSMutableDictionary *restoredDevices = [NSKeyedUnarchiver unarchivedObjectOfClass:NSMutableDictionary.class fromData:unarchivedData error:nil];
    if (nil != restoredDevices && restoredDevices.count > 0) {
        NSLog(@"Restored saved devices:");
        for (IQDevice *device in restoredDevices.allValues) {
            NSLog(@"%@", device);
        }
        _devices = restoredDevices;
    } else {
        NSLog(@"No saved devices to restore.");
        [_devices removeAllObjects];
    }
}

- (NSString *)devicesFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportDirectory = [paths objectAtIndex:0];
    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:appSupportDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [appSupportDirectory stringByAppendingPathComponent:kDevicesFileName];
}


// Example method
// See // https://reactnative.dev/docs/native-modules-ios
RCT_EXPORT_METHOD(init:(NSString *) appId
                  storeId: (NSString*) storeId
                  urlScheme: (NSString *)urlScheme
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [[ConnectIQ sharedInstance] initializeWithUrlScheme:urlScheme uiOverrideDelegate:nil];
    _urlScheme = urlScheme;
    _appId = [[NSUUID alloc] initWithUUIDString: appId];
    if (storeId != nil) {
        _storeId =  [[NSUUID alloc] initWithUUIDString: storeId];
    }
    _app = [IQApp appWithUUID:_appId storeUuid:_storeId device:_device];
    _devices = [NSMutableDictionary new];
    resolve(nil);
}

RCT_EXPORT_METHOD(addListener:(NSString *) eventName
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    resolve(nil);
}

RCT_EXPORT_METHOD(removeListeners:(NSInteger) count
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    resolve(nil);
}

RCT_EXPORT_METHOD(sendMessage:(NSString *) message
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [[ConnectIQ sharedInstance] sendMessage:message toApp:_app progress:nil completion:^(IQSendMessageResult result) {
        NSString* resultString;
        switch (result) {
            case IQSendMessageResult_Success:
                resultString = @"SUCCESS";
                break;
            case IQSendMessageResult_Failure_Unknown:
                resultString = @"FAILURE_UNKNOWN";
                break;
            case IQSendMessageResult_Failure_InternalError:
                resultString = @"FAILURE_INTERNAL_ERROR";
                break;
            case IQSendMessageResult_Failure_DeviceNotAvailable:
                resultString = @"FAILURE_DEVICE_NOT_AVAILABLE";
                break;
            case IQSendMessageResult_Failure_AppNotFound:
                resultString = @"FAILURE_APP_NOT_FOUND";
                break;
            case IQSendMessageResult_Failure_DeviceIsBusy:
                resultString = @"FAILURE_DEVICE_IS_BUSY";
                break;
            case IQSendMessageResult_Failure_UnsupportedType:
                resultString = @"FAILURE_UNSUPPORTED_TYPE";
                break;
            case IQSendMessageResult_Failure_InsufficientMemory:
                resultString = @"FAILURE_INSUFFICIENT_MEMORY";
                break;
            case IQSendMessageResult_Failure_Timeout:
                resultString = @"FAILURE_TIMEOUT";
                break;
            case IQSendMessageResult_Failure_MaxRetries:
                resultString = @"FAILURE_MAX_RETRIES";
                break;
            case IQSendMessageResult_Failure_PromptNotDisplayed:
                resultString = @"FAILURE_PROMPT_NOT_DISPLAYED";
                break;
            case IQSendMessageResult_Failure_AppAlreadyRunning:
                resultString = @"FAILURE_UNSUPPORTED_TYPE";
                break;
        }
        
        resolve(resultString);
    }];
}

- (void)receivedMessage:(id)message fromApp:(IQApp *)app
{
    [self sendEventWithName:@"messageReceived" body:@{@"message": message}];

}

RCT_EXPORT_METHOD(setDevice:(NSString *) deviceId
                  resolve:(RCTPromiseResolveBlock) resolve
                  reject:(RCTPromiseRejectBlock) reject)
{
    _device = [_devices objectForKey:[[NSUUID alloc] initWithUUIDString: deviceId]];
    NSLog(@"device is %@", _device.uuid);
    [[ConnectIQ sharedInstance] registerForDeviceEvents: _device delegate:self];
    /// @param  app      The app to listen for messages from.
    /// @param  delegate The listener which will receive messages for this app.
    [[ConnectIQ sharedInstance] registerForAppMessages:_app delegate:self];

    resolve(nil);
}

RCT_EXPORT_METHOD(getApplicationInfo: (RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [[ConnectIQ sharedInstance] getAppStatus: _app];
}

RCT_EXPORT_METHOD(getKnownDevices: (RCTPromiseResolveBlock) resolve
                reject:(RCTPromiseRejectBlock) reject)
{
    resolve([self getDevicesAsDictArray]);
}

RCT_EXPORT_METHOD(getConnectedDevices: (RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject)
{
    _connectedDevicesPromise = resolve;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[ConnectIQ sharedInstance] showConnectIQDeviceSelection];
    });
}

RCT_EXPORT_METHOD(openStore: (RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [[ConnectIQ sharedInstance]  showConnectIQStoreForApp:_app];
    resolve(nil);
}
@end
