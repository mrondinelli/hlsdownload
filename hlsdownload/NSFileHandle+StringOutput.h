//
//  NSFileHandle+StringOutput.h
//  hlsdownload
//
//  Created by Michael Rondinelli on 12/27/12.
//  Copyright (c) 2012 EyeSee360. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileHandle (StringOutput)

- (void)writeString:(NSString *)string;

@end
