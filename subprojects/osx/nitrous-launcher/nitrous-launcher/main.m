//
//  main.m
//  nitrous-launcher
//
//  Created by Callum Jones on 10/29/14.
//  Copyright (c) 2014 Callum Jones. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <AppKit/AppKit.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc <= 2) {
            printf("Usage: %s [scheme] [command]", argv[0]);
            return -1;
        }
        
        CFStringRef cfScheme = CFStringCreateWithCString(NULL, argv[1], kCFStringEncodingUTF8);
        CFURLRef url = CFURLCreateWithString(NULL, cfScheme, NULL);
        CFURLRef app = LSCopyDefaultApplicationURLForURL(url, kLSRolesAll, NULL);
        
        NSURL *appUrl = (__bridge NSURL *)(app);
        NSBundle *bundle = [NSBundle bundleWithURL:appUrl];
        NSString *appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
        printf("Starting %s", [appName UTF8String]);
        
        NSString *appleScriptSource;
        if ([appName containsString:@"iTerm"]) {
            appleScriptSource = @"tell app \"iTerm\"\n"
            "  activate\n"
            "  if (count of terminals) = 0 then\n"
            "      set t to (make new terminal)\n"
            "  else\n"
            "      set t to current terminal\n"
            "  end if\n"
            "  tell t\n"
            "      set s to (make new session at the end of sessions)\n"
            "      tell s\n"
            "          exec command \"%@\"\n"
            "      end tell\n"
            "  end tell\n"
            "end tell\n";
        } else {
            appleScriptSource = @"tell app \"Terminal\"\n"
            "   do script \"%@\"\n"
            "   activate\n"
            "end tell";
        }
        
        NSString *command = [NSString stringWithUTF8String:argv[2]];
        NSString *finalScript = [NSString stringWithFormat:appleScriptSource, [command stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
        NSAppleScript *as = [[NSAppleScript alloc] initWithSource:finalScript];
        NSDictionary *errorDict = nil;
        NSAppleEventDescriptor *event = [as executeAndReturnError:&errorDict];
        
        if (event == nil || errorDict != nil) {
            return -1;
        }
    }
    return 0;
}
