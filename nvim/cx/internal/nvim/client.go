package nvim

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

type Context struct {
	Socket  string `json:"socket"`
	CWD     string `json:"cwd"`
	BufType string `json:"buftype"`
	JobPID  int    `json:"job_pid"`
	NvimPID int    `json:"nvim_pid"`
	HasUI   bool   `json:"has_ui"`
}

type Snapshot struct {
	Socket  string `json:"socket"`
	PID     int    `json:"pid"`
	CWD     string `json:"cwd"`
	UICount int    `json:"ui_count"`
	Healthy bool   `json:"healthy"`
}

func CurrentTerminal() (Context, error) {
	socket := os.Getenv("NVIM")
	if socket == "" {
		return Context{}, fmt.Errorf("cx init must run inside a Neovim terminal")
	}
	var context Context
	if err := call(socket, "context", nil, &context); err != nil {
		return Context{}, fmt.Errorf("inspect Neovim terminal: %w", err)
	}
	if context.BufType != "terminal" || context.JobPID <= 0 {
		return Context{}, fmt.Errorf("cx init must run in the current Neovim terminal buffer")
	}
	owned, err := descendsFrom(os.Getpid(), context.JobPID)
	if err != nil {
		return Context{}, fmt.Errorf("verify Neovim terminal ownership: %w", err)
	}
	if !owned {
		return Context{}, fmt.Errorf("cx init caller is not a child of the current Neovim terminal job")
	}
	return context, nil
}

func descendsFrom(pid, ancestor int) (bool, error) {
	for range 64 {
		if pid == ancestor {
			return true, nil
		}
		if pid <= 1 {
			return false, nil
		}
		cmd := exec.Command("ps", "-o", "ppid=", "-p", strconv.Itoa(pid))
		output, err := cmd.Output()
		if err != nil {
			return false, err
		}
		parent, err := strconv.Atoi(strings.TrimSpace(string(output)))
		if err != nil {
			return false, err
		}
		if parent == pid {
			return false, nil
		}
		pid = parent
	}
	return false, fmt.Errorf("process ancestry exceeded 64 generations")
}

func Call(socket, method string, params any, result any) error {
	return call(socket, method, params, result)
}

func WaitHealthy(socket string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		var snapshot Snapshot
		if err := call(socket, "snapshot", nil, &snapshot); err == nil && snapshot.Healthy {
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}
	return fmt.Errorf("Neovim at %s did not become healthy", socket)
}

func Handoff(sourceSocket, targetSocket string) error {
	var ok bool
	if err := call(sourceSocket, "handoff", map[string]string{"socket": targetSocket}, &ok); err != nil {
		return err
	}
	if !ok {
		return fmt.Errorf("Neovim declined UI handoff")
	}
	return nil
}

func Send(socket, message string) error {
	var ok bool
	if err := call(socket, "send", map[string]string{"message": message}, &ok); err != nil {
		return err
	}
	if !ok {
		return fmt.Errorf("task terminal is unavailable")
	}
	return nil
}

func call(socket, method string, params any, result any) error {
	payload, err := json.Marshal(map[string]any{"method": method, "params": params})
	if err != nil {
		return err
	}
	expr := "json_encode(luaeval(\"require('user.cx').rpc(_A)\", json_decode(" + vimQuote(string(payload)) + ")))"
	cmd := exec.Command("nvim", "--server", socket, "--remote-expr", expr)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("Neovim RPC: %s: %w", strings.TrimSpace(stderr.String()), err)
	}
	if result == nil {
		return nil
	}
	text := strings.TrimSpace(stdout.String())
	if text == "" {
		return fmt.Errorf("Neovim RPC returned an empty response")
	}
	if err := json.Unmarshal([]byte(text), result); err != nil {
		return fmt.Errorf("decode Neovim RPC %s: %w", strconv.Quote(text), err)
	}
	return nil
}

func vimQuote(value string) string { return "'" + strings.ReplaceAll(value, "'", "''") + "'" }
