//
//  CDSessionResumeDownloader.m
//  CDResumeDownloader
//
//  Created by 饮长刀 on 2017/6/29.
//  Copyright © 2017年 饮长刀. All rights reserved.
//

#import "CDSessionResumeDownloader.h"

typedef void (^CDURLSessionDownloadProgressBlock)(int64_t bytesWritten, int64_t totalBytesWitten, int64_t totalBytesExpectedToWritte);
typedef void (^CDURLSessionDownloadCompletionBlock)(NSURL *filePath, NSError *error);
typedef void (^CDURLSessionDownloadSpeedBlock)(NSString *speed);

@interface CDSessionResumeDownloader () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSData *resumeData;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, assign) int64_t currentSize;
@property (nonatomic, assign) int64_t preSize;
@property (nonatomic, copy) CDURLSessionDownloadProgressBlock downloadProgress;
@property (nonatomic, copy) CDURLSessionDownloadCompletionBlock completion;

@end

@implementation CDSessionResumeDownloader

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"backGroundId"];
        //        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30;
        _session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:[[NSOperationQueue alloc] init]];
    }
    return _session;
}

- (void)invalidSession {
    [self.session invalidateAndCancel];
}

- (void)start {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *doc = [paths objectAtIndex:0];
    NSString *plistPath = [doc stringByAppendingPathComponent:@"resumeData.plist"];
    NSMutableDictionary *plistDic = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
    NSMutableArray *resumeArr = [plistDic valueForKey:self.md5Identifier];
    self.resumeData = [resumeArr firstObject];
    self.preSize = [[resumeArr lastObject] longLongValue];
    self.currentSize = [[resumeArr lastObject] longLongValue];
    
    if (!self.resumeData) {
        _task = [self.session downloadTaskWithURL:self.URL];
    } else {
        _task = [self.session downloadTaskWithResumeData:self.resumeData];
    }
    [_task resume];
    self.resumeData = nil;
}

- (void)cancel {
    //    NSLog(@"取消下载--%s", __func__);
    __weak typeof(self) weakSelf = self;
    [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        weakSelf.resumeData = resumeData;
        weakSelf.task = nil;
        // 把当前的下载进度存到plist文件中
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *doc = [paths objectAtIndex:0];
        NSString *plistPath = [doc stringByAppendingPathComponent:@"resumeData.plist"];
        NSMutableDictionary *plistDic = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
        if (plistDic == nil) {
            plistDic = [[NSMutableDictionary alloc] init];
        }
        
        if (weakSelf.md5Identifier.length != 0 && weakSelf.resumeData) {
            NSMutableArray *resumeArr = [NSMutableArray arrayWithCapacity:0];
            [resumeArr addObject:weakSelf.resumeData];
            [resumeArr addObject:@(weakSelf.currentSize)];
            [plistDic setValue:resumeArr forKey:weakSelf.md5Identifier];
            [plistDic writeToFile:plistPath atomically:YES];
        }
        
        weakSelf.preSize = 0;
        weakSelf.currentSize = 0;
        
        weakSelf.completion = nil;
        weakSelf.downloadProgress = nil;
    }];
}

- (void)setDownloadCompletionBlock:(void (^)(NSURL * _Nonnull, NSError *error))block {
    self.completion = block;
}

- (void)setDownloadProgressBlock:(void (^)(int64_t, int64_t, int64_t))block {
    self.downloadProgress = block;
}

#pragma mark - NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    //    NSLog(@"--下载完毕---%@", self.URL);
    
    // 完全下载完数据后，清理断点记录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *doc = [paths objectAtIndex:0];
    NSString *plistPath = [doc stringByAppendingPathComponent:@"resumeData.plist"];
    NSMutableDictionary *plistDic = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
    if (plistDic) {
        [plistDic removeObjectForKey:self.md5Identifier];
        [plistDic writeToFile:plistPath atomically:YES];
    }
    
    // 将该路径所指的文件搬到用户指定的文件夹下，并且以MD5命名，重名则在MD5后面加 ‘_1(2、3...)’
    NSString *filePath = [self.directoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", self.md5Identifier]];
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    int i = 0;
    while (isExist) {
        i++;
        filePath = [self.directoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%d", self.md5Identifier, i]];
        isExist = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    }
    [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:filePath error:nil];
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    if (self.completion) {
        self.completion(fileUrl, nil);
    }
    
    self.completion = nil;
    self.downloadProgress = nil;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.currentSize = totalBytesWritten;
    if (self.downloadProgress) {
        self.downloadProgress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    }
}

#pragma mark - NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    self.error = error;
    //    NSLog(@"原始文件下载错误:%@", error);
    if (error != nil) {
        if (error.code == NSURLErrorCannotWriteToFile || error.code == 2) {
            //! 该情况为断点文件被清理，需要从头开始下载。
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
            NSString *doc = [paths objectAtIndex:0];
            NSString *plistPath = [doc stringByAppendingPathComponent:@"resumeData.plist"];
            NSMutableDictionary *plistDic = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
            if (plistDic) {
                [plistDic removeObjectForKey:self.md5Identifier];
                [plistDic writeToFile:plistPath atomically:YES];
            }
            self.preSize = 0;
            self.currentSize = 0;
            _task = [self.session downloadTaskWithURL:self.URL];
            [_task resume];
        } else if (error.code != NSURLErrorCancelled) {
            if (self.completion) {
                self.completion(nil, error);
            }
            self.completion = nil;
            self.downloadProgress = nil;
        }
    }
}

@end
