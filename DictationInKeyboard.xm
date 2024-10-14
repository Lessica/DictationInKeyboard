#import <HBLog.h>
#import <substrate.h>

@import Foundation;
@import UIKit;

static BOOL USE_SWITCH_CONTROL = YES;

#define ITEM_ID "com.82flex.dictationinkeyboard.dictation"
#define NOTIFY_ENABLE "com.82flex.dictationinkeyboard/enable"
#define NOTIFY_DISABLE "com.82flex.dictationinkeyboard/disable"

@interface AFPreferences : NSObject
- (void)setDictationIsEnabled:(BOOL)enabled;
- (void)synchronize;
@end

@interface UIDictationConnectionPreferences : NSObject
@property (nonatomic, retain) AFPreferences *afPreferences;
+ (instancetype)sharedInstance;
- (BOOL)dictationIsEnabled;
@end

@interface UIInputSwitcherItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *localizedTitle;
@property (nonatomic, copy) NSString *localizedSubtitle;
@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) UIFont *subtitleFont;
@property (assign, nonatomic) BOOL usesDeviceLanguage;
@property (nonatomic, strong) UISwitch *switchControl;
@property (nonatomic, copy) id switchIsOnBlock;
@property (nonatomic, copy) id switchToggleBlock;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

@interface UIInputSwitcherView : UIView
@end

@interface UIKeyboardLayoutStar : NSObject
@property (nonatomic, strong) NSNumber *dik_needsReloadKeyplane;
- (void)refreshForDictationAvailablityDidChange;
- (void)reloadCurrentKeyplane;
- (void)dik_setNeedsReloadKeyplane;
- (void)upActionShift;
@end

@interface UIKBTree : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSMutableDictionary *properties; 
@end

@interface DIKWeakContainer : NSObject
@property (nonatomic, weak) id object;
@end

@implementation DIKWeakContainer
@end

static NSMutableArray<DIKWeakContainer *> *gWeakStarContainers = nil;

%group DIK_UIKit

%hook UIKeyboardLayoutStar

%property (nonatomic, strong) NSNumber *dik_needsReloadKeyplane;

%new
- (void)dik_setNeedsReloadKeyplane {
    self.dik_needsReloadKeyplane = @YES;
}

- (id)initWithFrame:(CGRect)arg1 {
    id star = %orig;
    DIKWeakContainer *container = [DIKWeakContainer new];
    container.object = star;
    [gWeakStarContainers addObject:container];
    return star;
}

- (void)refreshForDictationAvailablityDidChange {
    %orig;
    if ([self.dik_needsReloadKeyplane boolValue]) {
        self.dik_needsReloadKeyplane = @NO;
        [self reloadCurrentKeyplane];
    }
}

- (void)downActionShiftWithKey:(UIKBTree *)arg1 {
    %orig;
    if ([arg1.name isEqualToString:@"TenKey-Chinese-Facemark"]) {
        [self upActionShift];
    }
}

%end

%hook UIInputSwitcherView

- (BOOL)shouldSelectItemAtIndex:(unsigned long long)index {
    if (!USE_SWITCH_CONTROL) {
        return %orig;
    }
    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    UIInputSwitcherItem *item = items[index];
    if ([item.identifier isEqualToString:@ITEM_ID]) {
        return YES;
    }
    return %orig;
}

- (void)didSelectItemAtIndex:(unsigned long long)index {
    if (USE_SWITCH_CONTROL) {
        %orig;
        return;
    }
    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    UIInputSwitcherItem *item = items[index];
    if ([item.identifier isEqualToString:@ITEM_ID]) {
        for (DIKWeakContainer *container in gWeakStarContainers) {
            UIKeyboardLayoutStar *star = container.object;
            [star dik_setNeedsReloadKeyplane];
        }
        BOOL isDictationEnabled = [[%c(UIDictationConnectionPreferences) sharedInstance] dictationIsEnabled];
        if (isDictationEnabled) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(NOTIFY_DISABLE), NULL, NULL, YES);
        } else {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(NOTIFY_ENABLE), NULL, NULL, YES);
        }
    }
    %orig;
}

- (void)_reloadInputSwitcherItems {
    %orig;

    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:items];

    UIInputSwitcherItem *item = [[%c(UIInputSwitcherItem) alloc] initWithIdentifier:@ITEM_ID];

    if (USE_SWITCH_CONTROL) {
        NSBundle *keyboardBundle = [NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/KeyboardSettings.bundle"];
        NSString *title = [keyboardBundle localizedStringForKey:@"DICTATION" value:nil table:@"Keyboard"];
        [item setLocalizedTitle:title];

        UISwitch *switchControl = [[UISwitch alloc] init];
        [item setSwitchControl:switchControl];
        [item setSwitchIsOnBlock:^BOOL{
            return [[%c(UIDictationConnectionPreferences) sharedInstance] dictationIsEnabled];
        }];
        [item setSwitchToggleBlock:^(BOOL isOn) {
            for (DIKWeakContainer *container in gWeakStarContainers) {
                UIKeyboardLayoutStar *star = container.object;
                [star dik_setNeedsReloadKeyplane];
            }
            if (isOn) {
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(NOTIFY_ENABLE), NULL, NULL, YES);
            } else {
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(NOTIFY_DISABLE), NULL, NULL, YES);
            }
        }];
    } else {
        BOOL isDictationEnabled = [[%c(UIDictationConnectionPreferences) sharedInstance] dictationIsEnabled];
        [item setLocalizedTitle:isDictationEnabled ? @"听写已启用" : @"听写已停用"];
    }

    [newItems insertObject:item atIndex:0];
    MSHookIvar<NSArray *>(self, "m_inputSwitcherItems") = newItems;
}

%end

%end

%group DIK_Behaviors

%hook UIKBTree

- (id)initWithType:(int)arg1 withName:(NSString *)arg2 withProperties:(id)arg3 withSubtrees:(id)arg4 withCache:(id)arg5 {
    HBLogWarn(@"UIKBTree initWithType:%d withName:%@ withProperties:%@ withSubtrees:%@ withCache:%@", arg1, arg2, arg3, arg4, arg5);
    if ([arg2 isEqualToString:@"TenKey-Chinese-Facemark"]) {
        NSDictionary *newProperties = @{
            @"KBdisplayString": @"#+=",
            @"KBdisplayType": @18,
            @"KBinteractionType": @14,
            @"KBrepresentedString": @"Shift",
        };
        return %orig(arg1, arg2, [newProperties mutableCopy], arg4, arg5);
    }
    if ([arg2 hasSuffix:@"_PortraitChoco_iPhone-Pinyin10-Keyboard_Pinyin-Plane"] || 
        [arg2 hasSuffix:@"_PortraitTruffle_iPhone-Pinyin10-Keyboard_Pinyin-Plane"] ||
        [arg2 hasSuffix:@"_Caymen_iPhone-Pinyin10-Keyboard_Pinyin-Plane"]
    ) {
        NSMutableDictionary *newProperties = [arg3 mutableCopy];
        [newProperties addEntriesFromDictionary:@{
            @"shift-alternate": @"numbers-and-punctuation-plane",
        }];
        return %orig(arg1, arg2, newProperties, arg4, arg5);
    }
    return %orig;
}

%end

%end

static void ToggleOn(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AFPreferences *afPreferences = [[%c(UIDictationConnectionPreferences) sharedInstance] afPreferences];
        [afPreferences setDictationIsEnabled:YES];
    });
}

static void ToggleOff(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AFPreferences *afPreferences = [[%c(UIDictationConnectionPreferences) sharedInstance] afPreferences];
        [afPreferences setDictationIsEnabled:NO];
    });
}

%ctor {
    gWeakStarContainers = [NSMutableArray array];

    %init(DIK_Behaviors);
    %init(DIK_UIKit);
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = mainBundle.bundleIdentifier;
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, ToggleOn, CFSTR(NOTIFY_ENABLE), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, ToggleOff, CFSTR(NOTIFY_DISABLE), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}