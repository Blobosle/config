package codex

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"sync/atomic"
	"time"
)

type Client struct {
	Socket  string
	Timeout time.Duration
	nextID  atomic.Int64
}

func New(socket string) *Client { return &Client{Socket: socket, Timeout: 10 * time.Second} }

func (c *Client) Ping() error {
	conn, err := net.DialTimeout("unix", c.Socket, c.Timeout)
	if err != nil {
		return fmt.Errorf("connect to Codex app-server: %w", err)
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(c.Timeout))
	encoder := json.NewEncoder(conn)
	reader := bufio.NewReader(conn)
	id := c.nextID.Add(1)
	if err := encoder.Encode(map[string]any{
		"id": id, "method": "initialize",
		"params": map[string]any{"clientInfo": map[string]string{"name": "cx", "version": "0.1.0"}},
	}); err != nil {
		return err
	}
	if err := readResponse(reader, id, nil); err != nil {
		return fmt.Errorf("initialize app-server: %w", err)
	}
	return encoder.Encode(map[string]any{"method": "initialized"})
}

func (c *Client) Fork(threadID, cwd string) (string, error) {
	var result struct {
		Thread struct {
			ID string `json:"id"`
		} `json:"thread"`
	}
	if err := c.call("thread/fork", map[string]any{
		"threadId":              threadID,
		"cwd":                   cwd,
		"runtimeWorkspaceRoots": []string{cwd},
		"excludeTurns":          true,
		"deferGoalContinuation": true,
	}, &result); err != nil {
		return "", err
	}
	if result.Thread.ID == "" {
		return "", fmt.Errorf("thread/fork returned no child thread id")
	}
	return result.Thread.ID, nil
}

func (c *Client) Read(threadID string) error {
	var result struct {
		Thread struct {
			ID string `json:"id"`
		} `json:"thread"`
	}
	if err := c.call("thread/read", map[string]any{"threadId": threadID, "includeTurns": false}, &result); err != nil {
		return err
	}
	if result.Thread.ID != threadID {
		return fmt.Errorf("app-server returned thread %q, expected %q", result.Thread.ID, threadID)
	}
	return nil
}

func (c *Client) call(method string, params any, result any) error {
	conn, err := net.DialTimeout("unix", c.Socket, c.Timeout)
	if err != nil {
		return fmt.Errorf("connect to Codex app-server: %w", err)
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(c.Timeout))
	encoder := json.NewEncoder(conn)
	reader := bufio.NewReader(conn)

	initializeID := c.nextID.Add(1)
	if err := encoder.Encode(map[string]any{
		"id": initializeID, "method": "initialize",
		"params": map[string]any{"clientInfo": map[string]string{"name": "cx", "version": "0.1.0"}},
	}); err != nil {
		return err
	}
	if err := readResponse(reader, initializeID, nil); err != nil {
		return fmt.Errorf("initialize app-server: %w", err)
	}
	if err := encoder.Encode(map[string]any{"method": "initialized"}); err != nil {
		return err
	}

	id := c.nextID.Add(1)
	if err := encoder.Encode(map[string]any{"id": id, "method": method, "params": params}); err != nil {
		return err
	}
	if err := readResponse(reader, id, result); err != nil {
		return fmt.Errorf("%s: %w", method, err)
	}
	return nil
}

func readResponse(reader *bufio.Reader, wanted int64, result any) error {
	for {
		line, err := reader.ReadBytes('\n')
		if err != nil {
			return err
		}
		var envelope struct {
			ID     *int64          `json:"id"`
			Result json.RawMessage `json:"result"`
			Error  *struct {
				Code    int    `json:"code"`
				Message string `json:"message"`
			} `json:"error"`
		}
		if err := json.Unmarshal(line, &envelope); err != nil {
			return err
		}
		if envelope.ID == nil || *envelope.ID != wanted {
			continue
		}
		if envelope.Error != nil {
			return fmt.Errorf("app-server error %d: %s", envelope.Error.Code, envelope.Error.Message)
		}
		if result == nil || len(envelope.Result) == 0 {
			return nil
		}
		return json.Unmarshal(envelope.Result, result)
	}
}
