/********* QrScanner.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <Cordova/CDVPluginResult.h>
#import <Cordova/CDVAppDelegate.h>
#import <ScanKitFrameWork/ScanKitFrameWork.h>
#import <UIKit/UIKit.h>

@interface QrScanner : CDVPlugin {
  NSString* callbackId;
  HmsDefaultScanViewController* scanViewController;
  UIViewController* scanParentViewController;
}

- (void)startScan:(CDVInvokedUrlCommand*)command;
- (void)cleanupScanView;
- (UIViewController*)topMostViewController;
@end

@implementation QrScanner

- (void)startScan:(CDVInvokedUrlCommand*)command
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cleanupScanView];

        callbackId = command.callbackId;
        scanParentViewController = [self topMostViewController];
        if (!scanParentViewController) {
            scanParentViewController = self.viewController;
        }

        scanViewController = [[HmsDefaultScanViewController alloc] init];
        scanViewController.defaultScanDelegate = self;
        scanViewController.view.frame = scanParentViewController.view.bounds;
        scanViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        [scanParentViewController addChildViewController:scanViewController];
        [scanParentViewController.view addSubview:scanViewController.view];
        [scanViewController didMoveToParentViewController:scanParentViewController];
        scanParentViewController.navigationController.navigationBarHidden = YES;
    });
}

- (UIViewController*)topMostViewController
{
    UIWindow *keyWindow = nil;

    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }

            if (keyWindow) {
                break;
            }
        }
    }

    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }

    UIViewController *topViewController = keyWindow.rootViewController ? keyWindow.rootViewController : self.viewController;
    BOOL foundNext = YES;
    while (foundNext) {
        foundNext = NO;

        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
            foundNext = YES;
            continue;
        }

        if ([topViewController isKindOfClass:[UINavigationController class]]) {
            UIViewController *visibleViewController = ((UINavigationController *)topViewController).visibleViewController;
            if (visibleViewController && visibleViewController != topViewController) {
                topViewController = visibleViewController;
                foundNext = YES;
                continue;
            }
        }

        if ([topViewController isKindOfClass:[UITabBarController class]]) {
            UIViewController *selectedViewController = ((UITabBarController *)topViewController).selectedViewController;
            if (selectedViewController && selectedViewController != topViewController) {
                topViewController = selectedViewController;
                foundNext = YES;
                continue;
            }
        }
    }

    return topViewController;
}

- (void)cleanupScanView
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cleanupScanView];
        });
        return;
    }

    if (!scanViewController) {
        scanParentViewController = nil;
        return;
    }

    scanViewController.defaultScanDelegate = nil;
    [scanViewController willMoveToParentViewController:nil];
    [scanViewController.view removeFromSuperview];
    [scanViewController removeFromParentViewController];
    scanViewController = nil;
    scanParentViewController = nil;
}

- (void)defaultScanDelegateForDicResult:(NSDictionary *)resultDic{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentCallbackId = callbackId;
        callbackId = nil;
        if (!currentCallbackId) {
            [self cleanupScanView];
            return;
        }

        NSString *toastString = [NSString stringWithFormat:@"%@",[resultDic objectForKey:@"text"]];
        CDVPluginResult * pluginResult =[CDVPluginResult resultWithStatus : CDVCommandStatus_OK messageAsString : toastString];
        [self cleanupScanView];
        [self.commandDelegate sendPluginResult: pluginResult callbackId: currentCallbackId];
    });
}

- (void)defaultScanImagePickerDelegateForImage:(UIImage *)image{
    NSDictionary *dic = [HmsBitMap bitMapForImage:image withOptions:[[HmsScanOptions alloc] initWithScanFormatType:ALL Photo:true]];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentCallbackId = callbackId;
        callbackId = nil;
        if (!currentCallbackId) {
            [self cleanupScanView];
            return;
        }

        NSString *toastString = [NSString stringWithFormat:@"%@",[dic objectForKey:@"text"]];
        CDVPluginResult * pluginResult =[CDVPluginResult resultWithStatus : CDVCommandStatus_OK messageAsString : toastString];
        [self cleanupScanView];
        [self.commandDelegate sendPluginResult: pluginResult callbackId: currentCallbackId];
    });
}

- (void)onReset
{
    callbackId = nil;
    [self cleanupScanView];
}

@end
