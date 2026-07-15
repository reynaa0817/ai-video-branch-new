package main

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	serviceName = "budget"
	serviceKind = "core-fact-service"
	factOwner   = true
)

type Health struct {
	ServiceName  string             `json:"service_name"`
	ServiceKind  string             `json:"service_kind"`
	FactOwner    bool               `json:"fact_owner"`
	Status       string             `json:"status"`
	Dependencies []DependencyStatus `json:"dependencies,omitempty"`
	Trace        TraceStatus        `json:"trace"`
}

type DependencyStatus struct {
	Name   string `json:"name"`
	Kind   string `json:"kind"`
	Status string `json:"status"`
}

type TraceStatus struct {
	TraceID   string `json:"trace_id"`
	SpanID    string `json:"span_id"`
	RequestID string `json:"request_id"`
}

func validateContract() error {
	if serviceName == "" {
		return errors.New("service name is required")
	}
	validKind := serviceKind == "bff" || serviceKind == "core-fact-service" || serviceKind == "projection" || serviceKind == "execution-worker"
	if !validKind {
		return fmt.Errorf("unsupported service kind %q", serviceKind)
	}
	if factOwner != (serviceKind == "core-fact-service") {
		return errors.New("fact ownership must match service kind")
	}
	return nil
}

func emit(status string, deps []DependencyStatus) error {
	return json.NewEncoder(os.Stdout).Encode(Health{
		ServiceName:  serviceName,
		ServiceKind:  serviceKind,
		FactOwner:    factOwner,
		Status:       status,
		Dependencies: deps,
		Trace: TraceStatus{
			TraceID:   envDefault("TRACE_ID", "trace_story_13_local"),
			SpanID:    envDefault("SPAN_ID", serviceName+"_health"),
			RequestID: envDefault("REQUEST_ID", "req_story_13_local"),
		},
	})
}

func main() {
	if err := validateContract(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	mode := "serve"
	if len(os.Args) > 1 {
		mode = os.Args[1]
	}
	switch mode {
	case "health":
		ctx, cancel := context.WithTimeout(context.Background(), readinessTimeout())
		defer cancel()
		deps, err := checkReadiness(ctx)
		if err != nil {
			if logErr := writeStructuredLog("error", "readiness failed", deps); logErr != nil {
				fmt.Fprintf(os.Stderr, "readiness failed: %v; structured log failed: %v\n", err, logErr)
				os.Exit(1)
			}
			if emitErr := emit("not_ready", deps); emitErr != nil {
				fmt.Fprintf(os.Stderr, "readiness failed: %v; health output failed: %v\n", err, emitErr)
				os.Exit(1)
			}
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if err := writeStructuredLog("info", "readiness passed", deps); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if err := emit("ready", deps); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	case "contract":
		if err := emit("contract-boundary-ok", nil); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	case "serve":
		if err := enforceLogRetention(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if err := writeStructuredLog("info", "service starting", nil); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if err := emit("starting", nil); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
		defer stop()
		if err := serveHealthEndpoint(ctx); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if err := writeStructuredLog("info", "service stopped", nil); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if err := emit("stopped", nil); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "unknown mode %q\n", mode)
		os.Exit(2)
	}
}

func checkReadiness(ctx context.Context) ([]DependencyStatus, error) {
	var deps []DependencyStatus
	var failures []string
	for _, spec := range splitList(os.Getenv("REQUIRED_DEPENDENCY_ENDPOINTS")) {
		name, address := splitPair(spec)
		status := DependencyStatus{Name: name, Kind: protocolKind(name), Status: "ready"}
		err := probeEndpoint(ctx, name, address)
		if err != nil {
			status.Status = "not_ready"
			failures = append(failures, name)
		}
		deps = append(deps, status)
	}
	if len(failures) > 0 {
		return deps, fmt.Errorf("dependencies not ready: %s", strings.Join(failures, ","))
	}
	return deps, nil
}

func protocolKind(name string) string {
	switch name {
	case "mysql":
		return "mysql-handshake"
	case "kafka":
		return "kafka-api-versions"
	case "temporal":
		return "grpc-http2"
	case "minio":
		return "http-health"
	default:
		return "application-health"
	}
}

func probeEndpoint(ctx context.Context, name, address string) error {
	switch name {
	case "minio":
		return probeHTTP(ctx, "http://"+address+"/minio/health/live")
	case "budget", "quality", "asset", "model-gateway":
		return probeHTTP(ctx, "http://"+address+"/healthz")
	case "temporal":
		return probeHTTP2(ctx, address)
	case "mysql":
		return probeMySQL(ctx, address)
	case "kafka":
		return probeKafka(ctx, address)
	default:
		return fmt.Errorf("no protocol probe registered for %s", name)
	}
}

func probeHTTP(ctx context.Context, endpoint string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	resp, err := (&http.Client{Timeout: readinessTimeout()}).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("HTTP status %d", resp.StatusCode)
	}
	return nil
}

func probeMySQL(ctx context.Context, address string) error {
	conn, err := (&net.Dialer{}).DialContext(ctx, "tcp", address)
	if err != nil {
		return err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(readinessTimeout()))
	header := make([]byte, 4)
	if _, err := io.ReadFull(conn, header); err != nil {
		return err
	}
	length := int(header[0]) | int(header[1])<<8 | int(header[2])<<16
	if length < 1 || length > 1<<20 {
		return fmt.Errorf("invalid MySQL handshake length %d", length)
	}
	payload := make([]byte, length)
	if _, err := io.ReadFull(conn, payload); err != nil {
		return err
	}
	if payload[0] != 10 {
		return fmt.Errorf("unexpected MySQL protocol version %d", payload[0])
	}
	return nil
}

func probeKafka(ctx context.Context, address string) error {
	conn, err := (&net.Dialer{}).DialContext(ctx, "tcp", address)
	if err != nil {
		return err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(readinessTimeout()))
	clientID := []byte("health")
	body := make([]byte, 10+len(clientID))
	binary.BigEndian.PutUint16(body[0:2], 18)
	binary.BigEndian.PutUint16(body[2:4], 0)
	binary.BigEndian.PutUint32(body[4:8], 1)
	binary.BigEndian.PutUint16(body[8:10], uint16(len(clientID)))
	copy(body[10:], clientID)
	request := make([]byte, 4+len(body))
	binary.BigEndian.PutUint32(request[:4], uint32(len(body)))
	copy(request[4:], body)
	if _, err := conn.Write(request); err != nil {
		return err
	}
	header := make([]byte, 8)
	if _, err := io.ReadFull(conn, header); err != nil {
		return err
	}
	length := binary.BigEndian.Uint32(header[:4])
	if length < 8 || length > 1<<20 {
		return fmt.Errorf("invalid Kafka ApiVersions response length %d", length)
	}
	if binary.BigEndian.Uint32(header[4:8]) != 1 {
		return errors.New("Kafka correlation id mismatch")
	}
	payload := make([]byte, int(length)-4)
	if _, err := io.ReadFull(conn, payload); err != nil {
		return err
	}
	if len(payload) < 4 {
		return errors.New("Kafka ApiVersions response too short")
	}
	apiCount := int(binary.BigEndian.Uint32(payload[:4]))
	if apiCount <= 0 || len(payload) < 4+apiCount*6 {
		return fmt.Errorf("invalid Kafka ApiVersions API count %d", apiCount)
	}
	for offset := 4; offset < 4+apiCount*6; offset += 6 {
		if binary.BigEndian.Uint16(payload[offset:offset+2]) == 18 {
			return nil
		}
	}
	return errors.New("Kafka ApiVersions response did not include ApiVersions API key")
}

func probeHTTP2(ctx context.Context, address string) error {
	conn, err := (&net.Dialer{}).DialContext(ctx, "tcp", address)
	if err != nil {
		return err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(readinessTimeout()))
	if _, err := conn.Write([]byte("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")); err != nil {
		return err
	}
	frame := make([]byte, 9)
	if _, err := io.ReadFull(conn, frame); err != nil {
		return err
	}
	if frame[3] != 4 {
		return fmt.Errorf("expected HTTP/2 SETTINGS frame, got type %d", frame[3])
	}
	return nil
}

func readinessTimeout() time.Duration {
	seconds, err := strconv.Atoi(envDefault("READINESS_TIMEOUT_SECONDS", "2"))
	if err != nil || seconds < 1 {
		seconds = 2
	}
	return time.Duration(seconds) * time.Second
}

func splitList(value string) []string {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	parts := strings.Split(value, ",")
	items := make([]string, 0, len(parts))
	for _, part := range parts {
		item := strings.TrimSpace(part)
		if item != "" {
			items = append(items, item)
		}
	}
	return items
}

func splitPair(spec string) (string, string) {
	name, value, ok := strings.Cut(spec, "=")
	if !ok {
		return spec, spec
	}
	return strings.TrimSpace(name), strings.TrimSpace(value)
}

func writeStructuredLog(level, message string, deps []DependencyStatus) error {
	if err := enforceLogRetention(); err != nil {
		return err
	}
	entry := map[string]any{
		"time":         time.Now().UTC().Format(time.RFC3339),
		"level":        level,
		"service":      serviceName,
		"message":      message,
		"trace_id":     envDefault("TRACE_ID", "trace_story_13_local"),
		"span_id":      envDefault("SPAN_ID", serviceName+"_runtime"),
		"request_id":   envDefault("REQUEST_ID", "req_story_13_local"),
		"dependencies": deps,
	}
	payload, err := json.Marshal(entry)
	if err != nil {
		return err
	}
	if err := appendLine(filepath.Join(envDefault("APP_LOG_DIR", "/app/logs/app"), "app-"+time.Now().UTC().Format("2006-01-02")+".log"), payload); err != nil {
		return err
	}
	if level == "error" {
		return appendLine(filepath.Join(envDefault("ERROR_LOG_DIR", "/app/logs/error"), "error-"+time.Now().UTC().Format("2006-01-02")+".log"), payload)
	}
	return nil
}

func appendLine(path string, payload []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer file.Close()
	if _, err := file.Write(append(payload, '\n')); err != nil {
		return err
	}
	return nil
}

func enforceLogRetention() error {
	retention, err := strconv.Atoi(envDefault("LOG_RETENTION_DAYS", "30"))
	if err != nil || retention != 30 {
		return fmt.Errorf("LOG_RETENTION_DAYS must be 30, got %q", os.Getenv("LOG_RETENTION_DAYS"))
	}
	for _, dir := range []string{envDefault("APP_LOG_DIR", "/app/logs/app"), envDefault("ERROR_LOG_DIR", "/app/logs/error")} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
		if err := removeExpiredLogs(dir, retention); err != nil {
			return err
		}
	}
	return nil
}

func removeExpiredLogs(dir string, retention int) error {
	cutoff := time.Now().AddDate(0, 0, -retention)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".log") {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if info.ModTime().Before(cutoff) {
			if err := os.Remove(filepath.Join(dir, entry.Name())); err != nil {
				return err
			}
		}
	}
	return nil
}

func envDefault(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func serveHealthEndpoint(ctx context.Context) error {
	address := strings.TrimSpace(os.Getenv("HEALTH_LISTEN_ADDR"))
	if address == "" {
		<-ctx.Done()
		return nil
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, request *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		probeCtx, cancel := context.WithTimeout(request.Context(), readinessTimeout())
		defer cancel()
		deps, err := checkReadiness(probeCtx)
		status := "ready"
		if err != nil {
			status = "not_ready"
			w.WriteHeader(http.StatusServiceUnavailable)
		}
		if encodeErr := json.NewEncoder(w).Encode(map[string]any{"service": serviceName, "status": status, "dependencies": deps}); encodeErr != nil {
			fmt.Fprintln(os.Stderr, encodeErr)
		}
	})
	server := &http.Server{Addr: address, Handler: mux, ReadHeaderTimeout: 2 * time.Second}
	errCh := make(chan error, 1)
	go func() {
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()
	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		return server.Shutdown(shutdownCtx)
	case err := <-errCh:
		return err
	}
}
