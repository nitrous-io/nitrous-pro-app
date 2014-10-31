#import <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>

CFRunLoopRef backgroundLoop = NULL;

void event_cb(ConstFSEventStreamRef streamRef,
              void *ctx,
              size_t count,
              void *paths,
              const FSEventStreamEventFlags eventFlags[],
              const FSEventStreamEventId eventIds[]) {

    NSArray *eventPathsArray = (__bridge NSArray *)paths;
    for (NSUInteger i = 0; i < count; ++i) {
        FSEventStreamEventFlags flags = eventFlags[i];
        if (flags & (kFSEventStreamEventFlagItemCreated
                     | kFSEventStreamEventFlagItemRemoved
                     | kFSEventStreamEventFlagItemRenamed
                     | kFSEventStreamEventFlagItemModified
                     | kFSEventStreamEventFlagRootChanged)) {
            char * chngName;
            if (flags&kFSEventStreamEventFlagItemCreated)
                chngName = "create";
            else if (flags&kFSEventStreamEventFlagItemModified)
                chngName = "modify";
            else if (flags&kFSEventStreamEventFlagItemRemoved)
                chngName = "delete";
            else if (flags&kFSEventStreamEventFlagItemRenamed)
                chngName = "move";
            else if (flags&kFSEventStreamEventFlagRootChanged)
                chngName = "root_changed";
            else
                chngName = "0";
            for (NSString *path in eventPathsArray) {
                printf("Change(%s): %s\n", chngName, [path UTF8String]);
                fflush(stdout);
            }
        }
    }
}

void SIGTERM_handler(int signum) {
    CFRunLoopStop(backgroundLoop);
}

void watchFiles(NSString *path) {
    NSArray *paths = [NSArray arrayWithObject:path];

    FSEventStreamContext context = {0, NULL, NULL, NULL, NULL};
    NSTimeInterval latency = 0;

    FSEventStreamRef stream;
    stream = FSEventStreamCreate(NULL,
                                 &event_cb,
                                 &context,
                                 (__bridge CFArrayRef) paths,
                                 kFSEventStreamEventIdSinceNow,
                                 (CFAbsoluteTime) latency,
                                 kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot |kFSEventStreamCreateFlagFileEvents
                                 );
    if (stream == NULL) {
        printf("Failed to init FSEventStreamCreate!\n");
        exit(-1);
    }
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);

    backgroundLoop = CFRunLoopGetCurrent();
    CFRunLoopRun();

    printf("Cleaning up FSEventStream\n");
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
    FSEventStreamRelease(stream);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc <= 1) {
            printf("%s\n", [[NSString stringWithFormat:@"Nitrous Desktop Watcher\nUsage: %s [path]", argv[0]] UTF8String]);
            return -1;
        }

        signal(SIGTERM, SIGTERM_handler);
        signal(SIGINT, SIGTERM_handler);

        NSString *location = [NSString stringWithUTF8String:argv[1]];
        dispatch_sync(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            watchFiles(location);
        });
    }
    return 0;
}
