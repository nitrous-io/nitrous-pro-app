package main

import (
	"bytes"
	"fmt"
)

type wBuffer struct {
	buf bytes.Buffer
}

func (b *wBuffer) Write(p []byte) (n int, err error) {
	for _, chr := range p {
		if chr == 13 {
			fmt.Println(b.buf.String())
			b.buf.Reset()
		} else {
			b.buf.WriteByte(chr)
		}
	}

	return len(p), nil
}
