package main

import (
	"context"
	"encoding/binary"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestProtocolReadinessProbes(t *testing.T) {
	t.Setenv("READINESS_TIMEOUT_SECONDS", "1")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	httpServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) }))
	defer httpServer.Close()
	httpAddress := strings.TrimPrefix(httpServer.URL, "http://")
	if err := probeEndpoint(ctx, "minio", httpAddress); err != nil {
		t.Fatalf("http probe: %v", err)
	}

	tests := []struct {
		name    string
		handler func(net.Conn)
	}{
		{name: "mysql", handler: func(conn net.Conn) { _, _ = conn.Write([]byte{1, 0, 0, 0, 10}) }},
		{name: "kafka", handler: func(conn net.Conn) {
			header := make([]byte, 4)
			if _, err := io.ReadFull(conn, header); err != nil {
				return
			}
			body := make([]byte, binary.BigEndian.Uint32(header))
			if _, err := io.ReadFull(conn, body); err != nil {
				return
			}
			response := make([]byte, 18)
			binary.BigEndian.PutUint32(response[:4], 14)
			binary.BigEndian.PutUint32(response[4:8], 1)
			binary.BigEndian.PutUint32(response[8:12], 1)
			binary.BigEndian.PutUint16(response[12:14], 18)
			binary.BigEndian.PutUint16(response[14:16], 0)
			binary.BigEndian.PutUint16(response[16:18], 3)
			_, _ = conn.Write(response)
		}},
		{name: "temporal", handler: func(conn net.Conn) {
			want := []byte("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
			preface := make([]byte, len(want))
			if _, err := io.ReadFull(conn, preface); err != nil {
				return
			}
			if string(preface) != string(want) {
				return
			}
			frame := make([]byte, 9)
			frame[3] = 4
			_, _ = conn.Write(frame)
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			listener, err := net.Listen("tcp", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			defer listener.Close()
			go func() {
				conn, err := listener.Accept()
				if err == nil {
					defer conn.Close()
					tt.handler(conn)
				}
			}()
			if err := probeEndpoint(ctx, tt.name, listener.Addr().String()); err != nil {
				t.Fatalf("%s probe: %v", tt.name, err)
			}
		})
	}
}

func TestUnknownProtocolProbeFailsClosed(t *testing.T) {
	if err := probeEndpoint(context.Background(), "unknown", "127.0.0.1:1"); err == nil {
		t.Fatal("unknown dependency was accepted")
	}
}
