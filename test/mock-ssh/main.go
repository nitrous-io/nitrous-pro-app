package main

import (
	"bytes"
	"fmt"
	"golang.org/x/crypto/ssh"
	"io"
	"io/ioutil"
	"net"
	"os"
)

func main() {

	args := os.Args
	if len(args) < 2 {
		fmt.Printf("Usage: %s private_key_file\n", args[0])
		return
	}

	privKeyFile := args[1]

	pubBytes, err := ioutil.ReadFile(privKeyFile + ".pub")
	if err != nil {
		panic(fmt.Sprintf("Failed to load pub key: %s", err))
	}

	pub, _, _, _, err := ssh.ParseAuthorizedKey(pubBytes)
	if err != nil {
		panic(fmt.Sprintf("Failed to parse pub key: %s", err))
	}

	// An SSH server is represented by a ServerConfig, which holds
	// certificate details and handles authentication of ServerConns.
	config := &ssh.ServerConfig{
		PasswordCallback: func(c ssh.ConnMetadata, pass []byte) (*ssh.Permissions, error) {
			// Should use constant-time compare (or better, salt+hash) in
			// a production setting.
			if c.User() == "user" && string(pass) == "pwd" {
				return nil, nil
			}
			return nil, fmt.Errorf("password rejected for %q", c.User())
		},
		PublicKeyCallback: func(conn ssh.ConnMetadata, key ssh.PublicKey) (*ssh.Permissions, error) {
			if bytes.Compare(pub.Marshal(), key.Marshal()) == 0 {
				perms := ssh.Permissions{}
				return &perms, nil
			} else {
				return nil, fmt.Errorf("key does not match")
			}
		},
	}

	privateBytes, err := ioutil.ReadFile(privKeyFile)
	if err != nil {
		panic("Failed to load private key")
	}

	private, err := ssh.ParsePrivateKey(privateBytes)
	if err != nil {
		panic("Failed to parse private key")
	}

	config.AddHostKey(private)

	// Once a ServerConfig has been configured, connections can be
	// accepted.
	listener, err := net.Listen("tcp", "0.0.0.0:2022")
	if err != nil {
		panic("failed to listen for connection")
	}
	fmt.Println("Waiting for Accept")
	nConn, err := listener.Accept()
	if err != nil {
		panic("failed to accept incoming connection")
	}
	fmt.Println("Accepted!")

	// Before use, a handshake must be performed on the incoming
	// net.Conn.
	_, chans, reqs, err := ssh.NewServerConn(nConn, config)
	if err != nil {
		panic("failed to handshake")
	}
	// The incoming Request channel must be serviced.
	go ssh.DiscardRequests(reqs)

	// Service the incoming Channel channel.
	for newChannel := range chans {
		fmt.Printf("Channel: %+v\n", newChannel)
		// Channels have a type, depending on the application level
		// protocol intended. In the case of a shell, the type is
		// "session" and ServerShell may be used to present a simple
		// terminal interface.
		if newChannel.ChannelType() != "session" {
			newChannel.Reject(ssh.UnknownChannelType, "unknown channel type")
			continue
		}
		channel, requests, err := newChannel.Accept()
		if err != nil {
			panic("could not accept channel.")
		}

		channel.Write([]byte("Welcome!\r\n"))

		i := &wBuffer{}
		io.Copy(i, channel)

		// Sessions have out-of-band requests such as "shell",
		// "pty-req" and "env".  Here we handle only the
		// "shell" request.
		go func(in <-chan *ssh.Request) {
			for req := range in {
				fmt.Printf("Request: %v\n", req)
				switch req.Type {
				case "shell":
					if len(req.Payload) > 0 {
						req.Reply(false, nil)
					} else {
						req.Reply(true, nil)
					}
				}
			}
		}(requests)
	}
}
