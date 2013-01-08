//
//  main.m
//  hlsdownload
//
//  Created by Michael Rondinelli on 12/27/12.
//  Copyright (c) 2012 EyeSee360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <getopt.h>
#import "PlaylistDownloader.h"

static struct option longopts[] = {
    { "help", no_argument, NULL, 'h' },
    { "force-key", required_argument, NULL, 'k' },
    { "duration", required_argument, NULL, 'd' },
    { "output", required_argument, NULL, 'o' },
    { "silent", no_argument, NULL, 's' },
    { "overwrite", no_argument, NULL, 'y' },
    { 0, 0, 0, 0 }
};

static PlaylistDownloader *sDownloader;

// SIGINT handler
void int_handler(int x)
{
    fprintf(stdout, "Canceling...\n");
    if (sDownloader) {
        [sDownloader cancel];
    } else {
        exit(0);
    }
}

void show_help()
{
    fprintf(stdout, "Usage: hlsdownload [options...] <url>\n");
    fprintf(stdout, "Options: \n");
    fprintf(stdout, "  -h, --help              print this message.\n");
    fprintf(stdout, "  -k, --force-key KEY     force use of the supplied AES-128 key.\n");
    fprintf(stdout, "  -s, --silent            silent mode.\n");
    fprintf(stdout, "  -y, --overwrite         overwrite output files.\n");
    fprintf(stdout, "  -d, --duration SECS     specify maximum recording duration before stopping\n");
    fprintf(stdout, "                          (use 0 or unspecified for no limit)\n");
    fprintf(stdout, "  -o, --output FILE.ts    join all transport streams to one file.\n");
}

int main(int argc, char * const argv[])
{
    @autoreleasepool {
        int ch;
        NSString *key = nil;
        NSString *outFile = nil;
        NSError *error = nil;
        BOOL silent = NO;
        BOOL overwrite = NO;
        NSTimeInterval duration = 0.0;
        
        // Register interrupt handler
        signal(SIGINT, &int_handler);
        
        while ((ch = getopt_long(argc, argv, "hk:o:syd:", longopts, NULL)) != -1) {
            switch (ch) {
                case 'h':
                    // help
                    show_help();
                    break;
                    
                case 'k': {
                    key = [NSString stringWithUTF8String:optarg];
                    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\[0-9a-fA-F]{32}\\" options:0 error:&error];
                    if (![re numberOfMatchesInString:key options:NSMatchingAnchored range:NSMakeRange(0, [key length])]) {
                        fprintf(stderr, "Bad key format: \"%s\". Expected 32-character hex format.\nExample: -key 12ba7f70db4740dec4aab4c5c2c768d9", optarg);
                        return -1;
                    }
                }   break;
                    
                case 'd':
                    duration = atof(optarg);
                    break;
                    
                case 'o':
                    outFile = [NSString stringWithUTF8String:optarg];
                    break;
                    
                case 's':
                    silent = YES;
                    break;
                    
                case 'y':
                    overwrite = YES;
                    break;
                    
                default:
                    break;
            }
        }
        argc -= optind;
        argv += optind;
        
        if (argc > 0) {
            char * const urlCStr = argv[0];
            NSString *urlString = [NSString stringWithUTF8String:urlCStr];
            NSURL *playlistURL = [NSURL URLWithString:urlString];
            
            sDownloader = [[PlaylistDownloader alloc] initWithPlaylistURL:playlistURL];
            [sDownloader setMaxRecordingDuration:duration];
            [sDownloader download:outFile withKey:key];
        } else {
            show_help();
        }
    }
    return 0;
}

