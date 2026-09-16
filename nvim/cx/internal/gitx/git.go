package gitx

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type Git struct{}

func New() *Git { return &Git{} }

func (g *Git) Root(dir string) (string, error) { return g.output(dir, "rev-parse", "--show-toplevel") }
func (g *Git) Branch(dir string) (string, error) {
	branch, err := g.output(dir, "symbolic-ref", "--quiet", "--short", "HEAD")
	if err != nil {
		return "", fmt.Errorf("detached HEAD is not supported: %w", err)
	}
	return branch, nil
}
func (g *Git) Head(dir string) (string, error) { return g.output(dir, "rev-parse", "HEAD") }

func (g *Git) IsClean(dir string) (bool, error) {
	out, err := g.output(dir, "status", "--porcelain=v1", "--untracked-files=all")
	return out == "", err
}

func (g *Git) OperationInProgress(dir string) (bool, error) {
	for _, marker := range []string{"MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply"} {
		path, err := g.output(dir, "rev-parse", "--path-format=absolute", "--git-path", marker)
		if err != nil {
			return false, err
		}
		if _, err := os.Stat(path); err == nil {
			return true, nil
		} else if !os.IsNotExist(err) {
			return false, err
		}
	}
	return false, nil
}

func (g *Git) BranchExists(dir, branch string) bool {
	return g.run(dir, nil, "show-ref", "--verify", "--quiet", "refs/heads/"+branch) == nil
}

func (g *Git) CreateWorktree(repo, path, branch, base string) error {
	if g.BranchExists(repo, branch) {
		return fmt.Errorf("branch %q already exists; cx never adopts existing branches", branch)
	}
	if _, err := os.Stat(path); err == nil {
		return fmt.Errorf("worktree path already exists: %s", path)
	} else if !os.IsNotExist(err) {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	baseCommit, err := g.output(repo, "rev-parse", base)
	if err != nil {
		return err
	}
	if err := g.run(repo, nil, "worktree", "add", "--no-checkout", "-b", branch, path, base); err != nil {
		return fmt.Errorf("create worktree: %w", err)
	}
	if err := g.run(path, nil, "reset", "--hard", baseCommit); err != nil {
		_ = g.RemoveWorktree(repo, path)
		_ = g.DeleteBranchIfAt(repo, branch, baseCommit)
		return fmt.Errorf("check out worktree: %w", err)
	}
	return nil
}

func (g *Git) RemoveWorktree(repo, path string) error {
	return g.run(repo, nil, "worktree", "remove", path)
}

func (g *Git) DeleteBranch(repo, branch string) error {
	return g.run(repo, nil, "branch", "-d", branch)
}
func (g *Git) DeleteBranchIfAt(repo, branch, expectedCommit string) error {
	return g.run(repo, nil, "update-ref", "-d", "refs/heads/"+branch, expectedCommit)
}
func (g *Git) Diff(dir, base string) (string, error) {
	return g.output(dir, "diff", "--stat", base+"...HEAD")
}

func (g *Git) ExcludeWorktrees(repo string) error {
	path, err := g.output(repo, "rev-parse", "--path-format=absolute", "--git-path", "info/exclude")
	if err != nil {
		return err
	}
	data, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	line := ".agents/worktrees/"
	for _, existing := range strings.Split(string(data), "\n") {
		if strings.TrimSpace(existing) == line {
			return nil
		}
	}
	if len(data) > 0 && data[len(data)-1] != '\n' {
		data = append(data, '\n')
	}
	data = append(data, line...)
	data = append(data, '\n')
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

func (g *Git) Run(dir string, env []string, args ...string) error { return g.run(dir, env, args...) }
func (g *Git) Output(dir string, args ...string) (string, error)  { return g.output(dir, args...) }
func (g *Git) IsAncestor(dir, ancestor, descendant string) bool {
	return g.run(dir, nil, "merge-base", "--is-ancestor", ancestor, descendant) == nil
}

func (g *Git) output(dir string, args ...string) (string, error) {
	var stdout bytes.Buffer
	if err := g.command(dir, nil, &stdout, args...); err != nil {
		return "", err
	}
	return strings.TrimSpace(stdout.String()), nil
}

func (g *Git) run(dir string, env []string, args ...string) error {
	return g.command(dir, env, nil, args...)
}

func (g *Git) command(dir string, env []string, stdout *bytes.Buffer, args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), env...)
	if stdout != nil {
		cmd.Stdout = stdout
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("git %s: %s: %w", strings.Join(args, " "), strings.TrimSpace(stderr.String()), err)
	}
	return nil
}
