#import "AppDelegate.h"

#import <React/RCTBundleURLProvider.h>
#import <React/RCTBridge.h>
#import <React/RCTBridge+Private.h>


#import "ConnectIqMobileSdk.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.moduleName = @"ConnectIqMobileSdkExample";
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};

  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSString* sourceApp = options[UIApplicationOpenURLOptionsSourceApplicationKey];
    NSLog(@"Received URL from '%@': %@", sourceApp, url);

   RCTBridge *bridge = [RCTBridge currentBridge];
  
   ConnectIqMobileSdk * connectIqMobileSdk = [bridge moduleForName:@"ConnectIqMobileSdk"];

   return [connectIqMobileSdk handleOpenURL:url sourceApplication:sourceApp];
}

@end
