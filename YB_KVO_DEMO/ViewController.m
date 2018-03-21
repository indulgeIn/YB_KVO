//
//  ViewController.m
//  YB_KVO_DEMO
//
//  Created by 杨少 on 2018/3/19.
//  Copyright © 2018年 杨波. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+YB_KVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface TestObj:NSObject
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, strong) NSString *name;
@end
@implementation TestObj
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"%@ --- keyPath: %@, object: %@, change: %@, context: %@", self, keyPath, object, change, context);
}
- (void)setAge:(NSInteger)age {
    
    _age = age;
}
@end



@interface ViewController ()

@property (nonatomic, strong) TestObj *testObj;
@property (nonatomic, assign) NSInteger number;

@end

@implementation ViewController

@synthesize testObj = _testObj;

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self addObserver:self forKeyPath:@"testObj.name" options:NSKeyValueObservingOptionNew context:nil];
    [self yb_addObserver:self forKeyPath:@"testObj.name" options:NSKeyValueObservingOptionNew context:nil];
    
//    self.number = 2;
    self.testObj = [TestObj new];
//    self.testObj.name = @"a";
//    self.testObj.age = 10;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"%@ --- keyPath: %@, object: %@, change: %@, context: %@", self, keyPath, object, change, context);
}

- (void)yb_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@"%@ --- keyPath: %@, object: %@, change: %@, context: %@", self, keyPath, object, change, context);
}

#pragma mark getter setter
- (TestObj *)testObj {
    
    if (!_testObj) {
        _testObj = [TestObj new];
    }
    return _testObj;
}
- (void)setTestObj:(TestObj *)testObj {
    
    _testObj = testObj;
}


@end
