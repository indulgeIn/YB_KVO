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

static NSString * setterNameFromGetterName(NSString *getterName) {
    if (getterName.length < 1) {
        return nil;
    }
    NSString *setterName;
    setterName = [getterName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[getterName substringToIndex:1] uppercaseString]];
    setterName = [NSString stringWithFormat:@"set%@:", setterName];
    return setterName;
}
static NSString * getterNameFromSetterName(NSString *setterName) {
    if (setterName.length < 1 || ![setterName hasPrefix:@"set"] || ![setterName hasSuffix:@":"]) {
        return nil;
    }
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

static void yb_kvo_setter (id taget, SEL sel, id p0) {
    //拿到调用父类方法之前的值
    NSString *getterName = getterNameFromSetterName(NSStringFromSelector(sel));
    id old = [taget valueForKey:getterName];
    
    //给父类发送消息
    struct objc_super sup = {
        .receiver = taget,
        .super_class = class_getSuperclass(object_getClass(taget))
    };
    ((void(*)(struct objc_super *, SEL, id)) objc_msgSendSuper)(&sup, sel, p0);
    
    //回调相关
    //...
    
}


@interface YbKVOInfoModel : NSObject
@property (nonatomic, weak) id observer;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, assign) NSKeyValueObservingOptions options;
@end
@implementation YbKVOInfoModel
@end


@implementation NSObject (YB_KVO)

#pragma mark add
- (void)yb_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    if (!observer || !keyPath) {
        return;
    }
    @synchronized(self){
        NSMutableArray *targetArr = [NSMutableArray array];
        NSArray *keyArr = [keyPath componentsSeparatedByString:@"."];
        id nextTarget = self;
        //给 keyPath 所涉及的目标类做逻辑
        for (int i = 0; i < keyArr.count; i++) {
            if ([self yb_coreLogicWithTarget:nextTarget getterName:keyArr[i]]) {
                [targetArr addObject:nextTarget];
            } else {
                return;
            }
            if (i < keyArr.count-1) {
                nextTarget = [nextTarget valueForKey:keyArr[i]];
            }
        }
        //给所有目标类绑定信息
//        YbKVOInfoModel *infoModel = [YbKVOInfoModel new];
//        infoModel.observer = observer;
//        infoModel.keyPath = keyPath;
//        infoModel.options = options;
//        for (id target in targetArr) {
//            const void *key = (__bridge const void*)keyPath;
//            objc_setAssociatedObject(target, key, infoModel, OBJC_ASSOCIATION_RETAIN);
//        }
    }
}

- (BOOL)yb_coreLogicWithTarget:(id)target getterName:(NSString *)getterName {
    //若 setter 不存在
    NSString *setterName = setterNameFromGetterName(getterName);
    SEL setterSel = NSSelectorFromString(setterName);
    Method setterMethod = class_getInstanceMethod(object_getClass(target), setterSel);
    if (!setterMethod) {
        return NO;
    }
    
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





@end
