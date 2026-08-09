#import "RegistrantBridge.h"
#import "GeneratedPluginRegistrant.h"
#import <objc/message.h>

@implementation RegistrantBridge

+ (void)registerPluginsWith:(NSObject<FlutterPluginRegistry> *)registry {
    // The generated registrant exposes either `registerWithRegistry:` or
    // `registerWith:` depending on the Flutter tool's plugin integration mode.
    // Resolve at runtime so the app does not depend on the generated selector.
    SEL registerSel = NSSelectorFromString(@"registerWithRegistry:");
    if (![GeneratedPluginRegistrant respondsToSelector:registerSel]) {
        registerSel = NSSelectorFromString(@"registerWith:");
    }
    if (![GeneratedPluginRegistrant respondsToSelector:registerSel]) {
        NSLog(@"Relay: GeneratedPluginRegistrant has no register selector; plugins were not registered");
        return;
    }
    typedef void (*RegistrantFn)(id, SEL, id);
    ((RegistrantFn)objc_msgSend)([GeneratedPluginRegistrant class], registerSel, registry);
}

@end
