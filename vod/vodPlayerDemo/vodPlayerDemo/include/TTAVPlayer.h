//
//  TTVideoView.h
//  CoreIOS
//
//  Created by xun.liu on 14/11/20.
//  Copyright (c) 2014年 xun.liu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

//回调函数
typedef void (* VideoPlayerCallback)(void *, int, int);

@class PlayerView;
@interface TTAVPlayer : NSObject
{

}


@property (nonatomic, assign) VideoPlayerCallback videoPlayerCallback;    //c   函数callback
@property (nonatomic, assign) void* opaque;
@property (nonatomic, assign) int delay;                                  //设置超时时间



/**
 *    @brief  创建播放器
 *    @param url  播放源
 *    @return
 */
- (BOOL)videoPlayerCreateWithURL:(NSString *)url;

/**
 *    @brief  get player view
 *    @param
 *    @return
 */
- (PlayerView *)videoPlayerReceivePlayerView;

/**
 *    @brief  获取视频时长
 *    @param
 *    @return
 */
- (int)videoPlayerReceiveDuration:(double *) duration;

/**
 *    @brief  开始播放
 *    @param
 *    @return
 */
- (void)videoPlayerPlay;

/**
 *    @brief  暂停播放
 *    @param
 *    @return
 */
- (void)videoPlayerPause;

/**
 *    @brief  停止播放后调用
 *    @param
 *    @return
 */
- (void)videoPlayerStop;

/**
 *    @brief  获取播放进度
 *    @param
 *    @return 返回当前进度
 */
- (int)videoPlayerReceiveProgress:(double *)progress;

/**
 *    @brief  控制播放进度
 *    @param progressTime  给定进度，播放的时间点
 *    @return
 */
- (void)videoPlayerProgressHandle:(double )progress;

/**
 *    @brief  获取当前视频 缓冲 进度
 *    @param
 *    @return 返回当前视频 缓冲 进度
 */
- (int)videoPlayerReceiveBufferProgress:(double *)progress;

/**
 *    @brief  捕获某一时间点上的图像
 *    @param timePoint  指定时间点
 *    @return  捕获到的图片
 */
- (UIImage *)captureImage:(double)timePoint;

/**
 *    @brief  获取音量当前值
 *    @param
 *    @return  当前音量值  范围 0-1
 */
- (int)videoPlayerReceiveVolume:(float *)volume;

/**
 *    @brief  控制音量
 *    @param progressValue  给定音量  范围 0-1
 *    @return
 */
- (void)videoPlayerVolumeHandle:(float)volumeValue;

/**
 *    @brief  控制音量
 *    @param progressValue  给定音量  范围 0-1
 *    @return
 */
- (int)videoPlayerPlaybackSizeWithWidth:(float *)width height:(float *)height;



@end
