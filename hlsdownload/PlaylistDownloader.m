//
//  PlaylistDownloader.m
//  hlsdownload
//
//  Created by Michael Rondinelli on 12/27/12.
//  Copyright (c) 2012 EyeSee360. All rights reserved.
//

#import "PlaylistDownloader.h"
#import "NSFileHandle+StringOutput.h"

static NSString *EXT_INF = @"#EXTINF";
static NSString *EXT_X_KEY = @"#EXT-X-KEY";
static NSString *BANDWIDTH = @"BANDWIDTH";
static NSString *EXT_X_ENDLIST = @"EXT-X-ENDLIST";
static NSString *EXT_X_TARGETDURATION = @"EXT-X-TARGETDURATION";


@interface PlaylistDownloader ()

@property (retain) NSFileHandle *stdoutHandle;
@property (retain) NSFileHandle *outputFileHandle;
@property (retain) NSMutableOrderedSet *playlistSet;
@property (retain) NSMutableOrderedSet *downloadedSet;
@property NSTimeInterval startTime;
@property NSTimeInterval maxSegmentInterval;
@property NSTimeInterval elapsedRecordingTime;
@property BOOL endList;
@property BOOL didCancel;

@end


@implementation PlaylistDownloader

- (id)initWithPlaylistURL:(NSURL *)playlistURL
{
    self = [super init];
    if (self) {
        self.playlistURL = playlistURL;
        self.stdoutHandle = [NSFileHandle fileHandleWithStandardOutput];
        self.playlistSet = [NSMutableOrderedSet orderedSetWithCapacity:0];
        self.downloadedSet = [NSMutableOrderedSet orderedSetWithCapacity:0];
        self.endList = NO;
        self.didCancel = NO;
        self.elapsedRecordingTime = 0.0;
        
        char wd[MAXPATHLEN];
        getwd(wd);
        self.outputFolder = [NSString stringWithUTF8String:wd];
    }
    return self;
}

- (void)download:(NSString *)outputFile
{
    [self download:outputFile withKey:nil];
}

- (void)download:(NSString *)outputFile withKey:(NSString *)encryptionKey
{
    if (outputFile) {
        NSError *error = nil;
        [@"" writeToFile:outputFile atomically:NO encoding:NSUTF8StringEncoding error:&error];
        self.outputFileHandle = [NSFileHandle fileHandleForWritingAtPath:outputFile];
    }
        
    while (!self.endList) {
        @autoreleasepool {            
            NSTimeInterval playlistStartTime = [NSDate timeIntervalSinceReferenceDate];
            NSTimeInterval segmentTime = self.maxSegmentInterval;
            NSOrderedSet *dlSet = [self updatePlaylist];
            if (!dlSet) {
                break;
            }
            
            for (NSString *thisLine in dlSet) {
                NSString *line = [thisLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                
                if ([line rangeOfString:EXT_INF].length > 0) {
                    segmentTime = [[line substringFromIndex:[EXT_INF length]] doubleValue];
                }
                if ([line hasPrefix:EXT_X_KEY]) {
                    // Handle crypto key
                }
                else if ([line length] > 0 && ![line hasPrefix:@"#"]) {
                    NSURL *baseURL = [self.playlistURL URLByDeletingLastPathComponent];
                    NSURL *segmentURL = [NSURL URLWithString:line relativeToURL:baseURL];
                    
                    if (!self.didCancel) {
                        [self downloadSegment:segmentURL];
                        [self.downloadedSet addObject:line];
                        self.elapsedRecordingTime += segmentTime;
                        
                        if (self.maxRecordingDuration > 0.0 && self.elapsedRecordingTime > self.maxRecordingDuration) {
                            [self.stdoutHandle writeString:@"Maximum duration reached. Stopping."];
                            [self cancel];
                        }
                    }
                }
            }
            
            // Wait if we're ahead of time
            NSTimeInterval remainingTime = [NSDate timeIntervalSinceReferenceDate] - playlistStartTime;
            if (remainingTime < self.maxSegmentInterval) {
                sleep(ceil(remainingTime));
            }
        }
    }
    
    if (outputFile) {
        [self.outputFileHandle closeFile];
    }
}

- (void)cancel
{
    self.endList = YES;
    self.didCancel = YES;
}

- (NSOrderedSet *)updatePlaylist
{
    NSArray *currentPlaylist = [self fetchPlaylist];
    [self.playlistSet removeAllObjects];
    if (currentPlaylist) {
        [self.playlistSet addObjectsFromArray:currentPlaylist];
        
        NSMutableOrderedSet *toBeDownloadedSet = [self.playlistSet mutableCopy];
        [toBeDownloadedSet minusOrderedSet:self.downloadedSet];
        return toBeDownloadedSet;
    }
    return nil;
}

- (BOOL)checkHTTPResponse:(NSHTTPURLResponse *)response
{
    NSInteger statusCode = [response statusCode];

    if (statusCode >= 400) {
        NSString *message = [NSString stringWithFormat:@"Got response %ld (%@) for URL %@\n", statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode], [self.playlistURL absoluteString]];
        [self.stdoutHandle writeString:message];
        return NO;
    }

    return YES;
}

- (NSArray *)fetchPlaylist
{
    NSURLRequest *req = [NSURLRequest requestWithURL:self.playlistURL];
    NSHTTPURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
    BOOL isMaster = NO;
    NSInteger maxRate = 0;
    NSString *maxRateURL = nil;
    NSInteger index = 0;

    if (![self checkHTTPResponse:response]) {
        return nil;
    }
    if (error) {
        [self.stdoutHandle writeString:[error localizedDescription]];
        return nil;
    }
    
    NSString *playlist = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *playlistLines = [playlist componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    for (NSString *thisLine in playlistLines) {
        NSString *line = [thisLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ([line rangeOfString:BANDWIDTH].length > 0) {
            isMaster = YES;
        }
        if (isMaster && [line rangeOfString:BANDWIDTH].length > 0) {
            NSInteger bandwidth = 0;
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"BANDWIDTH=([0-9]+)" options:0 error:&error];
            NSArray *matches = [re matchesInString:line options:0 range:NSMakeRange(0, [line length])];
            if (matches && [matches count] > 0) {
                NSTextCheckingResult *result = [matches lastObject];
                NSString *bwStr = [line substringWithRange:[result rangeAtIndex:1]];
                bandwidth = [bwStr integerValue];
            }
            
            maxRate = MAX(bandwidth, maxRate);            
            if (bandwidth == maxRate) {
                maxRateURL = [playlistLines objectAtIndex:index + 1];
            }
        }
        if ([line rangeOfString:EXT_X_TARGETDURATION].length > 0) {
            self.maxSegmentInterval = [[line substringFromIndex:[EXT_X_TARGETDURATION length]] doubleValue];
        }
        if ([line rangeOfString:EXT_X_ENDLIST].length > 0) {
            self.endList = YES;
        }
        index++;
    };
    
    if (isMaster) {
        NSString *message = [NSString stringWithFormat:@"Found master playlist, fetching highest stream at %ld Kb/s\n", maxRate / 1024];
        [self.stdoutHandle writeString:message];
        NSURL *baseURL = [self.playlistURL URLByDeletingLastPathComponent];
        NSURL *playlistURL = [NSURL URLWithString:maxRateURL relativeToURL:baseURL];
        self.playlistURL = playlistURL;
        playlistLines = [self fetchPlaylist];
    }
    return playlistLines;
}

- (void)downloadSegment:(NSURL *)segmentURL
{
    @autoreleasepool {
        BOOL shouldCloseSegment = NO;
        NSFileHandle *outputHandle = self.outputFileHandle;
        if (!outputHandle) {
            NSError *error = nil;
            NSString *path = [self.outputFolder stringByAppendingPathComponent:[segmentURL lastPathComponent]];
            [@"" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:&error];
            outputHandle = [NSFileHandle fileHandleForWritingAtPath:path];
            shouldCloseSegment = YES;
        }
        
        [self.stdoutHandle writeString:[NSString stringWithFormat:@"Downloading segment: %@\r", [segmentURL lastPathComponent]]];
        
        NSURLRequest *req = [NSURLRequest requestWithURL:segmentURL];
        NSHTTPURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
        
        if (![self checkHTTPResponse:response]) {
            return;
        }

        if (data && !error) {
            [outputHandle writeData:data];
        }
        
        if (shouldCloseSegment) {
            [outputHandle closeFile];
        } else {
            [outputHandle synchronizeFile];
        }
    }
}

@end
