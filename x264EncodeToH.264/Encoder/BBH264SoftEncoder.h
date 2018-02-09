//
//  BBH264Encoder.h
//  x264EncodeToH.264
//
//  Created by ibabyblue on 2018/2/9.
//  Copyright © 2018年 ibabyblue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@class BBVideoConfig;

@interface BBH264SoftEncoder : NSObject

/**
 初始化编码参数

 @param config 编码所需配置
 */
- (void)setupEncodeWithConfig:(BBVideoConfig *)config;

/**
 编码

 @param sampleBuffer 摄像头捕获的数据格式
 */
- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer;

/**
 设置h264文件保存地址

 @param filePath 文件地址
 */
- (void)setFilePath:(NSString *)filePath;
/*
 * 释放资源
 */
- (void)freeX264Resource;
@end
