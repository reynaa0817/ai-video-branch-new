package main

import (
	"context"
	"crypto/sha256"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/aif-go/ag-core/ag/ag_conf"
	agnacosconfig "github.com/aif-go/ag-core/contribute/agnacos/config"
	"github.com/aif-go/ag-core/contribute/agnacos/common"
	"github.com/aif-go/ag-core/contribute/agredis"
	"github.com/nacos-group/nacos-sdk-go/vo"
)

const (
	dataID = "base002-agcore-runtime.yaml"
	group  = "DEFAULT_GROUP"
)

func mustEnv(name string) string {
	value := os.Getenv(name)
	if value == "" {
		panic(name + " is required")
	}
	return value
}

func digestFile(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	return fmt.Sprintf("%x", sha256.Sum256(data))
}

func waitFor(path string, timeout time.Duration) {
	deadline := time.Now().Add(timeout)
	for {
		if _, err := os.Stat(path); err == nil {
			return
		}
		if time.Now().After(deadline) {
			panic("event probe timeout: " + path)
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func newNacosClient() (*agnacosconfig.NacosConfigProperties, interface {
	PublishConfig(vo.ConfigParam) (bool, error)
	GetConfig(vo.ConfigParam) (string, error)
}) {
	props := &agnacosconfig.NacosConfigProperties{
		Enable: true,
		SCProperties: common.SCProperties{
			ServerAddr: mustEnv("NACOS_ADDR"),
			LogLevel:   "error",
		},
	}
	client, err := agnacosconfig.NewNacosConfigClient(props)
	if err != nil {
		panic(err)
	}
	return props, client
}

func runNacosPhase() {
	_, client := newNacosClient()
	content := mustEnv("CONFIG_CONTENT")
	action := mustEnv("PHASE_ACTION")
	if action == "publish" {
		ok, err := client.PublishConfig(vo.ConfigParam{DataId: dataID, Group: group, Content: content, Type: vo.YAML})
		if err != nil || !ok {
			panic(fmt.Sprintf("publish failed: ok=%v err=%v", ok, err))
		}
	}
	deadline := time.Now().Add(30 * time.Second)
	for {
		loaded, err := client.GetConfig(vo.ConfigParam{DataId: dataID, Group: group})
		if err == nil && loaded == content {
			fmt.Printf("NACOS_PHASE_%s=PASS\n", strings.ToUpper(action))
			return
		}
		if time.Now().After(deadline) {
			panic(fmt.Sprintf("Nacos phase %s mismatch: content=%q err=%v", action, loaded, err))
		}
		time.Sleep(100 * time.Millisecond)
	}
}

func newRedisClient() agredis.AgRedisClient {
	client, err := agredis.CreateClientByBuilder(&agredis.AgRedisClientBuilder{Config: &agredis.AgRedisProperties{
		Type: agredis.TypeUniversal,
		Config: agredis.AgUniversalOptionsProperties{
			Addrs: []string{mustEnv("REDIS_ADDR")}, DialTimeout: 2 * time.Second,
			ReadTimeout: 2 * time.Second, WriteTimeout: 2 * time.Second,
		},
	}})
	if err != nil {
		panic(err)
	}
	return client
}

func runRedisPhase() {
	client := newRedisClient()
	defer client.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	for _, item := range strings.Split(mustEnv("CACHE_ITEMS"), ",") {
		parts := strings.SplitN(item, "=", 2)
		if len(parts) != 2 {
			panic("invalid CACHE_ITEMS entry: " + item)
		}
		if os.Getenv("PHASE_ACTION") == "write" {
			if err := client.Set(ctx, parts[0], parts[1], 0).Err(); err != nil {
				panic(err)
			}
		}
		got, err := client.Get(ctx, parts[0]).Result()
		if err != nil || got != parts[1] {
			panic(fmt.Sprintf("Redis phase mismatch for %s: got=%q err=%v", parts[0], got, err))
		}
	}
	fmt.Printf("REDIS_PHASE_%s=PASS\n", strings.ToUpper(mustEnv("PHASE_ACTION")))
}

func main() {
	switch os.Getenv("MODE") {
	case "nacos-phase":
		runNacosPhase()
		return
	case "redis-phase":
		runRedisPhase()
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	evidence := mustEnv("EVIDENCE_DIR")
	factFile := mustEnv("FACT_FILE")
	readyFile := mustEnv("READY_FILE")
	continueFile := mustEnv("CONTINUE_FILE")
	nacosAddr := mustEnv("NACOS_ADDR")
	redisAddr := mustEnv("REDIS_ADDR")

	factDigest := digestFile(factFile)

	env, err := ag_conf.NewStandardEnvironment()
	if err != nil {
		panic(err)
	}
	env.GetPropertySources().AddLast(ag_conf.NewPropertiesPropertySource("base002-local", map[string]any{
		"app.feature": "local-fallback",
		"app.owner":   "architecture",
	}))

	nacosProps := &agnacosconfig.NacosConfigProperties{
		Enable: true,
		SCProperties: common.SCProperties{
			ServerAddr: nacosAddr,
			LogLevel:   "error",
		},
		DataIDs: []agnacosconfig.DataIDInfo{{
			DataID: dataID, Group: group, Type: "yaml", AutoRefresh: false,
		}},
	}
	nacosClient, err := agnacosconfig.NewNacosConfigClient(nacosProps)
	if err != nil {
		panic(err)
	}
	content := "app:\n  feature: remote-snapshot\n  owner: sre\n"
	published, err := nacosClient.PublishConfig(vo.ConfigParam{
		DataId: dataID, Group: group, Content: content, Type: vo.YAML,
	})
	if err != nil || !published {
		panic(fmt.Sprintf("publish config failed: published=%v err=%v", published, err))
	}
	var loaded string
	configDeadline := time.Now().Add(30 * time.Second)
	for loaded != content {
		loaded, err = nacosClient.GetConfig(vo.ConfigParam{DataId: dataID, Group: group})
		if err != nil {
			panic(fmt.Sprintf("get config failed: %v", err))
		}
		if time.Now().After(configDeadline) {
			panic(fmt.Sprintf("get config mismatch: content=%q", loaded))
		}
		time.Sleep(100 * time.Millisecond)
	}
	if err := agnacosconfig.EnableNacosRemoteConfig(env, nacosClient, nacosProps); err != nil {
		panic(err)
	}
	if got := env.GetProperty("app.feature"); got != "remote-snapshot" {
		panic("AgConf layering mismatch: " + got)
	}
	if err := os.WriteFile(evidence+"/nacos-config-snapshot.yaml", []byte(loaded), 0o600); err != nil {
		panic(err)
	}
	snapshotDigest := fmt.Sprintf("%x", sha256.Sum256([]byte(loaded)))
	if err := os.WriteFile(evidence+"/nacos-config-snapshot.sha256", []byte(snapshotDigest+"  nacos-config-snapshot.yaml\n"), 0o600); err != nil {
		panic(err)
	}

	redisClient, err := agredis.CreateClientByBuilder(&agredis.AgRedisClientBuilder{Config: &agredis.AgRedisProperties{
		Type: agredis.TypeUniversal,
		Config: agredis.AgUniversalOptionsProperties{
			Addrs: []string{redisAddr}, DialTimeout: 2 * time.Second,
			ReadTimeout: 2 * time.Second, WriteTimeout: 2 * time.Second,
		},
	}})
	if err != nil {
		panic(err)
	}
	defer redisClient.Close()
	if err := redisClient.Ping(ctx).Err(); err != nil {
		panic(err)
	}
	if err := redisClient.Set(ctx, "base002:derived-cache", factDigest, 0).Err(); err != nil {
		panic(err)
	}
	if got, err := redisClient.Get(ctx, "base002:derived-cache").Result(); err != nil || got != factDigest {
		panic(fmt.Sprintf("cache mismatch: got=%q err=%v", got, err))
	}

	if err := os.WriteFile(readyFile, []byte("ready\n"), 0o600); err != nil {
		panic(err)
	}
	fmt.Println("BASE002_AGCORE_READY")
	waitFor(continueFile, 45*time.Second)

	afterFailure, failureErr := nacosClient.GetConfig(vo.ConfigParam{DataId: dataID, Group: group})
	if failureErr == nil && afterFailure != content {
		panic(fmt.Sprintf("Nacos failure returned an unsafe config: %q", afterFailure))
	}
	if got := env.GetProperty("app.feature"); got != "remote-snapshot" {
		panic("established Nacos snapshot was not retained: " + got)
	}

	redisDeadline := time.Now().Add(30 * time.Second)
	for redisClient.Ping(context.Background()).Err() != nil {
		if time.Now().After(redisDeadline) {
			panic("replacement Redis did not become reachable")
		}
		time.Sleep(100 * time.Millisecond)
	}
	if value, err := redisClient.Get(context.Background(), "base002:derived-cache").Result(); err == nil || strings.TrimSpace(value) != "" {
		panic(fmt.Sprintf("cache survived empty Redis replacement: value=%q err=%v", value, err))
	}
	if after := digestFile(factFile); after != factDigest {
		panic(fmt.Sprintf("business fact source changed: before=%s after=%s", factDigest, after))
	}

	fmt.Printf("NACOS_AGNACOS_COMPATIBILITY=PASS\n")
	fmt.Printf("NACOS_AGCONF_LAYERING=PASS\n")
	fmt.Printf("NACOS_CONFIG_SNAPSHOT=PASS digest=%s\n", snapshotDigest)
	fmt.Printf("NACOS_FAILURE_SEMANTICS=PASS retained=remote-snapshot\n")
	fmt.Printf("REDIS_AGREDIS_COMPATIBILITY=PASS\n")
	fmt.Printf("REDIS_CACHE_LOSS_SEMANTICS=PASS\n")
	fmt.Printf("REDIS_FACT_SOURCE_UNCHANGED=PASS digest=%s\n", factDigest)
}
