//
//  CMAttributedStringRenderResult.h
//  CocoaMarkdown
//
//  Created by Jake Bellamy on 16/06/17.
//  Copyright © 2017 Indragie Karunaratne. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface CMAttributedStringRenderResult : NSObject

@property (nonatomic, readonly, copy) NSAttributedString *result;
@property (nonatomic, readonly, copy) NSArray<NSValue *> *blockQuoteRanges;

- (instancetype)initWithResult:(NSAttributedString *)result
              blockQuoteRanges:(NSArray<NSValue *> *)blockQuoteRanges;

@end

NS_ASSUME_NONNULL_END
