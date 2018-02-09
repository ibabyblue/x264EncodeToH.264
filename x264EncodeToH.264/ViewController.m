//
//  ViewController.m
//  x264EncodeToH.264
//
//  Created by ibabyblue on 2018/2/9.
//  Copyright © 2018年 ibabyblue. All rights reserved.
//

#import "ViewController.h"
#import "BBVideoCapture.h"

@interface ViewController ()
@property (nonatomic, strong) BBVideoCapture *capture;
@end

@implementation ViewController

- (BBVideoCapture *)capture{
    if (_capture == nil) {
        _capture = [[BBVideoCapture alloc] init];
    }
    return _capture;
}

- (IBAction)startEncode:(id)sender {
    [self.capture startCapture:self.view];
}
- (IBAction)stopEncode:(id)sender {
    [self.capture stopCapture];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
