//
// --------------------------------------------------------------------------
// ScrollControl.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollControl.h"
#import "DeviceManager.h"
#import "SmoothScroll.h"
#import "RoughScroll.h"
#import "TouchSimulator.h"
#import "ModifierInputReceiver.h"
#import "ConfigFileInterface_HelperApp.h"

@implementation ScrollControl

#pragma mark - Globals

static AXUIElementRef _systemWideAXUIElement;

#pragma mark - Interface

/// When scrolling is in progress, there are tons of variables holding global state. This resets some of them.
/// I determined the ones it resets through trial and error. Some misbehaviour/bugs might be caused by this not resetting all of the global variables.
+ (void)resetDynamicGlobals {
    _horizontalScrolling    =   NO;
    [SmoothScroll resetDynamicGlobals];
}

// Used to switch between SmoothScroll and RoughScroll
static BOOL _isSmoothEnabled;
+ (BOOL)isSmoothEnabled {
    return _isSmoothEnabled;
}
+ (void)setIsSmoothEnabled:(BOOL)B {
    _isSmoothEnabled = B;
}

static CGPoint _previousMouseLocation;
+ (CGPoint)previousMouseLocation {
    return _previousMouseLocation;
}
+ (void)setPreviousMouseLocation:(CGPoint)p {
    _previousMouseLocation = p;
}

+ (void)load_Manual {
    _systemWideAXUIElement = AXUIElementCreateSystemWide();
}

static int _scrollDirection;
+ (int)scrollDirection {
    return _scrollDirection;
}
+ (void)setScrollDirection:(int)dir {
    _scrollDirection = dir;
}

// ??? whenever relevantDevicesAreAttached or isEnabled are changed, MomentumScrolls class method decide is called. Start or stop decide will start / stop momentum scroll and set _isRunning

/// Either activate SmoothScroll or RoughScroll or stop scroll interception entirely
+ (void)decide {
    
    NSLog(@"DECIDING!!!11!!!11");
    NSLog(@"%d", [DeviceManager relevantDevicesAreAttached]);
    
    
    BOOL disableAll =
    ![DeviceManager relevantDevicesAreAttached]
    || (!_isSmoothEnabled && _scrollDirection == 1);
//    || isEnabled == NO;
    
    if (disableAll) {
        [SmoothScroll stop];
//        [RoughScroll stop];
        [ModifierInputReceiver stop];
        return;
    }
    [ModifierInputReceiver start];
    if (_isSmoothEnabled) {
        [SmoothScroll start];
    } else {
        [RoughScroll start];
    }
}

static BOOL     _horizontalScrolling;
+ (BOOL)horizontalScrolling {
    return _horizontalScrolling;
}
+ (void)setHorizontalScrolling:(BOOL)B {
    _horizontalScrolling = B;
}
static BOOL     _magnificationScrolling;
+ (BOOL)magnificationScrolling {
    return _magnificationScrolling;
}
+ (void)setMagnificationScrolling:(BOOL)B {
    _magnificationScrolling = B;
    if (_magnificationScrolling && !B) {
//        if (_scrollPhase != kMFPhaseEnd) {
            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseEnded];
//            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseBegan];
//            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseEnded];
//        }
    } else if (!_magnificationScrolling && B) {
//        if (_scrollPhase == kMFPhaseMomentum || _scrollPhase == kMFPhaseWheel) {
            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseBegan];
//        }
    }
}

#pragma mark - Helper functions

@end
