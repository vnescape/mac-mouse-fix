//
// --------------------------------------------------------------------------
// AppDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <PreferencePanes/PreferencePanes.h>
#import "AppDelegate.h"
#import "Config.h"
#import "MFMessagePort.h"
#import "Utility_App.h"
#import "AuthorizeAccessibilityView.h"
#import "HelperServices.h"
#import "SharedUtility.h"
#import "ToastNotificationController.h"
#import "NSView+Additions.h"
#import "AppTranslocationManager.h"
#import "NSAttributedString+Additions.h"
#import "Mac_Mouse_Fix-Swift.h"
#import "Locator.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

#pragma mark - IBActions

- (IBAction)openAboutTab:(id)sender {
    [MainAppState.shared.tabViewController coolSelectTabWithIdentifier:@"about" window:nil];
}

- (IBAction)activateLicense:(id)sender {
    [LicenseSheetController add];
}

- (IBAction)buyMMF:(id)sender {
    
    [LicenseConfig getOnComplete:^(LicenseConfig * _Nonnull licenseConfig) {
            
    }];
}


#pragma mark - Interface funcs

/// TODO: Remove these in favor of MainAppState.swift

+ (AppDelegate *)instance {
    return (AppDelegate *)NSApp.delegate;
}
+ (NSWindow *)mainWindow {
    return self.instance.window;
}

#pragma mark - Handle URLs

- (void)handleURLWithEvent:(NSAppleEventDescriptor *)event reply:(NSAppleEventDescriptor *)reply {
    
    /// Log
    DDLogDebug(@"Handling URL: %@", event.description);
    
    /// Get URL
    NSString *address = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL *url = [NSURL URLWithString:address];
    
    /// Get URL components
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    assert([components.scheme isEqual:@"macmousefix"]); /// Assert because we should only receive URLs with this scheme
    
    /// Get path from components
    NSString *path = components.path;
    
    /// Get query dict from components
    NSArray<NSURLQueryItem *> *queryItemArray = components.queryItems;
    NSMutableDictionary *queryItems = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in queryItemArray) {
        queryItems[item.name] = item.value;
    }
    
    if ([path isEqual:@"activate"]) {
        
        /// Open the license activation UI
        
        [LicenseSheetController add];
        
    } else if ([path isEqual:@"disable"]) {
        
        /// Switch to the general tab and then disable the helper
        
        /// Gather info
        NSString *currentTab = MainAppState.shared.tabViewController.identifierOfSelectedTab;
        BOOL willSwitch = ![currentTab isEqual:@"general"];
        BOOL windowExists = self.window != nil;
        
        /// Get delays
        double preSwitchDelay = willSwitch && !windowExists ? 0.1 : 0.0; /// Wait until the window exists so the switch works
        double postSwitchDelay = willSwitch ? 0.5 : 0.0; /// Wait until the tab switch animation is done before disabling the helper
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * preSwitchDelay), dispatch_get_main_queue(), ^{
            
            if (willSwitch) {
                [MainAppState.shared.tabViewController coolSelectTabWithIdentifier:@"general" window:self.window];
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * postSwitchDelay), dispatch_get_main_queue(), ^{
                
                [EnabledState.shared disable];
            });
        });
        
    } else if ([path isEqual:@"restarthelper"]) {
        
        NSString *delay = queryItems[@"delay"];
        [HelperServices restartHelperWithDelay:delay.doubleValue];
        
    } else {
        DDLogWarn(@"Received URL with unknown path: %@", address);
    }
}

#pragma mark - Init and Lifecycle

/// Define Globals
static NSDictionary *_scrollConfigurations;
static NSDictionary *sideButtonActions;

+ (void)initialize {
    
    if (self == [AppDelegate class]) {
        
        /// Why don't we do these things in applicationDidFinishLaunching?
        ///     TODO: Try moving this to applicationDidFinishLaunching, so we have a unified entryPoint.
        
        /// Setup CocoaLumberjack
        [SharedUtility setupBasicCocoaLumberjackLogging];
        DDLogInfo(@"Main App starting up...");     
        
        /// Remove restart the app untranslocated if it's currently translocated
        /// Need to call this before `MessagePort_App` is initialized, otherwise stuff breaks if app is translocated
        [AppTranslocationManager removeTranslocation];
        
        /// Start parts of the app that depend on the initialization we just did
        [MFMessagePort load_Manual];
        
        /// Need to manually initConfig because it is shared with Helper, and helper uses `load_Manual`
        ///     Edit: What?? That doesn't make sense to me.
        [Config load_Manual];
    }
    
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        /// Init URL handling
        ///     Doesn't work if done in applicationDidFinishLaunching or + initialize
        [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLWithEvent:reply:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    }
    return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
#pragma mark - Entry point of MainApp
    
    /// Log
    
    DDLogInfo(@"Mac Mouse Fix finished launching");
    
#pragma mark Experiments
    
    /// Test titlebarAccessory
    ///     Trying to add accessoryView to titlebar. We want this for app specific settings. Doesn't work so far
    ///     \note This *is* successfully added when we open the main app through the StatusBarItem (using NSWorkspace and the bundle URL)
    if ((NO)) {
        NSTitlebarAccessoryViewController *viewController = [[NSTitlebarAccessoryViewController alloc] initWithNibName:@"MyTitlebarAccessoryViewController" bundle:nil];
        viewController.layoutAttribute = NSLayoutAttributeRight;
        [NSApp.mainWindow addTitlebarAccessoryViewController:viewController];
    }
    
    /// Update licenseConfig
    ///     We only update once on startup and then use`[LicenseConfig getCached]` anywhere else in the main app. (Currrently only the about tab.)
    ///     Notes:
    ///     - If the user launches the app directly into the aboutTab, or switches to it super quickly, then the displayed info won't be up to date, but that's a very minor problem
    ///     - We don't need a similar mechanism in Helper, because it doesn't need to display licenseConfig immediately after user input
    ///     Edit: Turning this off for now because we don't need it.
    
//    [LicenseConfig getOnComplete:^(LicenseConfig * _Nonnull config) { }];
    
#pragma mark Update activeDevice onClick
    
    static id eventMonitor = nil;
    assert(eventMonitor == nil);
    
    if (eventMonitor == nil) {
        
        eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
            
            uint64_t senderID = CGEventGetIntegerValueField(event.CGEvent, (CGEventField)kMFCGEventFieldSenderID);
            [MFMessagePort sendMessage:@"updateActiveDeviceWithEventSenderID" withPayload:@(senderID) waitForReply:NO];
            
            return event;
        }];
    }
    
@end
