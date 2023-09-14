
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNConnectIqMobileSdkSpec.h"

@interface ConnectIqMobileSdk : NSObject <NativeConnectIqMobileSdkSpec>
#else
#import <React/RCTBridgeModule.h>

@interface ConnectIqMobileSdk : NSObject <RCTBridgeModule>
#endif

@end
