package main

import (
	"code.google.com/p/go.exp/inotify"
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	watcher, err := inotify.NewWatcher()
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
	if len(os.Args) < 2 {
		fmt.Printf("Usage: %s [path] ([path]...)\n", os.Args[0])
		os.Exit(1)
	}

	for _, path := range os.Args[1:len(os.Args)] {
		fmt.Printf("Subscribing to %s\n", path)
		err = watcher.AddWatch(path, inotify.IN_MODIFY|inotify.IN_CREATE|inotify.IN_DELETE|inotify.IN_MOVE|inotify.IN_DELETE_SELF|inotify.IN_CLOSE_WRITE)
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			os.Exit(1)
		}
	}

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, os.Kill, syscall.SIGTERM)
	go func() {
		for _ = range c {
			watcher.Close()
			os.Exit(0)
		}
	}()

	for {
		select {
		case ev := <-watcher.Event:
			evName := ""
			evMask := ev.Mask
			if evMask&inotify.IN_MODIFY == inotify.IN_MODIFY {
				evName = "modify"
			} else if evMask&inotify.IN_CREATE == inotify.IN_CREATE {
				evName = "create"
			} else if evMask&inotify.IN_DELETE == inotify.IN_DELETE || evMask&inotify.IN_DELETE_SELF == inotify.IN_DELETE_SELF {
				evName = "delete"
			} else if evMask&inotify.IN_MOVE == inotify.IN_MOVE {
				evName = "move"
			} else if evMask&inotify.IN_CLOSE_WRITE == inotify.IN_CLOSE_WRITE {
				evName = "closed"
			}
			fmt.Printf("Change(%s): %s\n", evName, ev.Name)
		}
	}
}
