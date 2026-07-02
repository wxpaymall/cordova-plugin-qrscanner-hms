/********* QrScanner.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <Cordova/CDVPluginResult.h>
#import <Cordova/CDVAppDelegate.h>
#import <ScanKitFrameWork/ScanKitFrameWork.h>

@interface QrScanner : CDVPlugin {
  NSString* callbackId;
  HmsDefaultScanViewController* scanViewController;
}

- (void)startScan:(CDVInvokedUrlCommand*)command;
- (void)cleanupScanView;
@end

@implementation QrScanner

- (void)startScan:(CDVInvokedUrlCommand*)command
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cleanupScanView];

        callbackId = command.callbackId;
        scanViewController = [[HmsDefaultScanViewController alloc] init];
        scanViewController.defaultScanDelegate = self;
        scanViewController.view.frame = self.webView.bounds;
        scanViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        [self.viewController addChildViewController:scanViewController];
        [self.webView addSubview:scanViewController.view];
        [scanViewController didMoveToParentViewController:self.viewController];
        self.viewController.navigationController.navigationBarHidden = YES;
    });
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
        return;
    }

    scanViewController.defaultScanDelegate = nil;
    [scanViewController willMoveToParentViewController:nil];
    [scanViewController.view removeFromSuperview];
    [scanViewController removeFromParentViewController];
    scanViewController = nil;
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
