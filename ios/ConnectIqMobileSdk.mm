#import "ConnectIqMobileSdk.h"
#import <ConnectIQ/ConnectIQ.h>

@implementation ConnectIqMobileSdk
RCT_EXPORT_MODULE()

// Example method
// See // https://reactnative.dev/docs/native-modules-ios
RCT_EXPORT_METHOD(init:(NSString *) appId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [[ConnectIQ sharedInstance] initializeWithUrlScheme:@"abcd" uiOverrideDelegate:nil];
 
    //resolve(result);
}


@end
