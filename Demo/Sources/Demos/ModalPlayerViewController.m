//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ModalPlayerViewController.h"

#import "ModalTransition.h"
#import "NSBundle+LetterboxDemo.h"
#import "UIWindow+LetterboxDemo.h"

#import <Masonry/Masonry.h>
#import <SRGAnalytics/SRGAnalytics.h>

@interface ModalPlayerViewController ()

@property (nonatomic) SRGMediaURN *URN;
@property (nonatomic) BOOL chaptersOnly;

@property (nonatomic) IBOutlet SRGLetterboxController *letterboxController;     // top-level object, retained
@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;
@property (nonatomic, weak) IBOutlet UIButton *closeButton;

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *nowLabel;
@property (nonatomic, weak) IBOutlet UILabel *nextLabel;

// Switching to and from full-screen is made by adjusting the priority / constance of a constraint of the letterbox
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *letterboxBottomConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *letterboxAspectRatioConstraint;

@property (nonatomic, getter=isTransitioningToFullScreen) BOOL wantsFullScreen;

@property (nonatomic) NSMutableArray<SRGSubdivision *> *favoritedSubdivisions;

@property (nonatomic) ModalTransition *interactiveTransition;

@end

@implementation ModalPlayerViewController

#pragma mark Object lifecycle

- (instancetype)initWithURN:(SRGMediaURN *)URN chaptersOnly:(BOOL)chaptersOnly
{
    SRGLetterboxService *service = [SRGLetterboxService sharedService];
    
    // If an equivalent view controller was dismissed for picture in picture of the same media, simply restore it
    if (service.controller.pictureInPictureActive && [service.pictureInPictureDelegate isKindOfClass:[self class]] && [service.controller.URN isEqual:URN]) {
        return (ModalPlayerViewController *)service.pictureInPictureDelegate;
    }
    // Otherwise instantiate a fresh new one
    else {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass([self class]) bundle:nil];
        ModalPlayerViewController *viewController = [storyboard instantiateInitialViewController];
        viewController.favoritedSubdivisions = [NSMutableArray array];
        viewController.URN = URN;
        viewController.chaptersOnly = chaptersOnly;
        return viewController;
    }
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.closeButton.accessibilityLabel = SRGLetterboxDemoAccessibilityLocalizedString(@"Close", @"Close button label");
    
    // Use custom modal transition
    self.transitioningDelegate = self;
    
    [[SRGLetterboxService sharedService] enableWithController:self.letterboxController pictureInPictureDelegate:self];
    
    // Start with a hidden interface
    [self.letterboxView setUserInterfaceHidden:YES animated:NO togglable:YES];
    
    // Always display the full-screen interface in landscape orientation
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    BOOL isLandscape = UIDeviceOrientationIsValidInterfaceOrientation(deviceOrientation) ? UIDeviceOrientationIsLandscape(deviceOrientation) : UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
    [self.letterboxView setFullScreen:isLandscape animated:NO];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(metadataDidChange:)
                                                 name:SRGLetterboxMetadataDidChangeNotification
                                               object:self.letterboxController];
    
    [self.letterboxController playURN:self.URN withChaptersOnly:self.chaptersOnly];
    
    [self reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if ([self isMovingFromParentViewController] || [self isBeingDismissed]) {
        if (! self.letterboxController.pictureInPictureActive) {
            [[SRGLetterboxService sharedService] disableForController:self.letterboxController];
        }
    }
}

#pragma mark Rotation

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        BOOL isLandscape = (size.width > size.height);
        [self.letterboxView setFullScreen:isLandscape animated:NO];
    } completion:nil];
}

#pragma mark Data

- (void)reloadData
{
    [self reloadDataOverriddenWithMedia:nil];
}

- (void)reloadDataOverriddenWithMedia:(SRGMedia *)media
{
    if (! media) {
        media = self.letterboxController.subdivisionMedia;
    }
    
    self.titleLabel.text = media.title;
    
    SRGChannel *channel = self.letterboxController.channel;
    self.nowLabel.text = channel.currentProgram.title ? [NSString stringWithFormat:NSLocalizedString(@"Now: %@", nil), channel.currentProgram.title] : nil;
    self.nextLabel.text = channel.nextProgram.title ? [NSString stringWithFormat:NSLocalizedString(@"Next: %@", nil), channel.nextProgram.title] : nil;
}

#pragma mark SRGLetterboxPictureInPictureDelegate protocol

- (BOOL)letterboxDismissUserInterfaceForPictureInPicture
{
    [self dismissViewControllerAnimated:YES completion:nil];
    return YES;
}

- (BOOL)letterboxShouldRestoreUserInterfaceForPictureInPicture
{
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.topViewController;
    return topViewController != self;
}

- (void)letterboxRestoreUserInterfaceForPictureInPictureWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.topViewController;
    [topViewController presentViewController:self animated:YES completion:^{
        completionHandler(YES);
    }];
}

- (void)letterboxDidStartPictureInPicture
{
    [[SRGAnalyticsTracker sharedTracker] trackHiddenEventWithTitle:@"pip_start"];
}

- (void)letterboxDidEndPictureInPicture
{
    [[SRGAnalyticsTracker sharedTracker] trackHiddenEventWithTitle:@"pip_end"];
}

- (void)letterboxDidStopPlaybackFromPictureInPicture
{
    [[SRGLetterboxService sharedService] disableForController:self.letterboxController];
}

#pragma mark SRGLetterboxViewDelegate protocol

- (void)letterboxViewWillAnimateUserInterface:(SRGLetterboxView *)letterboxView
{
    [self.view layoutIfNeeded];
    [letterboxView animateAlongsideUserInterfaceWithAnimations:^(BOOL hidden, CGFloat heightOffset) {
        self.letterboxAspectRatioConstraint.constant = heightOffset;
        self.closeButton.alpha = (hidden && ! self.letterboxController.error && self.letterboxController.URN) ? 0.f : 1.f;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didScrollWithSubdivision:(SRGSubdivision *)subdivision time:(CMTime)time interactive:(BOOL)interactive
{
    if (interactive) {
        SRGMedia *media = subdivision ? [self.letterboxController.mediaComposition mediaForSubdivision:subdivision] : self.letterboxController.fullLengthMedia;
        [self reloadDataOverriddenWithMedia:media];
    }
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView toggleFullScreen:(BOOL)fullScreen animated:(BOOL)animated withCompletionHandler:(nonnull void (^)(BOOL))completionHandler
{
    static const UILayoutPriority LetterboxViewConstraintLessPriority = 850;
    static const UILayoutPriority LetterboxViewConstraintMorePriority = 950;
    
    void (^animations)(void) = ^{
        if (fullScreen) {
            self.letterboxBottomConstraint.priority = LetterboxViewConstraintMorePriority;
            self.letterboxAspectRatioConstraint.priority = LetterboxViewConstraintLessPriority;
        }
        else {
            self.letterboxBottomConstraint.priority = LetterboxViewConstraintLessPriority;
            self.letterboxAspectRatioConstraint.priority = LetterboxViewConstraintMorePriority;
        }
    };
    
    self.wantsFullScreen = fullScreen;
    
    if (animated) {
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.2 animations:^{
            animations();
            [self.view layoutIfNeeded];
        } completion:completionHandler];
    }
    else {
        animations();
        completionHandler(YES);
    }
}

- (BOOL)letterboxViewShouldDisplayFullScreenToggleButton:(SRGLetterboxView *)letterboxView
{
    return UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
}

- (BOOL)letterboxView:(SRGLetterboxView *)letterboxView shouldDisplayFavoriteForSubdivision:(SRGSubdivision *)subdivision
{
    return [self.favoritedSubdivisions containsObject:subdivision];
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didLongPressSubdivision:(SRGSubdivision *)subdivision
{
    if ([self.favoritedSubdivisions containsObject:subdivision]) {
        [self.favoritedSubdivisions removeObject:subdivision];
    }
    else {
        [self.favoritedSubdivisions addObject:subdivision];
    }
}

#pragma mark UIGestureRecognizerDelegate protocol

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ! [touch.view isKindOfClass:[UISlider class]];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return [otherGestureRecognizer.view isKindOfClass:[UIScrollView class]];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return [otherGestureRecognizer isKindOfClass:[SRGActivityGestureRecognizer class]];
}

#pragma mark UIViewControllerTransitioningDelegate protocol

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return [[ModalTransition alloc] initForPresentation:YES];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return [[ModalTransition alloc] initForPresentation:NO];
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator
{
    // Return the installed interactive transition, if any
    return self.interactiveTransition;
}

#pragma mark Actions

- (IBAction)close:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)hideControls:(id)sender
{
    [self.letterboxView setUserInterfaceHidden:YES animated:YES togglable:YES];
}

- (IBAction)showControls:(id)sender
{
    [self.letterboxView setUserInterfaceHidden:NO animated:YES togglable:YES];
}

- (IBAction)forceHideControls:(id)sender
{
    [self.letterboxView setUserInterfaceHidden:YES animated:YES togglable:NO];
}

- (IBAction)forceShowControls:(id)sender
{
    [self.letterboxView setUserInterfaceHidden:NO animated:YES togglable:NO];
}

- (IBAction)fullScreen:(id)sender
{
    [self.letterboxView setFullScreen:YES animated:YES];
}

- (IBAction)toggleAlwaysHideTimeline:(UISwitch *)sender
{
    [self.letterboxView setTimelineAlwaysHidden:sender.on animated:YES];
}

- (IBAction)pullDown:(UIPanGestureRecognizer *)panGestureRecognizer
{
    CGFloat progress = [panGestureRecognizer translationInView:self.view].y / CGRectGetHeight(self.view.frame);
    
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            // Avoid duplicate dismissal (which can make it impossible to dismiss the view controller altogether)
            if (self.interactiveTransition) {
                return;
            }
            
            // Install the interactive transition animation before triggering it
            self.interactiveTransition = [[ModalTransition alloc] initForPresentation:NO];
            [self dismissViewControllerAnimated:YES completion:^{
                // Only stop tracking the interactive transition at the very end. The completion block is called
                // whether the transition ended or was cancelled
                self.interactiveTransition = nil;
            }];
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            [self.interactiveTransition updateInteractiveTransitionWithProgress:progress];
            break;
        }
            
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled: {
            [self.interactiveTransition cancelInteractiveTransition];
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            // Finish the transition if the view was dragged by 20% and the user is dragging downwards
            CGFloat velocity = [panGestureRecognizer velocityInView:self.view].y;
            if (progress > 0.2f && velocity >= 0.f) {
                [self.interactiveTransition finishInteractiveTransition];
            }
            else {
                [self.interactiveTransition cancelInteractiveTransition];
            }
            break;
        }
            
        default: {
            break;
        }
    }
}

#pragma mark Notifications

- (void)metadataDidChange:(NSNotification *)notification
{
    [self reloadDataOverriddenWithMedia:nil];
}

@end
