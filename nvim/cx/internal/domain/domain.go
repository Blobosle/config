package domain

import "time"

type Project struct {
	ID                string    `json:"id"`
	ScopeRoot         string    `json:"scope_root"`
	GitRoot           string    `json:"git_root"`
	BaseBranch        string    `json:"base_branch"`
	BaseCommit        string    `json:"base_commit"`
	NvimSocket        string    `json:"nvim_socket"`
	NvimPID           int       `json:"nvim_pid"`
	AppServerSocket   string    `json:"app_server_socket"`
	AppServerPID      int       `json:"app_server_pid"`
	RootCodexThreadID string    `json:"root_codex_thread_id,omitempty"`
	CreatedAt         time.Time `json:"created_at"`
}

type Task struct {
	ID            string    `json:"id"`
	ProjectID     string    `json:"project_id"`
	Message       string    `json:"message"`
	Branch        string    `json:"branch"`
	Worktree      string    `json:"worktree"`
	ScopeRoot     string    `json:"scope_root"`
	ForkCommit    string    `json:"fork_commit"`
	CodexThreadID string    `json:"codex_thread_id"`
	NvimSocket    string    `json:"nvim_socket"`
	NvimPID       int       `json:"nvim_pid"`
	Status        string    `json:"status"`
	LandedCommit  string    `json:"landed_commit,omitempty"`
	Operation     string    `json:"operation,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
}

const (
	TaskCreating = "creating"
	TaskReady    = "ready"
	TaskConflict = "conflict"
	TaskLanded   = "landed"
)
