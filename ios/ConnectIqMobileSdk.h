#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "RNConnectIqMobileSdkSpec.h"

@interface ConnectIqMobileSdk : NSObject <NativeConnectIqMobileSdkSpec>
#else
#import <React/RCTBridgeModule.h>

@interface ConnectIqMobileSdk : RCTEventEmitter <RCTBridgeModule>


#endif
- (BOOL)handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication;
@end
