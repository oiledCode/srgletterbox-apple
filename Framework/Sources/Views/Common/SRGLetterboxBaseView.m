//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGLetterboxBaseView.h"

#import "NSBundle+SRGLetterbox.h"
#import "SRGLetterboxView+Private.h"

static void commonInit(SRGLetterboxBaseView *self);

@interface SRGLetterboxBaseView ()

@property (nonatomic) UIView *nibView;         // Strong

@end

@implementation SRGLetterboxBaseView

#pragma mark Object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        commonInit(self);
        
        // The top-level view loaded from the xib file and initialized in `commonInit` is NOT a instance of the class.
        // Manually calling `-awakeFromNib` forces the final view initialization (also see comments in `commonInit`).
        [self awakeFromNib];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        commonInit(self);
    }
    return self;
}

#pragma mark Getters and setters

#if TARGET_OS_IOS

- (SRGLetterboxView *)parentLetterboxView
{
    // Start with self. The context can namely be the receiver itself
    UIView *parentLetterboxView = self;
    while (parentLetterboxView) {
        if ([parentLetterboxView isKindOfClass:SRGLetterboxView.class]) {
            return (SRGLetterboxView *)parentLetterboxView;
        }
        parentLetterboxView = parentLetterboxView.superview;
    }
    return nil;
}

#endif

#pragma mark Overrides

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        if (self.nibView) {
            [self insertSubview:self.nibView atIndex:0];
            
            self.nibView.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[ [self.nibView.topAnchor constraintEqualToAnchor:self.topAnchor],
                                                       [self.nibView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
                                                       [self.nibView.leftAnchor constraintEqualToAnchor:self.leftAnchor],
                                                       [self.nibView.rightAnchor constraintEqualToAnchor:self.rightAnchor] ]];
        }
        
        [self contentSizeCategoryDidChange];
        [self voiceOverStatusDidChange];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(contentSizeCategoryDidChange:)
                                                   name:UIContentSizeCategoryDidChangeNotification
                                                 object:nil];
        
#if TARGET_OS_IOS
        if (@available(iOS 11, *)) {
#endif
            [NSNotificationCenter.defaultCenter addObserver:self
                                                   selector:@selector(accessibilityVoiceOverStatusDidChange:)
                                                       name:UIAccessibilityVoiceOverStatusDidChangeNotification
                                                     object:nil];
#if TARGET_OS_IOS
        }
        else {
            [NSNotificationCenter.defaultCenter addObserver:self
                                                   selector:@selector(accessibilityVoiceOverStatusDidChange:)
                                                       name:UIAccessibilityVoiceOverStatusChanged
                                                     object:nil];
        }
#endif
    }
    else {
        [self.nibView removeFromSuperview];
        
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:UIContentSizeCategoryDidChangeNotification
                                                    object:nil];
        
#if TARGET_OS_IOS
        if (@available(iOS 11, *)) {
#endif
            [NSNotificationCenter.defaultCenter removeObserver:self
                                                          name:UIAccessibilityVoiceOverStatusDidChangeNotification
                                                        object:nil];
#if TARGET_OS_IOS
        }
        else {
            [NSNotificationCenter.defaultCenter removeObserver:self
                                                          name:UIAccessibilityVoiceOverStatusChanged
                                                        object:nil];
        }
#endif
    }
}

#pragma mark Subclassing hooks

- (void)contentSizeCategoryDidChange
{}

- (void)voiceOverStatusDidChange
{}

- (void)updateLayoutForUserInterfaceHidden:(BOOL)userInterfaceHidden
{}

- (void)immediatelyUpdateLayoutForUserInterfaceHidden:(BOOL)userInterfaceHidden
{}

#pragma mark Notifications

- (void)contentSizeCategoryDidChange:(NSNotification *)notification
{
    [self contentSizeCategoryDidChange];
}

- (void)accessibilityVoiceOverStatusDidChange:(NSNotification *)notification
{
    [self voiceOverStatusDidChange];
}

#pragma mark Layout

#if TARGET_OS_IOS

- (void)setNeedsLayoutAnimated:(BOOL)animated
{
    [self.parentLetterboxView setNeedsLayoutAnimated:animated];
}

#endif

@end

static void commonInit(SRGLetterboxBaseView *self)
{
    NSString *nibName = SRGLetterboxResourceNameForUIClass(self.class);
    if ([NSBundle.srg_letterboxBundle pathForResource:nibName ofType:@"nib"]) {
        // This makes design in a xib and Interface Builder preview (IB_DESIGNABLE) work. The top-level view must NOT be
        // an instance of the class itself to avoid infinite recursion.
        self.nibView = [[NSBundle.srg_letterboxBundle loadNibNamed:nibName owner:self options:nil] firstObject];
        self.nibView.backgroundColor = UIColor.clearColor;
    }
}
