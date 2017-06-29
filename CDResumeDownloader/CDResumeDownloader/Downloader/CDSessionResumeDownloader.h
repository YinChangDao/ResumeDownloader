//
//  CDSessionResumeDownloader.h
//  CDResumeDownloader
//
//  Created by 饮长刀 on 2017/6/29.
//  Copyright © 2017年 饮长刀. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface CDSessionResumeDownloader : NSObject

@property (nonatomic, strong) NSURL *URL;

@property (nonatomic, strong) NSString *directoryPath;

@property (nonatomic, copy) NSString *md5Identifier;

- (void)start;

- (void)cancel;

- (void)setDownloadProgressBlock:(nullable void (^)(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite))block;

- (void)setDownloadCompletionBlock:(void (^) (NSURL *filePath, NSError *error))block;

- (void)invalidSession;

@property (nonatomic, strong) NSError *error;

extern NSString * const CDURLSessionDidStartNotification;

extern NSString * const CDURLSessionDidFinishNotification;

@end
NS_ASSUME_NONNULL_END
