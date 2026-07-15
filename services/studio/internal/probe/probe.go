package probe

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/IBM/sarama"
	"github.com/aif-go/ag-core/ag/ag_log"
	"github.com/aif-go/ag-core/contribute/agdb"
	"github.com/aif-go/ag-core/contribute/agdb/conditonwhere"
	"github.com/aif-go/ag-core/contribute/agdb/gormdb"
	"github.com/aif-go/ag-core/contribute/agsarama"
	"github.com/aif-go/ag-core/fxs"
	"github.com/frochyzhang/ai-video/services/studio/internal/repository/dao"
	"github.com/frochyzhang/ai-video/services/studio/internal/repository/model"
	"go.uber.org/fx"
)

const (
	topic              = "ai-video-story13-events"
	envelopeSchema     = "ai.video.platform.v1.DomainEventEnvelope"
	expectedOwner      = "studio"
	expectedEventKind  = "ProjectCreationSkeleton"
	publishedAtPending = "1970-01-01T00:00:01Z"
)

type Envelope struct {
	EventID          string          `json:"event_id"`
	WorkspaceID      string          `json:"workspace_id"`
	AggregateID      string          `json:"aggregate_id"`
	AggregateVersion int64           `json:"aggregate_version"`
	OwnerDomain      string          `json:"owner_domain"`
	EventKind        string          `json:"event_kind"`
	SchemaVersion    string          `json:"schema_version"`
	OccurredAt       string          `json:"occurred_at"`
	Producer         string          `json:"producer"`
	Trace            TraceEnvelope   `json:"trace"`
	Payload          string          `json:"payload"`
	Raw              json.RawMessage `json:"-"`
}

type TraceEnvelope struct {
	TraceID   string `json:"trace_id"`
	SpanID    string `json:"span_id"`
	RequestID string `json:"request_id"`
}

type runner struct {
	factDao   dao.IStory13FactDao
	outboxDao dao.IStory13OutboxDao
	guardDao  dao.IStory13GuardedCommandDao
	tm        agdb.TransactionManager
	kafka     sarama.Client
}

func newRunner(fact dao.IStory13FactDao, outbox dao.IStory13OutboxDao, guard dao.IStory13GuardedCommandDao, tm agdb.TransactionManager, kafka sarama.Client) *runner {
	return &runner{factDao: fact, outboxDao: outbox, guardDao: guard, tm: tm, kafka: kafka}
}

func newKafkaClient(lifecycle fx.Lifecycle) (sarama.Client, error) {
	cfg := agsarama.NewDefaultConfig()
	cfg.Brokers = splitList(envDefault("KAFKA_BROKERS", "kafka:29092"))
	cfg.Producer.Return.Successes = true
	cfg.Producer.RequiredAcks = agsarama.RequiredAcksWaitForAll
	cfg.Producer.Retry.Max = 5
	client, err := agsarama.NewClientWithAgConfig(cfg)
	if err != nil {
		return nil, err
	}
	lifecycle.Append(fx.Hook{OnStop: func(context.Context) error { return client.Close() }})
	return client, nil
}

func Run(ctx context.Context, mode string) error {
	r, stop, err := startDB(ctx)
	if err != nil {
		return err
	}
	defer stop()
	switch mode {
	case "record-probe":
		return r.record(ctx)
	case "inspect-roundtrip":
		return r.inspectRoundtrip(ctx)
	case "advance-platform-state":
		return r.advancePlatformState(ctx)
	case "inspect-platform-state":
		return r.inspectPlatformState(ctx)
	default:
		return fmt.Errorf("unknown probe mode %q", mode)
	}
}

func Serve(ctx context.Context) error {
	r, stop, err := startRelay(ctx)
	if err != nil {
		return err
	}
	defer stop()
	if err := r.ensureTopic(); err != nil {
		return err
	}
	return r.relayLoop(ctx)
}

func CheckDatabase(ctx context.Context) error {
	r, stop, err := startDB(ctx)
	if err != nil {
		return err
	}
	defer stop()
	_, err = r.factDao.FindByPrimaryKey(ctx, model.Story13FactPrimaryKey("__story13_readiness_probe__"))
	return err
}

func startDB(ctx context.Context) (*runner, func(), error) {
	var r *runner
	app := fx.New(
		fxs.FxAgConfModule,
		ag_log.FxAglogMode,
		gormdb.FxAicGromdbModule,
		agdb.FxAgDbModule,
		fx.Provide(dao.NewStory13FactDao, dao.NewStory13OutboxDao, dao.NewStory13GuardedCommandDao, func(fact dao.IStory13FactDao, outbox dao.IStory13OutboxDao, guard dao.IStory13GuardedCommandDao, tm agdb.TransactionManager) *runner {
			return &runner{factDao: fact, outboxDao: outbox, guardDao: guard, tm: tm}
		}),
		fx.Populate(&r),
	)
	if err := app.Start(ctx); err != nil {
		return nil, nil, err
	}
	return r, func() { _ = app.Stop(context.Background()) }, nil
}

func startRelay(ctx context.Context) (*runner, func(), error) {
	var r *runner
	app := fx.New(
		fxs.FxAgConfModule,
		ag_log.FxAglogMode,
		gormdb.FxAicGromdbModule,
		agdb.FxAgDbModule,
		fx.Provide(newKafkaClient, dao.NewStory13FactDao, dao.NewStory13OutboxDao, dao.NewStory13GuardedCommandDao, newRunner),
		fx.Populate(&r),
	)
	if err := app.Start(ctx); err != nil {
		return nil, nil, err
	}
	return r, func() { _ = app.Stop(context.Background()) }, nil
}

func (r *runner) record(ctx context.Context) error {
	raw, err := decodeRequired("PROBE_ENVELOPE_BASE64")
	if err != nil {
		return err
	}
	event, err := decodeEnvelope(raw)
	if err != nil {
		return err
	}
	pendingAt, _ := time.Parse(time.RFC3339, publishedAtPending)
	err = agdb.WithTransaction(ctx, r.tm, agdb.TRANSACTION_PROPAGATION_REQUIRED, func(txctx context.Context) error {
		existing, err := r.factDao.FindByPrimaryKey(txctx, model.Story13FactPrimaryKey(event.EventID))
		if err != nil {
			return err
		}
		if existing != nil {
			if existing.EnvelopeJson != string(raw) {
				return fmt.Errorf("event %s already exists with different envelope", event.EventID)
			}
			return nil
		}
		if _, err := r.factDao.InsertOne(txctx, &model.Story13Fact{EventId: event.EventID, AggregateId: event.AggregateID, AggregateVersion: event.AggregateVersion, EnvelopeJson: string(raw)}); err != nil {
			return fmt.Errorf("persist fact: %w", err)
		}
		if _, err := r.outboxDao.InsertOne(txctx, &model.Story13Outbox{EventId: event.EventID, EnvelopeJson: string(raw), Published: 0, KafkaPartition: -1, KafkaOffset: -1, PublishedAt: pendingAt}); err != nil {
			return fmt.Errorf("persist outbox: %w", err)
		}
		return nil
	})
	if err != nil {
		return err
	}
	return writeJSON(map[string]any{"event_id": event.EventID, "accepted": true, "published": false})
}

func (r *runner) ensureTopic() error {
	admin, err := sarama.NewClusterAdminFromClient(r.kafka)
	if err != nil {
		return fmt.Errorf("create kafka admin: %w", err)
	}
	defer admin.Close()
	err = admin.CreateTopic(topic, &sarama.TopicDetail{NumPartitions: 1, ReplicationFactor: 1}, false)
	if err != nil && !errors.Is(err, sarama.ErrTopicAlreadyExists) {
		return fmt.Errorf("create topic %s: %w", topic, err)
	}
	return nil
}

func (r *runner) relayLoop(ctx context.Context) error {
	producer, err := sarama.NewSyncProducerFromClient(r.kafka)
	if err != nil {
		return fmt.Errorf("create producer: %w", err)
	}
	defer producer.Close()
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for {
		if err := r.relayOnce(ctx, producer); err != nil {
			fmt.Fprintf(os.Stderr, "story13 outbox relay failed: %v\n", err)
		}
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
		}
	}
}

func (r *runner) relayOnce(ctx context.Context, producer sarama.SyncProducer) error {
	cond := conditonwhere.NewWhereClauseBuilder().Eq("PUBLISHED", 0)
	rows, _, err := r.outboxDao.FindByCondition(ctx, cond, nil, &gormdb.Page{PageNum: 1, PageSize: 50})
	if err != nil {
		return err
	}
	for _, row := range rows {
		event, err := decodeEnvelope([]byte(row.EnvelopeJson))
		if err != nil {
			return fmt.Errorf("invalid outbox envelope %s: %w", row.EventId, err)
		}
		partition, offset, err := producer.SendMessage(&sarama.ProducerMessage{Topic: topic, Key: sarama.StringEncoder(row.EventId), Value: sarama.StringEncoder(row.EnvelopeJson)})
		if err != nil {
			return fmt.Errorf("publish %s: %w", row.EventId, err)
		}
		row.Published = 1
		row.KafkaPartition = int(partition)
		row.KafkaOffset = offset
		row.PublishedAt = time.Now().UTC()
		if _, err := r.outboxDao.UpdateByPrimaryKey(ctx, row); err != nil {
			return fmt.Errorf("mark %s published: %w", row.EventId, err)
		}
		_ = event
	}
	return nil
}

func (r *runner) inspectRoundtrip(ctx context.Context) error {
	eventID, err := required("PROBE_EVENT_ID")
	if err != nil {
		return err
	}
	fact, err := r.factDao.FindByPrimaryKey(ctx, model.Story13FactPrimaryKey(eventID))
	if err != nil {
		return err
	}
	outbox, err := r.outboxDao.FindByPrimaryKey(ctx, model.Story13OutboxPrimaryKey(eventID))
	if err != nil {
		return err
	}
	if fact == nil || outbox == nil {
		return errors.New("fact or outbox not found")
	}
	event, err := decodeEnvelope([]byte(fact.EnvelopeJson))
	if err != nil {
		return err
	}
	return writeJSON(map[string]any{
		"fact":   map[string]any{"event_id": fact.EventId, "workspace_id": event.WorkspaceID, "aggregate_id": fact.AggregateId, "aggregate_version": fact.AggregateVersion, "envelope_digest": digest(fact.EnvelopeJson), "storage": "mysql.STORY13_FACT"},
		"outbox": map[string]any{"event_id": outbox.EventId, "published": outbox.Published == 1, "partition": outbox.KafkaPartition, "offset": outbox.KafkaOffset, "envelope_digest": digest(outbox.EnvelopeJson), "storage": "mysql.STORY13_OUTBOX"},
	})
}

func (r *runner) advancePlatformState(ctx context.Context) error {
	commandID, err := required("PROBE_COMMAND_ID")
	if err != nil {
		return err
	}
	dependency, err := required("PROBE_DEPENDENCY")
	if err != nil {
		return err
	}
	endpoint, ok := platformDependencyEndpoints()[dependency]
	if !ok {
		return fmt.Errorf("unsupported dependency %q", dependency)
	}
	if err := probeDependency(ctx, dependency, endpoint); err != nil {
		return fmt.Errorf("command rejected: %s unavailable: %w", dependency, err)
	}
	existing, err := r.guardDao.FindByPrimaryKey(ctx, model.Story13GuardedCommandPrimaryKey(commandID))
	if err != nil {
		return err
	}
	if existing != nil {
		return writeJSON(map[string]any{"command_id": commandID, "dependency": dependency, "state_advanced": existing.StateAdvanced == 1})
	}
	_, err = r.guardDao.InsertOne(ctx, &model.Story13GuardedCommand{CommandId: commandID, DependencyName: dependency, StateAdvanced: 1})
	if err != nil {
		return fmt.Errorf("advance platform state: %w", err)
	}
	return writeJSON(map[string]any{"command_id": commandID, "dependency": dependency, "state_advanced": true})
}

func (r *runner) inspectPlatformState(ctx context.Context) error {
	commandID, err := required("PROBE_COMMAND_ID")
	if err != nil {
		return err
	}
	row, err := r.guardDao.FindByPrimaryKey(ctx, model.Story13GuardedCommandPrimaryKey(commandID))
	if err != nil {
		return err
	}
	return writeJSON(map[string]any{"command_id": commandID, "found": row != nil, "state_advanced": row != nil && row.StateAdvanced == 1})
}

func decodeEnvelope(raw []byte) (*Envelope, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	var event Envelope
	if err := dec.Decode(&event); err != nil {
		return nil, fmt.Errorf("decode envelope: %w", err)
	}
	if err := dec.Decode(&struct{}{}); err != io.EOF {
		return nil, errors.New("decode envelope: trailing JSON data")
	}
	event.Raw = append(event.Raw[:0], raw...)
	if event.EventID == "" || event.WorkspaceID == "" || event.AggregateID == "" || event.AggregateVersion < 1 {
		return nil, errors.New("invalid envelope identity")
	}
	if event.OwnerDomain != expectedOwner || event.Producer != expectedOwner || event.EventKind != expectedEventKind || event.SchemaVersion != envelopeSchema {
		return nil, errors.New("invalid envelope type")
	}
	if _, err := time.Parse(time.RFC3339, event.OccurredAt); err != nil {
		return nil, fmt.Errorf("invalid occurred_at: %w", err)
	}
	if event.Trace.TraceID == "" || event.Trace.SpanID == "" || event.Trace.RequestID == "" {
		return nil, errors.New("trace identity is required")
	}
	if payload, err := base64.StdEncoding.DecodeString(event.Payload); err != nil || len(payload) == 0 {
		return nil, errors.New("payload must be non-empty base64")
	}
	return &event, nil
}

func platformDependencyEndpoints() map[string]string {
	return map[string]string{
		"budget":         "http://budget:8081/healthz",
		"object_storage": "http://minio:9000/minio/health/live",
		"quality":        "http://quality:8081/healthz",
		"temporal":       "temporal:7233",
	}
}

func probeDependency(ctx context.Context, dependency, endpoint string) error {
	switch dependency {
	case "budget", "quality", "object_storage":
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
		if err != nil {
			return err
		}
		resp, err := (&http.Client{Timeout: 2 * time.Second}).Do(req)
		if err != nil {
			return err
		}
		defer resp.Body.Close()
		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			return fmt.Errorf("status %d", resp.StatusCode)
		}
		return nil
	case "temporal":
		conn, err := (&net.Dialer{}).DialContext(ctx, "tcp", endpoint)
		if err != nil {
			return err
		}
		defer conn.Close()
		_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
		if _, err := conn.Write([]byte("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")); err != nil {
			return err
		}
		buf := make([]byte, 9)
		if _, err := conn.Read(buf); err != nil {
			return fmt.Errorf("gRPC HTTP/2 handshake: %w", err)
		}
		return nil
	default:
		return fmt.Errorf("unsupported dependency %q", dependency)
	}
}

func required(key string) (string, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return "", fmt.Errorf("%s is required", key)
	}
	return value, nil
}

func decodeRequired(key string) ([]byte, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return nil, fmt.Errorf("%s is required", key)
	}
	return base64.StdEncoding.DecodeString(value)
}

func splitList(value string) []string {
	var result []string
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			result = append(result, item)
		}
	}
	return result
}

func envDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func digest(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}

func writeJSON(value any) error { return json.NewEncoder(os.Stdout).Encode(value) }
