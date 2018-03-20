//
//  NSObject+YB_KVO.h
//  YB_KVO_DEMO
//
//  Created by 杨少 on 2018/3/19.
//  Copyright © 2018年 杨波. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (YB_KVO)

- (void)yb_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;
//- (void)yb_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(nullable void *)context;
//- (void)yb_yremoveObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;


- (void)yb_observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary*)change context:(nullable void *)context;

@end

NS_ASSUME_NONNULL_END
