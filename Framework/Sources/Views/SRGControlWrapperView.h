//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

@interface SRGControlWrapperView : UIView

/**
 *  Wrapped view which declared as the only accessibility element.
 *
 */
@property (nonatomic, weak) IBOutlet UIView *wrappedView;

/**
 *  When set to `YES`, force the view to be hidden / display like the wrapped view.
 *
 *  Default value is `NO`.
 */
@property (nonatomic, getter=isObservingWrappedViewHidden) IBInspectable BOOL observingWrappedViewHidden;

/**
 *  When set to `YES`, force the view to be always hidden, even if the wrapper view isn't empty.
 *
 *  Default value is `NO`.
 */
@property (nonatomic, getter=isAlwaysHidden) IBInspectable BOOL alwaysHidden;

@end
