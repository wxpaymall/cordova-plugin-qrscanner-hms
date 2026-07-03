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
  UIViewController* scanPresenterViewController;
  BOOL isFinishingScan;
}

- (void)startScan:(CDVInvokedUrlCommand*)command;
- (UIViewController*)topMostViewController;
- (void)cleanupScanViewWithCompletion:(void (^)(void))completion;
- (void)cleanupScanView;
- (void)scanViewControllerDidDisappear:(UIViewController*)viewController;
- (void)cancelScanWithMessage:(NSString*)message;
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
        scanPresenterViewController = [self topMostViewController];
        if (!scanPresenterViewController) {
            scanPresenterViewController = self.viewController;
        }

        NSLog(@"[QrScanner] startScan, presenter: %@", scanPresenterViewController);

        scanViewController = [[QrScannerDefaultScanViewController alloc] init];
        scanViewController.owner = self;
        scanViewController.defaultScanDelegate = self;
        scanViewController.modalPresentationStyle = UIModalPresentationFullScreen;

        [scanPresenterViewController presentViewController:scanViewController animated:YES completion:nil];
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
    [self cleanupScanViewWithCompletion:nil];
}

- (void)cleanupScanViewWithCompletion:(void (^)(void))completion
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cleanupScanViewWithCompletion:completion];
        });
        return;
    }

    NSLog(@"[QrScanner] cleanupScanView, scanViewController: %@", scanViewController);

    if (!scanViewController) {
        scanPresenterViewController = nil;
        if (completion) {
            completion();
        }
        return;
    }

    QrScannerDefaultScanViewController *controller = scanViewController;
    scanViewController = nil;
    scanPresenterViewController = nil;
    controller.owner = nil;
    controller.defaultScanDelegate = nil;

    if (controller.presentingViewController) {
        [controller dismissViewControllerAnimated:YES completion:completion];
    } else {
        if (controller.parentViewController) {
            [controller willMoveToParentViewController:nil];
            [controller.view removeFromSuperview];
            [controller removeFromParentViewController];
        } else {
            [controller.view removeFromSuperview];
        }
        if (completion) {
            completion();
        }
    }
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
    [self cleanupScanViewWithCompletion:^{
        [self.commandDelegate sendPluginResult:pluginResult callbackId:currentCallbackId];
    }];
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
    [self cleanupScanViewWithCompletion:^{
        if (currentCallbackId) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:(message ?: @"scan cancelled")];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:currentCallbackId];
        }
    }];
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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (viewController == scanViewController && !isFinishingScan) {
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
