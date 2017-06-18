//
//  CMHTMLStrikethroughTransformer.h
//  CocoaMarkdown
//
//  Created by Indragie on 1/16/15.
//  Copyright (c) 2015 Indragie Karunaratne. All rights reserved.
//

@import Foundation;
#import "CMHTMLElementTransformer.h"
#import "CMPlatformDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Transforms HTML strikethrough elements (<s>) into attributed strings.
 */
@interface CMHTMLStrikethroughTransformer : NSObject <CMHTMLElementTransformer>

/**
 *  Initializes the receiver with the default attributes -- a single line
 *  style and a color that matches the color of the text.
 *
 *  @return An initialized instance of the receiver.
 */
- (instancetype)init;

/**
 *  Initializes the receiver with a custom style and color.
 *
 *  @param style Strikethrough style.
 *  @param color Strikethrough color. If `nil`, the transformer uses
 *  the color of the text if it has been specified.
 *
 *  @return An initialized instance of the receiver.
 */
- (instancetype)initWithStrikethroughStyle:(CMUnderlineStyle)style color:(CMColor * _Nullable)color;

@end

NS_ASSUME_NONNULL_END
