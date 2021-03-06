//
//  TTVideoView.m
//  CoreIOS
//
//  Created by xun.liu on 14/11/20.
//  Copyright (c) 2014年 xun.liu. All rights reserved.
//  lx_xi163@163.com

#import "TTAVPlayer.h"
#import <MediaPlayer/MediaPlayer.h>
#import "PlayerView.h"

#define TIME_INTERVAL 10

//block
typedef void (^IsCreateSuccessBlock)(int block);

@interface TTAVPlayer ()
{
    AVPlayerItem *_avPlayerItem;
    AVAsset *_avAsset;
    
    
    CGFloat _totalVideoDuration;    //当前视频总时间
    CGFloat _currentDuration;       //当前视频的当前时间
    BOOL    _isPlaying;             //是否处在播放状态
    double  _bufferTime;            //缓冲时间
    BOOL    _isDestroy;             //是否已经销毁
    int     _num;                   //用来计时超时
    int     _seekNum;
    
    float x;
    float y;
}

@property (nonatomic, assign) BOOL isSuccess;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic ,strong) id playbackTimeObserver;
@property (nonatomic, strong) IsCreateSuccessBlock isCreateSuccessBlock;  //oc  block
@property (nonatomic, assign) int flag;
@property (nonatomic, strong) PlayerView *avplayer;

@end


@implementation TTAVPlayer

- (void)dealloc
{
    NSLog(@"dealloc----TTAVPlayer");
}

- (id)init
{
    self = [super init];
    if (self) {
        
        _avplayer = [[PlayerView alloc] init];

        _totalVideoDuration = 0;
        _currentDuration = 0;
        _bufferTime = 0;
        _isSuccess = NO;
        _isDestroy = NO;
        _isSeeking = NO;
        _seekNum = 0;
    }
    
    return self;
}

/* Cancels the previously registered time observer. */
- (void)removePlayerTimeObserver
{
    if (_playbackTimeObserver) {
        [_avplayer.player removeTimeObserver:_playbackTimeObserver];
        _playbackTimeObserver = nil;
    }
}

- (void)initVideoPlayer:(NSString *)url
{
    NSURL *URL;
    NSRange range = [url rangeOfString:@"http"];
    if (range.location == NSNotFound) {   //url中不包含http
        URL = [NSURL fileURLWithPath:url];
    }
    else {
        URL = [NSURL URLWithString:url];
    }
    
    _avAsset = [AVURLAsset URLAssetWithURL:URL options:nil];
    
    //使用playerItem获取视频的信息，当前播放时间，总时间等
    if (_avPlayerItem) {
        /* Remove existing player item key value observers and notifications. */
        [_avPlayerItem removeObserver:self forKeyPath:@"status"];
        [_avPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    }
    _avPlayerItem  = [AVPlayerItem playerItemWithAsset:_avAsset];
    [_avPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [_avPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoPlayerDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    //player是视频播放的控制器，可以用来快进播放，暂停等
    if (!_avplayer.player) {
        AVPlayer *player = [AVPlayer playerWithPlayerItem:_avPlayerItem];
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:_avplayer.player];
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [_avplayer setPlayer:player];
        
        //允许线控
        _avplayer.player.allowsAirPlayVideo = YES;
        
        //观察 player 状态变化   KVO / NSNotification
        [_avplayer.player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
    }
    

    _isPlaying = YES;

    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (_avplayer.player.currentItem != _avPlayerItem) {
        [_avplayer.player replaceCurrentItemWithPlayerItem:_avPlayerItem];
    }
}

//KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        if (playerItem.status == AVPlayerStatusReadyToPlay) {
            //视频加载成功
            CMTime totalTime = playerItem.duration;
            _totalVideoDuration = (CGFloat)totalTime.value/totalTime.timescale;
            [self monitorVideoProgress:_avPlayerItem];
            
            //block
            _isCreateSuccessBlock(1);
            _isSuccess = YES;
        }
        else if (playerItem.status == AVPlayerStatusFailed) {
            NSError *error = playerItem.error;
            NSLog(@"AVPlayerStatusFailed error = %@", error);
            
            //block
            if (!_isSuccess) {
                _isCreateSuccessBlock(0);
            }
            //回调函数
            if (_videoPlayerCallback) {
                _videoPlayerCallback(_opaque, 1, 1);
            }
            
            return;
        }
        else if (playerItem.status == AVPlayerStatusUnknown) {

            //block
            if (!_isSuccess) {
                _isCreateSuccessBlock(0);
            }
            //回调函数
            if (_isSuccess && _videoPlayerCallback) {
                _videoPlayerCallback(_opaque, 2, 1);
            }
            return;
        }
    }
    
    if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        //缓冲
        _bufferTime = [self availableDuration];
        //缓冲进度回调
        int result = _bufferTime*1000;
        if (_isSuccess && _videoPlayerCallback) {
            _videoPlayerCallback(_opaque, result, 3);
        }
        
        //因网络原因导致播放不动处理
        //获取当前时间
        CMTime currentTime = _avPlayerItem.currentTime;
        //转成秒数
        _currentDuration = (CGFloat)currentTime.value/currentTime.timescale;
        if (_avplayer.player.rate==0 && _isPlaying) {
            [_avplayer.player play];
        }
        
    }
    
    if ([keyPath isEqualToString:@"rate"]) {
        if (_isSuccess && _videoPlayerCallback) {
            _videoPlayerCallback(_opaque, (int)_avplayer.player.rate, 5);
        }
        NSLog(@"----rate = %f", _avplayer.player.rate);
    }
}


//当前视频总时间
- (CMTime)playerItemDuration
{
    AVPlayerItem *playerItem = [_avplayer.player currentItem];
    if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
        return ([playerItem duration]);
    }
    
    return kCMTimeInvalid;
}

//反应播放进度方法
- (void)monitorVideoProgress:(AVPlayerItem *)playerItem
{
    __weak __block TTAVPlayer *this = self;
    //参数CMTimeMake(1, 1) 反应检测频率
    self.playbackTimeObserver = [_avplayer.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        double currentSecond = playerItem.currentTime.value/playerItem.currentTime.timescale;
        //回调
        int result = currentSecond*1000+1;
        if (this.isSuccess && this.videoPlayerCallback && !this.isSeeking) {
            this.videoPlayerCallback(this.opaque, result, 2);
        }
    }];
}

//播放完成通知方法
- (void)videoPlayerDidEnd:(NSNotification *)notification
{
    //回调
    if (_isSuccess && _videoPlayerCallback) {
        _videoPlayerCallback(_opaque, 0, 4);
    }
}

//加载缓冲进度
- (float)availableDuration
{
    NSArray *loadedTimeRange = [[_avplayer.player currentItem] loadedTimeRanges];
    if ([loadedTimeRange count] > 0) {
        CMTimeRange timeRange = [[loadedTimeRange objectAtIndex:0] CMTimeRangeValue];
        float startSeconds = CMTimeGetSeconds(timeRange.start);
        float durationSeconds = CMTimeGetSeconds(timeRange.duration);
        
        return (startSeconds + durationSeconds);
    }
    else {
        return 0.0f;
    }
}

/*
#pragma mark - Touch action - time / volume progress
//触摸滑动 快进
- (void)touchSpeed
{
    //获取当前时间
    CMTime currentTime = _avplayer.player.currentItem.currentTime;
    //转成秒数
    _currentDuration = (CGFloat)currentTime.value/currentTime.timescale;
    CGFloat newTime = _currentDuration + TIME_INTERVAL;
    if (newTime >= _totalVideoDuration) {
        return;
    }
    
    [self speed:TIME_INTERVAL];
}

//触摸滑动 后退 进度
- (void)touchRetreat
{
    //获取当前时间
    CMTime currentTime = _avplayer.player.currentItem.currentTime;
    //转成秒数
    _currentDuration = (CGFloat)currentTime.value/currentTime.timescale;
    
    [self retreat:TIME_INTERVAL];
}

//触摸滑动 音量 减小
- (void)touchVolumeSub
{
    MPMusicPlayerController *mpc = [MPMusicPlayerController applicationMusicPlayer];
    if ((mpc.volume - 0.01) <= 0) {
        mpc.volume = 0;
    }
    else {
        mpc.volume = mpc.volume - 0.01;
    }
}

//触摸滑动 音量 增加
- (void)touchVolumeAdd
{
    MPMusicPlayerController *mpc = [MPMusicPlayerController applicationMusicPlayer];
    if ((mpc.volume + 0.01) >= 1) {
        mpc.volume = 1;
    }
    else {
        mpc.volume = mpc.volume + 0.01;
    }
}


- (void)speed:(float)timeInterval
{
    CGFloat newTime = _currentDuration + timeInterval;
    if (newTime >= _totalVideoDuration) {
        if (_isPlaying) {
            [_avplayer.player play];
        }
        return;
    }
    
    [_avplayer.player pause];
    //转换成CMTime才能给player控制播放进度
    CMTime dragedCMTime = CMTimeMake(newTime, 1);
    [_avplayer.player seekToTime:dragedCMTime completionHandler:^(BOOL finished) {
        if (_isPlaying) {
            [_avplayer.player play];
        }
    }];
    
//    _isPlaying = YES;
}

- (void)retreat:(float)timeInterval
{
    CGFloat newTime = _currentDuration - timeInterval;
    if (newTime <= 0.0) {
        if (_isPlaying == YES) {
            [_avplayer.player play];
        }
        
        newTime = 0.0;
    }
    
    [_avplayer.player pause];
    //转换成CMTime才能给player控制播放进度
    CMTime dragedCMTime = CMTimeMake(newTime, 1);
    [_avplayer.player seekToTime:dragedCMTime completionHandler:^(BOOL finished) {
        if (_isPlaying) {
            [_avplayer.player play];
        }
    }];
    
//    _isPlaying = YES;
}


#pragma mark - Touch responder
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    NSLog(@"began pointX%f-----pointY%f",touchPoint.x,touchPoint.y);
    x = (touchPoint.x);
    y = (touchPoint.y);
    
//    [self.player pause];
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    NSLog(@"end pointX%f-----pointY%f",touchPoint.x,touchPoint.y);
    
//    //快进
//    if ((touchPoint.x - x) >= 50 && (touchPoint.y - y) <= 20 && (touchPoint.y - y) >= -20) {
//        NSLog(@"快进");
//        [self touchSpeed];
//    }
//    
//    if ((touchPoint.x - x) >= 50 && (y - touchPoint.y) <= 50 && (y - touchPoint.y) >= -50) {
//        NSLog(@"快进");
//        [self touchSpeed];
//    }
//    
//    //快退
//    if ((x - touchPoint.x) >= 50 && (touchPoint.y - y) <= 50 && (touchPoint.y - y) >= -50) {
//        NSLog(@"快退");
//        [self touchRetreat];
//        
//    }
//    
//    if ((x - touchPoint.x) >= 50 && (y - touchPoint.y) <= 50 && (y - touchPoint.y) >= -50) {
//        NSLog(@"快退");
//        [self touchRetreat];
//    }
    
    
    //音量
    if ((touchPoint.y - y) >= 50 && (touchPoint.x - x) <= 50 && (touchPoint.x - x) >= -50) {
        NSLog(@"减小音量");
        [self touchVolumeSub];
    }
    
    if ((y - touchPoint.y) >= 50) {
        NSLog(@"音量加大");
        [self touchVolumeAdd];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    NSLog(@"end pointX%f-----pointY%f",touchPoint.x,touchPoint.y);
    
    //快进
    if ((touchPoint.x - x) >= 50 && (touchPoint.y - y) <= 20 && (touchPoint.y - y) >= -20) {
        NSLog(@"快进");
//        [self touchSpeed];
    }
    
    if ((touchPoint.x - x) >= 50 && (y - touchPoint.y) <= 50 && (y - touchPoint.y) >= -50) {
        NSLog(@"快进");
//        [self touchSpeed];
    }
    
    //快退
    if ((x - touchPoint.x) >= 50 && (touchPoint.y - y) <= 50 && (touchPoint.y - y) >= -50) {
        NSLog(@"快退");
//        [self touchRetreat];
        
    }
    
    if ((x - touchPoint.x) >= 50 && (y - touchPoint.y) <= 50 && (y - touchPoint.y) >= -50) {
        NSLog(@"快退");
//        [self touchRetreat];
    }
}
*/

#pragma mark - External Method

//创建播放
- (BOOL)videoPlayerCreateWithURL:(NSString *)url
{
    [self initVideoPlayer:url];
    
    _num = 0;
    _flag = 0;
    __weak __block TTAVPlayer *this = (TTAVPlayer *)self;
    _isCreateSuccessBlock = ^(int block) {
        if (block == 1) {
            NSLog(@"create success");
            this.flag = 1;
        }
        else {
            this.flag = 2;
            [this videoPlayerStop];
        }
    };
    
    //延迟调用   规定阻塞时间
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        while (_flag == 0) {
            
            if (_num == _delay) {
                _flag= 3;
                [self videoPlayerStop];
    
            }
            
            sleep(1);
            _num ++;
        }
    });
    
    //阻塞当前线程
    while (_flag == 0) {
//        NSLog(@"runloop.....");
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
//        NSLog(@"runloop end");
    }
    
    if (_flag == 1) {
        return YES;
    }
    else {
        return NO;
    }
}


//获取playerView
- (PlayerView *)videoPlayerReceivePlayerView
{
    return _avplayer;
}


//获取视频时长
- (int)videoPlayerReceiveDuration:(double *)duration
{
    *duration = _totalVideoDuration;
    return 0;
}

//开始播放
- (void)videoPlayerPlay
{
    _isPlaying = YES;
    [_avplayer.player play];
}

//暂停播放
- (void)videoPlayerPause
{
    _isPlaying = NO;
    [_avplayer.player pause];
}

//播放停止
- (void)videoPlayerStop
{
    if (_isDestroy == YES) {
        return;
    }
    
    [_avplayer.player replaceCurrentItemWithPlayerItem:nil];
    //释放播放完成的通知和KVO
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [_avPlayerItem removeObserver:self forKeyPath:@"status" context:nil];
    [_avPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    [_avplayer.player removeObserver:self forKeyPath:@"rate" context:nil];
    [_avplayer.player removeTimeObserver:_playbackTimeObserver];
    _avAsset = nil;
    _avPlayerItem = nil;
    _isCreateSuccessBlock = nil;
    _isSuccess = NO;
    _isDestroy = YES;
    _flag = 2;
}

//获取当前 播放 进度
- (int)videoPlayerReceiveProgress:(double *)progress
{
    //获取当前时间
    CMTime currentTime = _avPlayerItem.currentTime;
    //转成秒数
    _currentDuration = (CGFloat)currentTime.value/currentTime.timescale;
    
    *progress = (double)_currentDuration;

    return 0;
}

//控制 播放 进度
- (void)videoPlayerProgressHandle:(double)progress
{
    NSLog(@"seek begin ---------");
    _seekNum = _seekNum + 1;
    //转换成CMTime才能给player控制播放进度
    _isSeeking = YES;
    [_avplayer.player setRate:0];
    CMTime dragedCMTime = CMTimeMake(progress, 1);
    [_avplayer.player seekToTime:dragedCMTime completionHandler:^(BOOL finished) {
        _isSeeking = NO;
        _seekNum = _seekNum - 1;
        if (_isPlaying == YES) {
            NSLog(@"seek finish =============");
            if (_seekNum == 0) {
                NSLog(@"seek rate 1 -=-=-=-=-=-");
                [_avplayer.player setRate:1];
            }
        }
    }];
    
//    [self removePlayerTimeObserver];
//    [_avplayer.player seekToTime:dragedCMTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
//        _isSeeking = NO;
////        [self monitorVideoProgress:_avPlayerItem];
//        if (_isPlaying == YES) {
//            [_avplayer.player setRate:1];
//        }
//    }];
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        
//    });
}

//获取当前 缓冲 进度
- (int)videoPlayerReceiveBufferProgress:(double *)progress
{
    *progress = _bufferTime;
    return 0;
}

//捕获图片
- (UIImage *)captureImage:(double)timePoint
{
    AVAssetImageGenerator *assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:_avAsset];
    CMTime pointCMTime = CMTimeMakeWithSeconds(timePoint, 1);
    CMTime actualTime;
    NSError *error;
    CGImageRef imageRef = [assetImageGenerator copyCGImageAtTime:pointCMTime actualTime:&actualTime error:&error];
    if (imageRef != NULL) {
        UIImage *img = [UIImage imageWithCGImage:imageRef];
        
        CGImageRelease(imageRef);
        
        return img;
    }
    
    return nil;
}

//获取当前音量
- (int)videoPlayerReceiveVolume:(float *)volume
{
    MPMusicPlayerController *mpc = [MPMusicPlayerController applicationMusicPlayer];
    *volume = mpc.volume;
    return 0;
}

//控制音量
- (void)videoPlayerVolumeHandle:(float)volumeValue
{
    MPMusicPlayerController *mpc = [MPMusicPlayerController applicationMusicPlayer];
    if (volumeValue <= 0) {
        mpc.volume = 0;
    }
    else if (volumeValue >= 1) {
        mpc.volume = 1;
    }
    else {
        mpc.volume = volumeValue;
    }
}


//获取playback宽高
- (int)videoPlayerPlaybackSizeWithWidth:(float *)width height:(float *)height
{
    CGSize size = _avPlayerItem.presentationSize;
    *width = size.width;
    *height = size.height;
    if (*width > 0 && *height > 0) {
        return 0;
    }
    return -1;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
