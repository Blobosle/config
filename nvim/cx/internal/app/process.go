package app

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/benjaminlobos/cx/internal/codex"
)

func startDetached(logPath, dir string, env []string, name string, args ...string) (int, error) {
	if err := os.MkdirAll(filepath.Dir(logPath), 0o700); err != nil {
		return 0, err
	}
	log, err := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return 0, err
	}
	defer log.Close()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = append(scrubEnv(os.Environ(), "CODEX_THREAD_ID"), env...)
	cmd.Stdin = nil
	cmd.Stdout = log
	cmd.Stderr = log
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return 0, err
	}
	return cmd.Process.Pid, nil
}

func waitForAppServer(socket string, pid int, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	client := codex.New(socket)
	client.Timeout = 500 * time.Millisecond
	var lastErr error
	for time.Now().Before(deadline) {
		if !processAlive(pid) {
			return fmt.Errorf("Codex app-server exited before becoming ready")
		}
		if err := client.Ping(); err == nil {
			return nil
		} else {
			lastErr = err
		}
		time.Sleep(100 * time.Millisecond)
	}
	return fmt.Errorf("Codex app-server did not become ready: %w", lastErr)
}

func processAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	process, err := os.FindProcess(pid)
	return err == nil && process.Signal(syscall.Signal(0)) == nil
}

func stopProcess(pid int) error {
	if !processAlive(pid) {
		return nil
	}
	process, _ := os.FindProcess(pid)
	if err := process.Signal(syscall.SIGTERM); err != nil {
		return err
	}
	for range 20 {
		if !processAlive(pid) {
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}
	return fmt.Errorf("process %d did not stop", pid)
}

func scrubEnv(env []string, keys ...string) []string {
	blocked := make(map[string]bool, len(keys))
	for _, key := range keys {
		blocked[key] = true
	}
	out := make([]string, 0, len(env))
	for _, pair := range env {
		key, _, _ := strings.Cut(pair, "=")
		if !blocked[key] {
			out = append(out, pair)
		}
	}
	return out
}
