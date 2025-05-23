#import "ConnectIqMobileSdk.h"
#import <ConnectIQ/ConnectIQ.h>

NSString * const kDevicesFileName = @"devices";

@interface ConnectIqMobileSdk() <IQDeviceEventDelegate,IQAppMessageDelegate>

@property (nonatomic, readwrite) NSMutableDictionary *devices;
@property (nonatomic, readwrite) IQDevice* device;
@property (nonatomic, readwrite) RCTPromiseResolveBlock connectedDevicesPromise;
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
        [dictDevices addObject:@{@"deviceIdentifier":[[device uuid] UUIDString], @"friendlyName": [device friendlyName], @"modelName": [device modelName]}];
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
                if (device.uuid != nil && device !=nil) {
                    _devices[device.uuid] = device;
                } else {
                    NSLog(@"Device id or device was nil");
                }
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
RCT_EXPORT_METHOD(init: (NSString*) storeId
                  urlScheme: (NSString *)urlScheme
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"init called with storeId %@, urlScheme %@", storeId, urlScheme);
    [[ConnectIQ sharedInstance] initializeWithUrlScheme:urlScheme uiOverrideDelegate:nil];
    _urlScheme = urlScheme;
    if (storeId != nil) {
        _storeId =  [[NSUUID alloc] initWithUUIDString: storeId];
    }
//    NSLog(@"setting app to %@", _app.description);
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


- (void) sendMessageInternal: (id)message
appId: (NSString *) appId
resolve:(RCTPromiseResolveBlock)resolve
reject:(RCTPromiseRejectBlock)reject
{
    if (appId == nil) {
        NSError * error = [[NSError alloc] initWithDomain:@"com.github" code:200 userInfo:@{@"Error reason": @"No app provided.  Please provide an appId"}];
        reject(@"error",@"appId is null", error);
        return;
    }
    if (_device == nil) {
        NSError * error = [[NSError alloc] initWithDomain:@"com.github" code:201 userInfo:@{@"Error reason": @"No device set.  Please call setDevice"}];
        reject(@"error",@"setDevice not called", error);
        return;
    }
    NSUUID* appUuid = [[NSUUID alloc] initWithUUIDString: appId];
    IQApp* app = [IQApp appWithUUID:appUuid storeUuid:_storeId device:_device];
    NSLog(@"sending message to app %@", app.description);
    [[ConnectIQ sharedInstance] sendMessage:message toApp:app progress:nil completion:^(IQSendMessageResult result) {
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

RCT_EXPORT_METHOD(sendMessageDictionary:(NSDictionary *) dictMessage
                  appId: (NSString *) appId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [self sendMessageInternal: dictMessage appId:appId resolve:resolve reject: reject];
}

RCT_EXPORT_METHOD(sendMessage:(NSString *) message
                  appId: (NSString *) appId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [self sendMessageInternal: message appId:appId resolve:resolve reject: reject];
}

- (void)deviceStatusChanged:(IQDevice *)device status:(IQDeviceStatus)status {
    NSString* statusString;
    switch (status) {
        case IQDeviceStatus_InvalidDevice:
            statusString = @"INVALID_DEVICE";
            break;
        case IQDeviceStatus_BluetoothNotReady:
            statusString = @"NOT_PAIRED";
            break;
        case IQDeviceStatus_NotFound:
            statusString = @"NOT_FOUND";
            break;
        case IQDeviceStatus_NotConnected:
            statusString = @"NOT_CONNECTED";
            break;
        case IQDeviceStatus_Connected:
            statusString = @"CONNECTED";
            break;
    }
    [self sendEventWithName:@"deviceStatusChanged" body:@{@"deviceId": [device.uuid  UUIDString], @"status": statusString}];
}

- (void)receivedMessage:(id)message fromApp:(IQApp *)app
{
    NSString *appId = [app.uuid UUIDString];
    [self sendEventWithName:@"messageReceived" body:@{@"message": message, @"appId": appId}];
}

RCT_EXPORT_METHOD(setDevice:(NSDictionary *) device
                  resolve:(RCTPromiseResolveBlock) resolve
                  reject:(RCTPromiseRejectBlock) reject)
{
    NSLog(@"setting device to %@", device.description);
    _device = [IQDevice deviceWithId: [[NSUUID alloc] initWithUUIDString:[device objectForKey:@"deviceIdentifier"]] modelName: [device objectForKey:@"modelName"] friendlyName: [device objectForKey:@"friendlyName"]];
    [[ConnectIQ sharedInstance] registerForDeviceEvents: _device delegate:self];
    IQDeviceStatus deviceStatus = [[ConnectIQ sharedInstance] getDeviceStatus: _device];
    [self deviceStatusChanged: _device status: deviceStatus];

    resolve(nil);
}

RCT_EXPORT_METHOD(registerForAppMessages: (NSString*) appId
                  resolve:(RCTPromiseResolveBlock) resolve
                  reject:(RCTPromiseRejectBlock) reject)
{
    NSUUID* appUuid = [[NSUUID alloc] initWithUUIDString: appId];
    IQApp* app = [IQApp appWithUUID:appUuid storeUuid:_storeId device:_device];
    [[ConnectIQ sharedInstance] registerForAppMessages:app delegate:self];
    resolve(nil);
}


RCT_EXPORT_METHOD(getApplicationInfo:  (NSString*) appId           resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSUUID* appUuid = [[NSUUID alloc] initWithUUIDString: appId];
    IQApp* app = [IQApp appWithUUID:appUuid storeUuid:_storeId device:_device];

    NSLog(@"calling getAppStatus with app %@", app.description);
    [[ConnectIQ sharedInstance] getAppStatus:app completion:^(IQAppStatus *appStatus) {
        NSLog(@"got AppStatus of %@", appStatus.description);
        resolve(@{
            @"status": appStatus.isInstalled ? @"INSTALLED" : @"NOT_INSTALLED",
            @"version": [NSString stringWithFormat:@"%d", appStatus.version],
        });
    }];
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

RCT_EXPORT_METHOD(openStore: (NSString*) appId           resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSUUID* appUuid = [[NSUUID alloc] initWithUUIDString: appId];
    IQApp* app = [IQApp appWithUUID:appUuid storeUuid:_storeId device:_device];

    [[ConnectIQ sharedInstance]  showConnectIQStoreForApp:app];
    resolve(nil);
}
@end
