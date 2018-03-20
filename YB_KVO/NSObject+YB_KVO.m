//
//  NSObject+YB_KVO.m
//  YB_KVO_DEMO
//
//  Created by 杨少 on 2018/3/19.
//  Copyright © 2018年 杨波. All rights reserved.
//

#import "NSObject+YB_KVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString *kPrefixOfYBKVO = @"kPrefixOfYBKVO_";

NSString * setterNameFromGetterName(NSString *getterName) {
    if (getterName.length < 1) {
        return nil;
    }
    NSString *setterName;
    setterName = [getterName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[getterName substringToIndex:1] uppercaseString]];
    setterName = [NSString stringWithFormat:@"set%@:", setterName];
    return setterName;
}
NSString * getterNameFromSetterName(NSString *setterName) {
    if (setterName.length < 1 || ![setterName hasPrefix:@"set"] || ![setterName hasSuffix:@":"]) {
        return nil;
    }
    NSString *getterName;
    getterName = [setterName substringWithRange:NSMakeRange(3, setterName.length-4)];
    getterName = [getterName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[getterName substringToIndex:1] lowercaseString]];
    return getterName;
}

void yb_kvo_setter (id observer, SEL sel, id p0) {
    
    NSString *getterName = getterNameFromSetterName(NSStringFromSelector(sel));
    id old = [observer valueForKey:getterName];
    
    //给父类发送消息
    struct objc_super sup = {
        .receiver = observer,
        .super_class = class_getSuperclass(object_getClass(observer))
    };
    ((void(*)(struct objc_super *, SEL, id)) objc_msgSendSuper)(&sup, sel, p0);
    
    //回调相关
    if ([observer respondsToSelector:@selector(yb_observeValueForKeyPath:ofObject:change:context:)]) {
        [observer yb_observeValueForKeyPath:@"test" ofObject:observer change:@{} context:nil];
    }
    
}

@implementation NSObject (YB_KVO)

#pragma mark add
- (void)yb_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    if (!observer || !keyPath) {
        return;
    }
    NSArray *keyArr = [keyPath componentsSeparatedByString:@"."];
    
    //遍历 keyArr ，逐个处理
    id nextObserver = observer;
    int i = 0;
    while (i < keyArr.count) {
        if (![self yb_observer:nextObserver getterName:keyArr[i]]) {
            return;
        }
        nextObserver = [nextObserver valueForKey:keyArr[i]];
        i++;
    }
}

- (BOOL)yb_observer:(id)observer getterName:(NSString *)getterName {
    //判断 setter 是否存在
    NSString *setterName = setterNameFromGetterName(getterName);
    SEL setterSel = NSSelectorFromString(setterName);
    Method setterMethod = class_getInstanceMethod(object_getClass(observer), setterSel);
    if (!setterMethod) {
        return NO;
    }
    
    //添加派生类
    [self yb_creatSubClassWithObserver:observer];
    
    //给派生类添加 setter 方法
    const char *types = method_getTypeEncoding(setterMethod);
    return class_addMethod(object_getClass(observer), setterSel, (IMP)yb_kvo_setter, types);
}

- (void)yb_creatSubClassWithObserver:(id)observer {
    //判断是否已经是派生类
    Class nowClass = object_getClass(observer);
    NSString *nowClass_name = NSStringFromClass(nowClass);
    if ([nowClass_name hasPrefix:kPrefixOfYBKVO]) {
        return;
    }
    
    //添加派生类，并且给派生类添加 class 方法
    NSString *subClass_name = [kPrefixOfYBKVO stringByAppendingString:nowClass_name];
    Class subClass = objc_allocateClassPair(nowClass, subClass_name.UTF8String, 0);
    const char *types = method_getTypeEncoding(class_getInstanceMethod(nowClass, @selector(class)));
    IMP class_imp = imp_implementationWithBlock(^Class(id target){
        return class_getSuperclass(object_getClass(target));
    });
    class_addMethod(subClass, @selector(class), class_imp, types);
    objc_registerClassPair(subClass);
    
    //核心操作，将该对象isa指针指向派生类
    object_setClass(observer, subClass);
}


#pragma mark remove





@end
