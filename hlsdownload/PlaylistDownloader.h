//
//  PlaylistDownloader.h
//  hlsdownload
//
//  Created by Michael Rondinelli on 12/27/12.
//  Copyright (c) 2012 EyeSee360. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PlaylistDownloader : NSObject

@property (copy) NSURL *playlistURL;
@property (copy) NSString *outputFolder;
@property (copy) NSString *encryptionKey;
@property NSTimeInterval maxRecordingDuration;

- (id)initWithPlaylistURL:(NSURL *)playlistURL;

- (void)download:(NSString *)outputFile;
- (void)download:(NSString *)outputFile withKey:(NSString *)encryptionKey;

- (void)cancel;

@end
