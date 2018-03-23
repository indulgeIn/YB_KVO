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


const void *keyOfYbKVOInfoModel = &keyOfYbKVOInfoModel;
NSString *kPrefixOfYBKVO = @"kPrefixOfYBKVO_";


@interface YbKVOInfoModel : NSObject {
    void *_context;
}
- (void)setContext:(void *)context;
- (void *)getContext;
@property (nonatomic, weak) id target;
@property (nonatomic, weak) id observer;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, assign) YB_NSKeyValueObservingOptions options;
@end
@implementation YbKVOInfoModel
- (void)dealloc {
    _context = NULL;
}
- (void)setContext:(void *)context {
    _context = context;
}
- (void *)getContext {
    return _context;
}
@end


static NSString * setterNameFromGetterName(NSString *getterName) {
    if (getterName.length < 1) return nil;
    NSString *setterName;
    setterName = [getterName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[getterName substringToIndex:1] uppercaseString]];
    setterName = [NSString stringWithFormat:@"set%@:", setterName];
    return setterName;
}
static NSString * getterNameFromSetterName(NSString *setterName) {
    if (setterName.length < 1 || ![setterName hasPrefix:@"set"] || ![setterName hasSuffix:@":"]) return nil;
    NSString *getterName;
    getterName = [setterName substringWithRange:NSMakeRange(3, setterName.length-4)];
    getterName = [getterName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[getterName substringToIndex:1] lowercaseString]];
    return getterName;
}

static inline int classHasSel(Class class, SEL sel) {
    unsigned int outCount = 0;
    Method *methods = class_copyMethodList(class, &outCount);
    for (int i = 0; i < outCount; i++) {
        Method method = methods[i];
        SEL mSel = method_getName(method);
        if (mSel == sel) {
            free(methods);
            return 1;
        }
    }
    free(methods);
    return 0;
}

static void callBack (id taget, id nValue, id oValue, NSString *getterName, BOOL notificationIsPrior) {
    NSMutableDictionary *dic = objc_getAssociatedObject(taget, keyOfYbKVOInfoModel);
    if (dic && [dic valueForKey:getterName]) {
        NSMutableArray *tempArr = [dic valueForKey:getterName];
        for (YbKVOInfoModel *info in tempArr) {
            if (info && info.observer && [info.observer respondsToSelector:@selector(yb_observeValueForKeyPath:ofObject:change:context:)]) {
                NSMutableDictionary *change = [NSMutableDictionary dictionary];
                if (info.options & YB_NSKeyValueObservingOptionNew && nValue) {
                    [change setValue:nValue forKey:@"new"];
                }
                if (info.options & YB_NSKeyValueObservingOptionOld && oValue) {
                    [change setValue:oValue forKey:@"old"];
                }
                if (notificationIsPrior) {
                    if (info.options & YB_NSKeyValueObservingOptionPrior) {
                        [change setObject:@"1" forKey:@"notificationIsPrior"];
                    } else {
                        continue;
                    }
                }
                [info.observer yb_observeValueForKeyPath:info.keyPath ofObject:info.target change:change context:info.getContext];
            }
        }
    }
}

static void yb_kvo_setter (id taget, SEL sel, id p0) {
    //拿到调用父类方法之前的值
    NSString *getterName = getterNameFromSetterName(NSStringFromSelector(sel));
    id old = [taget valueForKey:getterName];
    callBack(taget, nil, old, getterName, YES);
    
    //给父类发送消息
    struct objc_super sup = {
        .receiver = taget,
        .super_class = class_getSuperclass(object_getClass(taget))
    };
    ((void(*)(struct objc_super *, SEL, id)) objc_msgSendSuper)(&sup, sel, p0);
    
    //回调相关
    callBack(taget, p0, old, getterName, NO);
}


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation NSObject (YB_KVO)
#pragma clang diagnostic pop

#pragma mark add
- (void)yb_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(YB_NSKeyValueObservingOptions)options context:(void *)context {
    if (!observer || !keyPath) return;
    
    @synchronized(self){
        //给 keyPath 链条最终类做逻辑
        NSArray *keyArr = [keyPath componentsSeparatedByString:@"."];
        if (keyArr.count <= 0) return;
        id nextTarget = self;
        for (int i = 0; i < keyArr.count-1; i++) {
            nextTarget = [nextTarget valueForKey:keyArr[i]];
        }
        if (![self yb_coreLogicWithTarget:nextTarget getterName:keyArr.lastObject]) {
            return;
        }
        //给目标类绑定信息
        YbKVOInfoModel *info = [YbKVOInfoModel new];
        info.target = self;
        info.observer = observer;
        info.keyPath = keyPath;
        info.options = options;
        [info setContext:context];
        [self yb_bindInfoToTarget:nextTarget info:info key:keyArr.lastObject options:options];
    }
}

- (void)yb_bindInfoToTarget:(id)target info:(YbKVOInfoModel *)info key:(NSString *)key options:(YB_NSKeyValueObservingOptions)options {
    NSMutableDictionary *dic = objc_getAssociatedObject(target, keyOfYbKVOInfoModel);
    if (dic) {
        if ([dic valueForKey:key]) {
            NSMutableArray *tempArr = [dic valueForKey:key];
            [tempArr addObject:info];
        } else {
            NSMutableArray *tempArr = [NSMutableArray array];
            [tempArr addObject:info];
            [dic setObject:tempArr forKey:key];
        }
    } else {
        NSMutableDictionary *addDic = [NSMutableDictionary dictionary];
        NSMutableArray *tempArr = [NSMutableArray array];
        [tempArr addObject:info];
        [addDic setObject:tempArr forKey:key];
        objc_setAssociatedObject(target, keyOfYbKVOInfoModel, addDic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (options & YB_NSKeyValueObservingOptionInitial) {
        callBack(target, nil, nil, key, NO);
    }
}

- (BOOL)yb_coreLogicWithTarget:(id)target getterName:(NSString *)getterName {
    //若 setter 不存在
    NSString *setterName = setterNameFromGetterName(getterName);
    SEL setterSel = NSSelectorFromString(setterName);
    Method setterMethod = class_getInstanceMethod(object_getClass(target), setterSel);
    if (!setterMethod) return NO;
    
    //创建派生类并且更改 isa 指针
    [self yb_creatSubClassWithTarget:target];
    
    //给派生类添加 setter 方法体
    if (!classHasSel(object_getClass(target), setterSel)) {
        const char *types = method_getTypeEncoding(setterMethod);
        return class_addMethod(object_getClass(target), setterSel, (IMP)yb_kvo_setter, types);
    }
    return YES;
}

- (void)yb_creatSubClassWithTarget:(id)target {
    //若 isa 指向是否已经是派生类
    Class nowClass = object_getClass(target);
    NSString *nowClass_name = NSStringFromClass(nowClass);
    if ([nowClass_name hasPrefix:kPrefixOfYBKVO]) {
        return;
    }
    
    //若派生类存在
    NSString *subClass_name = [kPrefixOfYBKVO stringByAppendingString:nowClass_name];
    Class subClass = NSClassFromString(subClass_name);
    if (subClass) {
        //将该对象 isa 指针指向派生类
        object_setClass(target, subClass);
        return;
    }
    
    //添加派生类，并且给派生类添加 class 方法体
    subClass = objc_allocateClassPair(nowClass, subClass_name.UTF8String, 0);
    const char *types = method_getTypeEncoding(class_getInstanceMethod(nowClass, @selector(class)));
    IMP class_imp = imp_implementationWithBlock(^Class(id target){
        return class_getSuperclass(object_getClass(target));
    });
    class_addMethod(subClass, @selector(class), class_imp, types);
    objc_registerClassPair(subClass);
    
    //将该对象 isa 指针指向派生类
    object_setClass(target, subClass);
}


#pragma mark remove
- (void)yb_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    [self yb_removeObserver:observer forKeyPath:keyPath context:nil];
}
- (void)yb_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context {
    @synchronized(self) {
        //移除配置信息
        NSArray *keyArr = [keyPath componentsSeparatedByString:@"."];
        if (keyArr.count <= 0) return;
        id nextTarget = self;
        for (int i = 0; i < keyArr.count-1; i++) {
            nextTarget = [nextTarget valueForKey:keyArr[i]];
        }
        NSString *getterName = keyArr.lastObject;
        NSMutableDictionary *dic = objc_getAssociatedObject(nextTarget, keyOfYbKVOInfoModel);
        if (dic && [dic valueForKey:getterName]) {
            NSMutableArray *tempArr = [dic valueForKey:getterName];
            @autoreleasepool {
                for (YbKVOInfoModel *info in tempArr.copy) {
                    if (info.getContext == context && info.observer == observer && [info.keyPath isEqualToString:keyPath]) {
                        [tempArr removeObject:info];
                    }
                }
            }
            if (tempArr.count == 0) {
                [dic removeObjectForKey:getterName];
            }
            //若无可监听项，isa 指针指回去
            if (dic.count <= 0) {
                Class nowClass = object_getClass(nextTarget);
                NSString *nowClass_name = NSStringFromClass(nowClass);
                if ([nowClass_name hasPrefix:kPrefixOfYBKVO]) {
                    Class superClass = [nextTarget class];
                    object_setClass(nextTarget, superClass);
                }
            }
        }
    }
}

@end
