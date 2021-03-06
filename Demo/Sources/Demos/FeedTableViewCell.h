//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGDataProvider/SRGDataProvider.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_UNAVAILABLE(tvos)
@interface FeedTableViewCell : UITableViewCell

- (void)setMedia:(nullable SRGMedia *)media withPreferredSubtitleLocalization:(nullable NSString *)preferredSubtitleLocalization;

@property (nonatomic, getter=isMuted) BOOL muted;

@end

NS_ASSUME_NONNULL_END
