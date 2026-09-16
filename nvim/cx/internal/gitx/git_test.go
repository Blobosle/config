package gitx

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestCreateWorktreeNeverAdoptsExistingBranch(t *testing.T) {
	t.Parallel()

	repo := initRepo(t)
	g := New()
	if err := run(repo, "git", "branch", "feat/existing"); err != nil {
		t.Fatal(err)
	}
	err := g.CreateWorktree(repo, filepath.Join(repo, ".agents", "worktrees", "feat", "existing"), "feat/existing", "main")
	if err == nil || !strings.Contains(err.Error(), "already exists") {
		t.Fatalf("CreateWorktree() error = %v", err)
	}
}

func TestCreateWorktreeCreatesBranchAtBase(t *testing.T) {
	t.Parallel()

	repo := initRepo(t)
	g := New()
	path := filepath.Join(repo, ".agents", "worktrees", "feat", "new")
	if err := g.CreateWorktree(repo, path, "feat/new", "main"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(path, "README.md"))
	if err != nil || string(data) != "root\n" {
		t.Fatalf("worktree content = %q, %v", data, err)
	}
}

func TestDeleteBranchIfAtPreservesBranchThatMoved(t *testing.T) {
	t.Parallel()

	repo := initRepo(t)
	g := New()
	base, err := g.Head(repo)
	if err != nil {
		t.Fatal(err)
	}
	if err := run(repo, "git", "branch", "feat/moved"); err != nil {
		t.Fatal(err)
	}
	if err := run(repo, "git", "checkout", "feat/moved"); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repo, "moved.txt"), []byte("moved\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := run(repo, "git", "add", "moved.txt"); err != nil {
		t.Fatal(err)
	}
	if err := run(repo, "git", "commit", "-m", "move branch"); err != nil {
		t.Fatal(err)
	}
	if err := g.DeleteBranchIfAt(repo, "feat/moved", base); err == nil {
		t.Fatal("expected atomic deletion to reject a moved branch")
	}
	if !g.BranchExists(repo, "feat/moved") {
		t.Fatal("moved branch was deleted")
	}
}

func initRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	for _, args := range [][]string{
		{"git", "init", "-b", "main"},
		{"git", "config", "user.email", "cx@example.invalid"},
		{"git", "config", "user.name", "cx test"},
	} {
		if err := run(dir, args[0], args[1:]...); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "README.md"), []byte("root\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := run(dir, "git", "add", "README.md"); err != nil {
		t.Fatal(err)
	}
	if err := run(dir, "git", "commit", "-m", "root"); err != nil {
		t.Fatal(err)
	}
	return dir
}

func run(dir, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_CONFIG_NOSYSTEM=1")
	return cmd.Run()
}
