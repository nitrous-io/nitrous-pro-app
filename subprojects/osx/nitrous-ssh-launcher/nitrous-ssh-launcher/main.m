//
//  main.m
//  nitrous-ssh-launcher
//
//  Created by Callum Jones on 10/29/14.
//  Copyright (c) 2014 Callum Jones. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <AppKit/AppKit.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc <= 1) {
            printf("Usage: %s [command]", argv[0]);
            return -1;
        }
        
        CFStringRef cfScheme = CFStringCreateWithCString(NULL, "ssh://", kCFStringEncodingUTF8);
        CFURLRef url = CFURLCreateWithString(NULL, cfScheme, NULL);
        CFURLRef app = NULL;
        LSGetApplicationForURL((CFURLRef)url, kLSRolesAll, NULL, &app);
        if (app == NULL) {
            printf("Unable to locate application for ssh:// scheme\n");
            return -1;
        }
        
        NSURL *appUrl = (__bridge NSURL *)(app);
        NSBundle *bundle = [NSBundle bundleWithURL:appUrl];
        NSString *appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
        printf("Starting %s", [appName UTF8String]);
        
        NSString *appleScriptSource;
        if ([appName rangeOfString:@"iTerm"].location != NSNotFound) {
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
            "   do script \"%@ && exit\"\n"
            "   activate\n"
            "   delay 0.5\n"
            "   tell application \"System Events\" to keystroke \"k\" using command down\n"
            "end tell";
        }
        
        NSMutableString *command = [NSMutableString stringWithUTF8String:argv[1]];
        if (argc > 2) {
            for (int i = 2; i < argc; i++) {
                [command appendFormat:@" %s", argv[i]];
            }
        }
        NSLog(@"Command: %@", command);
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
