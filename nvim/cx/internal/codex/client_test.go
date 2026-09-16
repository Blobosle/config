package codex

import (
	"bufio"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"testing"
)

func TestForkInitializesConnectionAndReturnsChildID(t *testing.T) {
	t.Parallel()

	dir, err := os.MkdirTemp("/tmp", "cx-client-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(dir) })
	socket := filepath.Join(dir, "app.sock")
	listener, err := net.Listen("unix", socket)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()

	done := make(chan error, 1)
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			done <- err
			return
		}
		defer conn.Close()
		scanner := bufio.NewScanner(conn)
		encoder := json.NewEncoder(conn)
		for scanner.Scan() {
			var request map[string]any
			if err := json.Unmarshal(scanner.Bytes(), &request); err != nil {
				done <- err
				return
			}
			switch request["method"] {
			case "initialize":
				_ = encoder.Encode(map[string]any{"id": request["id"], "result": map[string]any{}})
			case "initialized":
			case "thread/fork":
				params := request["params"].(map[string]any)
				if params["threadId"] != "root-thread" || params["cwd"] != "/tmp/task" {
					done <- &protocolError{"unexpected fork params"}
					return
				}
				_ = encoder.Encode(map[string]any{"id": request["id"], "result": map[string]any{"thread": map[string]any{"id": "child-thread"}}})
				done <- nil
				return
			}
		}
		done <- scanner.Err()
	}()

	client := New(socket)
	id, err := client.Fork("root-thread", "/tmp/task")
	if err != nil {
		t.Fatal(err)
	}
	if id != "child-thread" {
		t.Fatalf("Fork() = %q", id)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

type protocolError struct{ message string }

func (e *protocolError) Error() string { return e.message }
