package app

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/benjaminlobos/cx/internal/domain"
	"github.com/benjaminlobos/cx/internal/gitx"
	"github.com/benjaminlobos/cx/internal/state"
)

func TestLandCreatesOneCommitAndFastForwardsBase(t *testing.T) {
	repo := initGitRepo(t)
	store := state.New(filepath.Join(t.TempDir(), "state"))
	git := gitx.New()
	if err := git.ExcludeWorktrees(repo); err != nil {
		t.Fatal(err)
	}
	base, err := git.Head(repo)
	if err != nil {
		t.Fatal(err)
	}
	project := domain.Project{
		ID: "project", ScopeRoot: repo, GitRoot: repo, BaseBranch: "main", BaseCommit: base,
		CreatedAt: time.Now(),
	}
	if err := store.CreateProject(project); err != nil {
		t.Fatal(err)
	}
	worktree := filepath.Join(repo, ".agents", "worktrees", "feat", "land")
	if err := git.CreateWorktree(repo, worktree, "feat/land", "main"); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(worktree, "one.txt"), []byte("one\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gitRun(t, worktree, "add", "one.txt")
	gitRun(t, worktree, "commit", "-m", "temporary one")
	if err := os.WriteFile(filepath.Join(worktree, "two.txt"), []byte("two\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gitRun(t, worktree, "add", "two.txt")
	gitRun(t, worktree, "commit", "-m", "temporary two")

	task := domain.Task{
		ID: "task", ProjectID: project.ID, Message: "feat: land once", Branch: "feat/land",
		Worktree: worktree, ScopeRoot: worktree, ForkCommit: base, CodexThreadID: "owner",
		Status: domain.TaskReady, CreatedAt: time.Now(),
	}
	if err := store.SaveTask(task); err != nil {
		t.Fatal(err)
	}
	t.Setenv("CODEX_THREAD_ID", "owner")
	application := &App{Store: store, Git: git, Out: os.Stdout, ErrOut: os.Stderr, Now: time.Now}
	if err := application.Land(repo, task.ID, "", false, false); err != nil {
		t.Fatal(err)
	}

	count, err := git.Output(repo, "rev-list", "--count", base+"..main")
	if err != nil || count != "1" {
		t.Fatalf("landed commit count = %q, %v", count, err)
	}
	message, err := git.Output(repo, "log", "-1", "--format=%s", "main")
	if err != nil || message != task.Message {
		t.Fatalf("landed message = %q, %v", message, err)
	}
	updated, err := store.Task(project.ID, task.ID)
	if err != nil || updated.Status != domain.TaskLanded || updated.LandedCommit == "" {
		t.Fatalf("updated Task = %#v, %v", updated, err)
	}
}

func initGitRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	for _, args := range [][]string{
		{"init", "-b", "main"},
		{"config", "user.email", "cx@example.invalid"},
		{"config", "user.name", "cx test"},
	} {
		gitRun(t, dir, args...)
	}
	if err := os.WriteFile(filepath.Join(dir, "README.md"), []byte("root\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gitRun(t, dir, "add", "README.md")
	gitRun(t, dir, "commit", "-m", "root")
	return dir
}

func gitRun(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_CONFIG_NOSYSTEM=1")
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %s: %s: %v", strings.Join(args, " "), output, err)
	}
}
