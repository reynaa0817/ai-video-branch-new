package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	serviceName = "model-gateway"
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
			_ = writeStructuredLog("error", "readiness failed", deps)
			_ = emit("not_ready", deps)
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		_ = writeStructuredLog("info", "readiness passed", deps)
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
		<-ctx.Done()
		_ = writeStructuredLog("info", "service stopped", nil)
		_ = emit("stopped", nil)
	default:
		fmt.Fprintf(os.Stderr, "unknown mode %q\n", mode)
		os.Exit(2)
	}
}

func checkReadiness(ctx context.Context) ([]DependencyStatus, error) {
	var deps []DependencyStatus
	var failures []string
	for _, spec := range splitList(os.Getenv("REQUIRED_TCP_ENDPOINTS")) {
		name, address := splitPair(spec)
		status := DependencyStatus{Name: name, Kind: "tcp", Status: "ready"}
		dialer := net.Dialer{}
		conn, err := dialer.DialContext(ctx, "tcp", address)
		if err != nil {
			status.Status = "not_ready"
			failures = append(failures, name)
		} else {
			_ = conn.Close()
		}
		deps = append(deps, status)
	}
	if len(failures) > 0 {
		return deps, fmt.Errorf("dependencies not ready: %s", strings.Join(failures, ","))
	}
	return deps, nil
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
