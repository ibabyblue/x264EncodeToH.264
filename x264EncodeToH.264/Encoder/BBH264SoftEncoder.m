//
//  BBH264Encoder.m
//  x264EncodeToH.264
//
//  Created by ibabyblue on 2018/2/9.
//  Copyright © 2018年 ibabyblue. All rights reserved.
//

#import "BBH264SoftEncoder.h"
#import "BBVideoConfig.h"
#import <stdint.h>
#import <inttypes.h>
#import "x264.h"

@implementation BBH264SoftEncoder{
    
    x264_t                  *pX264Handle;
    x264_param_t            *pX264Param;
    x264_picture_t          *pPicIn;
    x264_picture_t          *pPicOut;
    
    x264_nal_t              *pNals;
    int                      iNal;
    
    FILE                    *pFile;
    
    BBVideoConfig           *_config;
    
}

- (void)setupEncodeWithConfig:(BBVideoConfig *)config{
    
    _config = config;
    
    pX264Param = (x264_param_t *)malloc(sizeof(x264_param_t));
    assert(pX264Param);
    /* 配置参数预设置
     * 主要是zerolatency该参数，即时编码。
     * static const char * const x264_tune_names[] = { "film", "animation", "grain", "stillimage", "psnr", "ssim", "fastdecode", "zerolatency", 0 };
     */
    x264_param_default_preset(pX264Param, "veryfast", "zerolatency");
    
    /* 设置Profile.使用Baseline profile
     * static const char * const x264_profile_names[] = { "baseline", "main", "high", "high10", "high422", "high444", 0 };
     */
    x264_param_apply_profile(pX264Param, "baseline");
    
    // cpuFlags
    pX264Param->i_threads = X264_SYNC_LOOKAHEAD_AUTO; // 取空缓冲区继续使用不死锁的保证
    
    // 视频宽高
    pX264Param->i_width   = config.videoSize.width; // 要编码的图像宽度.
    pX264Param->i_height  = config.videoSize.height; // 要编码的图像高度
    pX264Param->i_frame_total = 0; //编码总帧数，未知设置为0
    
    // 流参数
    pX264Param->b_cabac = 0; //支持利用基于上下文的自适应的算术编码 0为不支持
    pX264Param->i_bframe = 5;//两个参考帧之间B帧的数量
    pX264Param->b_interlaced = 0;//隔行扫描
    pX264Param->rc.i_rc_method = X264_RC_ABR; // 码率控制，CQP(恒定质量)，CRF(恒定码率)，ABR(平均码率)
    pX264Param->i_level_idc = 30; // 编码复杂度
    
    // 图像质量
    pX264Param->rc.f_rf_constant = 15; // rc.f_rf_constant是实际质量，越大图像越花，越小越清晰
    pX264Param->rc.f_rf_constant_max = 45; // param.rc.f_rf_constant_max ，图像质量的最大值。
    
    // 速率控制参数 通常为屏幕分辨率*3 （宽x高x3）
    pX264Param->rc.i_bitrate = config.bitrate / 1000; // 码率(比特率), x264使用的bitrate需要/1000。
    // pX264Param->rc.i_vbv_max_bitrate=(int)((m_bitRate * 1.2) / 1000) ; // 平均码率模式下，最大瞬时码率，默认0(与-B设置相同)
    pX264Param->rc.i_vbv_buffer_size = pX264Param->rc.i_vbv_max_bitrate = (int)((config.bitrate * 1.2) / 1000);
    pX264Param->rc.f_vbv_buffer_init = 0.9;//默认0.9
    
    
    // 使用实时视频传输时，需要实时发送sps,pps数据
    pX264Param->b_repeat_headers = 1;  // 重复SPS/PPS 放到关键帧前面。该参数设置是让每个I帧都附带sps/pps。
    
    // 帧率
    pX264Param->i_fps_num  = config.fps; // 帧率分子
    pX264Param->i_fps_den  = 1; // 帧率分母
    pX264Param->i_timebase_den = pX264Param->i_fps_num;
    pX264Param->i_timebase_num = pX264Param->i_fps_den;
    
    /* I帧间隔 GOP
     * 一般为帧率的整数倍，通常设置2倍，即 GOP = 帧率 * 2；
     * GOP的大小设置和首屏秒开优化有关系。
     */
    pX264Param->b_intra_refresh = 1;
    pX264Param->b_annexb = 1;
    pX264Param->i_keyint_max = config.fps * 2;
    
    
    // Log参数，打印编码信息
    pX264Param->i_log_level  = X264_LOG_DEBUG;
    
    // 编码需要的辅助变量
    iNal = 0;
    pNals = NULL;
    
    pPicIn = (x264_picture_t *)malloc(sizeof(x264_picture_t));
    memset(pPicIn, 0, sizeof(x264_picture_t));
    x264_picture_alloc(pPicIn, X264_CSP_I420, pX264Param->i_width, pX264Param->i_height);
    pPicIn->i_type = X264_TYPE_AUTO;
    pPicIn->img.i_plane = 3;
    
    pPicOut = (x264_picture_t *)malloc(sizeof(x264_picture_t));
    memset(pPicOut, 0, sizeof(x264_picture_t));
    x264_picture_init(pPicOut);
    
    // 打开编码器句柄,通过x264_encoder_parameters得到设置给X264
    // 的参数.通过x264_encoder_reconfig更新X264的参数
    pX264Handle = x264_encoder_open(pX264Param);
    assert(pX264Handle);
    
}

- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer{
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
    UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    size_t bytesrow0 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
    size_t bytesrow1  = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
    
    UInt8 *yuv420_data = (UInt8 *)malloc(width * height *3/ 2);//buffer to store YUV with layout YYYYYYYYUUVV
    
    
    /* convert NV12 data to YUV420*/
    UInt8 *pY = bufferPtr ;
    UInt8 *pUV = bufferPtr1;
    UInt8 *pU = yuv420_data + width * height;
    UInt8 *pV = pU + width * height / 4;
    for(int i = 0; i < height; i++)
    {
        memcpy(yuv420_data + i * width, pY + i * bytesrow0, width);
    }
    for(int j = 0;j < height/2; j++)
    {
        for(int i = 0; i < width/2; i++)
        {
            *(pU++) = pUV[i<<1];
            *(pV++) = pUV[(i<<1) + 1];
        }
        pUV += bytesrow1;
    }
    
    // yuv420_data <==> pInFrame
    pPicIn->img.plane[0] = yuv420_data;
    pPicIn->img.plane[1] = pPicIn->img.plane[0] + (int)_config.videoSize.width * (int)_config.videoSize.height;
    pPicIn->img.plane[2] = pPicIn->img.plane[1] + (int)(_config.videoSize.width * _config.videoSize.height / 4);
    pPicIn->img.i_stride[0] = _config.videoSize.width;
    pPicIn->img.i_stride[1] = _config.videoSize.width / 2;
    pPicIn->img.i_stride[2] = _config.videoSize.width / 2;
    
    // 编码
    int frame_size = x264_encoder_encode(pX264Handle, &pNals, &iNal, pPicIn, pPicOut);
    
    // 将编码数据写入文件
    if(frame_size > 0) {
        
        for (int i = 0; i < iNal; ++i)
        {
            fwrite(pNals[i].p_payload, 1, pNals[i].i_payload, pFile);
        }
        
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

- (void)setFilePath:(NSString *)path{
    char *filePath = [self private_nsstring2char:path];
    pFile = fopen(filePath, "wb");
}

- (void)freeX264Resource{
    // 清除图像区域
    x264_picture_clean(pPicIn);
    // 关闭编码器句柄
    x264_encoder_close(pX264Handle);
    pX264Handle = NULL;
    free(pPicIn);
    pPicIn = NULL;
    free(pPicOut);
    pPicOut = NULL;
    free(pX264Param);
    pX264Param = NULL;
    fclose(pFile);
    pFile = NULL;
}
#pragma mark - 私有方法
/**将路径转成C语言字符串*/
- (char*)private_nsstring2char:(NSString *)path{
    
    NSUInteger len = [path length];
    char *filepath = (char*)malloc(sizeof(char) * (len + 1));
    
    [path getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    
    return filepath;
}
@end
