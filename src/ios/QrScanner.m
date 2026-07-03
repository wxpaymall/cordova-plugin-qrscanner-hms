/********* QrScanner.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <Cordova/CDVPluginResult.h>
#import <Cordova/CDVAppDelegate.h>
#import <ScanKitFrameWork/ScanKitFrameWork.h>
#import <UIKit/UIKit.h>

@class QrScannerDefaultScanViewController;

@interface QrScanner : CDVPlugin {
  NSString* callbackId;
  QrScannerDefaultScanViewController* scanViewController;
  UIViewController* scanParentViewController;
  BOOL isFinishingScan;
}

- (void)startScan:(CDVInvokedUrlCommand*)command;
- (void)cleanupScanView;
- (UIViewController*)topMostViewController;
- (void)scanViewControllerDidDisappear:(UIViewController*)viewController;
- (void)cancelScanWithMessage:(NSString*)message;
- (void)cancelScanFromButton;
- (void)finishScanWithResult:(NSString*)result;
@end

@interface QrScannerDefaultScanViewController : HmsDefaultScanViewController
@property (nonatomic, weak) QrScanner* owner;
@end

@implementation QrScannerDefaultScanViewController

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.owner scanViewControllerDidDisappear:self];
}

@end

@implementation QrScanner

- (void)startScan:(CDVInvokedUrlCommand*)command
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cleanupScanView];

        callbackId = command.callbackId;
        isFinishingScan = NO;
        scanParentViewController = [self topMostViewController];
        if (!scanParentViewController) {
            scanParentViewController = self.viewController;
        }

        NSLog(@"[QrScanner] startScan, parent: %@", scanParentViewController);

        scanViewController = [[QrScannerDefaultScanViewController alloc] init];
        scanViewController.owner = self;
        scanViewController.defaultScanDelegate = self;
        scanViewController.view.frame = scanParentViewController.view.bounds;
        scanViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        [scanParentViewController addChildViewController:scanViewController];
        [scanParentViewController.view addSubview:scanViewController.view];
        [scanViewController didMoveToParentViewController:scanParentViewController];
        scanParentViewController.navigationController.navigationBarHidden = YES;

        // HMS default scan page has a built-in back button but does not provide a cancel delegate.
        // Intercept taps in the top-left back area so JS receives the error callback and native state is cleaned.
        UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        cancelButton.frame = CGRectMake(0, 0, 100, 100);
        cancelButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        cancelButton.backgroundColor = [UIColor clearColor];
        [cancelButton addTarget:self action:@selector(cancelScanFromButton) forControlEvents:UIControlEventTouchUpInside];
        [scanViewController.view addSubview:cancelButton];
        [scanViewController.view bringSubviewToFront:cancelButton];
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

    NSLog(@"[QrScanner] cleanupScanView, scanViewController: %@", scanViewController);

    if (!scanViewController) {
        scanParentViewController = nil;
        return;
    }

    scanViewController.owner = nil;
    scanViewController.defaultScanDelegate = nil;
    [scanViewController willMoveToParentViewController:nil];
    [scanViewController.view removeFromSuperview];
    [scanViewController removeFromParentViewController];
    scanViewController = nil;
    scanParentViewController = nil;
}

- (void)finishScanWithResult:(NSString*)result
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishScanWithResult:result];
        });
        return;
    }

    NSString *currentCallbackId = callbackId;
    callbackId = nil;
    isFinishingScan = YES;

    if (!currentCallbackId) {
        [self cleanupScanView];
        return;
    }

    NSLog(@"[QrScanner] finishScanWithResult: %@", result);
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:(result ?: @"")];
    [self cleanupScanView];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:currentCallbackId];
}

- (void)cancelScanWithMessage:(NSString*)message
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cancelScanWithMessage:message];
        });
        return;
    }

    NSString *currentCallbackId = callbackId;
    callbackId = nil;
    isFinishingScan = YES;

    NSLog(@"[QrScanner] cancelScanWithMessage: %@", message);
    [self cleanupScanView];

    if (currentCallbackId) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:(message ?: @"scan cancelled")];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:currentCallbackId];
    }
}

- (void)cancelScanFromButton
{
    [self cancelScanWithMessage:@"scan cancelled"];
}

- (void)scanViewControllerDidDisappear:(UIViewController*)viewController
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scanViewControllerDidDisappear:viewController];
        });
        return;
    }

    if (viewController != scanViewController || isFinishingScan) {
        return;
    }

    if (viewController.presentedViewController) {
        NSLog(@"[QrScanner] scanViewControllerDidDisappear ignored, presentedViewController: %@", viewController.presentedViewController);
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (viewController == scanViewController && !isFinishingScan && !viewController.presentedViewController) {
            NSLog(@"[QrScanner] scan view disappeared without result, treat as cancel");
            [self cancelScanWithMessage:@"scan cancelled"];
        }
    });
}

- (void)defaultScanDelegateForDicResult:(NSDictionary *)resultDic{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *toastString = [NSString stringWithFormat:@"%@",[resultDic objectForKey:@"text"]];
        [self finishScanWithResult:toastString];
    });
}

- (void)defaultScanImagePickerDelegateForImage:(UIImage *)image{
    NSDictionary *dic = [HmsBitMap bitMapForImage:image withOptions:[[HmsScanOptions alloc] initWithScanFormatType:ALL Photo:true]];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *toastString = [NSString stringWithFormat:@"%@",[dic objectForKey:@"text"]];
        [self finishScanWithResult:toastString];
    });
}

- (void)onReset
{
    callbackId = nil;
    isFinishingScan = YES;
    [self cleanupScanView];
}

@end
