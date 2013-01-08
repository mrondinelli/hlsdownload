//
//  NSFileHandle+StringOutput.m
//  hlsdownload
//
//  Created by Michael Rondinelli on 12/27/12.
//  Copyright (c) 2012 EyeSee360. All rights reserved.
//

#import "NSFileHandle+StringOutput.h"

@implementation NSFileHandle (StringOutput)

- (void)writeString:(NSString *)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    [self writeData:data];
}

@end
