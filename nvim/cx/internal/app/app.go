package app

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/benjaminlobos/cx/internal/codex"
	"github.com/benjaminlobos/cx/internal/domain"
	"github.com/benjaminlobos/cx/internal/gitx"
	"github.com/benjaminlobos/cx/internal/nvim"
	"github.com/benjaminlobos/cx/internal/state"
)

type App struct {
	Store  *state.Store
	Git    *gitx.Git
	Out    io.Writer
	ErrOut io.Writer
	Now    func() time.Time
}

type ListItem struct {
	Kind          string `json:"kind"`
	ID            string `json:"id"`
	ProjectID     string `json:"project_id"`
	ProjectScope  string `json:"project_scope"`
	Message       string `json:"message"`
	Branch        string `json:"branch"`
	Status        string `json:"status"`
	Attached      bool   `json:"attached"`
	NvimSocket    string `json:"nvim_socket"`
	Worktree      string `json:"worktree"`
	CodexThreadID string `json:"codex_thread_id,omitempty"`
}

func New() (*App, error) {
	root, err := StateRoot()
	if err != nil {
		return nil, err
	}
	return &App{Store: state.New(root), Git: gitx.New(), Out: os.Stdout, ErrOut: os.Stderr, Now: time.Now}, nil
}

func StateRoot() (string, error) {
	if value := os.Getenv("CX_STATE_HOME"); value != "" {
		return value, nil
	}
	if value := os.Getenv("XDG_STATE_HOME"); value != "" {
		return filepath.Join(value, "cx"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "state", "cx"), nil
}

func (a *App) Init(cwd string) error {
	context, err := nvim.CurrentTerminal()
	if err != nil {
		return err
	}
	scope, err := filepath.Abs(cwd)
	if err != nil {
		return err
	}
	gitRoot, err := a.Git.Root(scope)
	if err != nil {
		return fmt.Errorf("cx init requires a Git repository: %w", err)
	}
	clean, err := a.Git.IsClean(gitRoot)
	if err != nil {
		return err
	}
	if !clean {
		return fmt.Errorf("cx init requires a clean Git repository, including no untracked files")
	}
	inProgress, err := a.Git.OperationInProgress(gitRoot)
	if err != nil {
		return err
	}
	if inProgress {
		return fmt.Errorf("cx init is unavailable during an in-progress Git operation")
	}
	initLock, err := lockProject(filepath.Join(a.Store.Root, "init"))
	if err != nil {
		return err
	}
	defer initLock.Close()
	base, err := a.Git.Branch(gitRoot)
	if err != nil {
		return err
	}
	head, err := a.Git.Head(gitRoot)
	if err != nil {
		return err
	}
	projects, err := a.Store.ListProjects()
	if err != nil {
		return err
	}
	for _, project := range projects {
		if filepath.Clean(project.ScopeRoot) == filepath.Clean(scope) {
			return fmt.Errorf("project already initialized at %s", scope)
		}
		if project.NvimSocket == context.Socket {
			return fmt.Errorf("this Neovim instance already owns project %s", project.ScopeRoot)
		}
	}
	if err := a.Git.ExcludeWorktrees(gitRoot); err != nil {
		return fmt.Errorf("exclude task worktrees: %w", err)
	}

	id := stableID(scope)
	runtimeDir := filepath.Join(os.TempDir(), "cx-"+strconv.Itoa(os.Getuid()), id[:8])
	if err := os.MkdirAll(runtimeDir, 0o700); err != nil {
		return err
	}
	appSocket := filepath.Join(runtimeDir, "codex.sock")
	_ = os.Remove(appSocket)
	project := domain.Project{
		ID: id, ScopeRoot: scope, GitRoot: gitRoot, BaseBranch: base, BaseCommit: head,
		NvimSocket: context.Socket, NvimPID: context.NvimPID, AppServerSocket: appSocket,
		CreatedAt: a.Now().UTC(),
	}
	logPath := filepath.Join(a.Store.ProjectDir(id), "logs", "app-server.log")
	pid, err := startDetached(logPath, scope, nil, "codex", "app-server", "--listen", "unix://"+appSocket)
	if err != nil {
		return fmt.Errorf("start Codex app-server: %w", err)
	}
	project.AppServerPID = pid
	if err := waitForAppServer(appSocket, pid, 10*time.Second); err != nil {
		_ = stopProcess(pid)
		return err
	}
	if err := a.Store.CreateProject(project); err != nil {
		_ = stopProcess(pid)
		return err
	}
	if os.Getenv("CX_TEST_NO_EXEC") == "1" {
		return nil
	}
	path, err := exec.LookPath("codex")
	if err != nil {
		_ = a.Store.RemoveProject(project.ID)
		_ = stopProcess(pid)
		return err
	}
	argv := []string{"codex", "--remote", "unix://" + appSocket, "-C", scope}
	_ = initLock.Close()
	return syscall.Exec(path, argv, scrubEnv(os.Environ(), "CODEX_THREAD_ID"))
}

func (a *App) Task(cwd, message string) (task domain.Task, err error) {
	project, err := a.Store.ResolveProject(cwd)
	if err != nil {
		return task, err
	}
	lock, err := lockProject(a.Store.ProjectDir(project.ID))
	if err != nil {
		return task, err
	}
	defer lock.Close()

	threadID := os.Getenv("CODEX_THREAD_ID")
	if threadID == "" {
		return task, fmt.Errorf("cx task must be invoked by the Project Root Codex session")
	}
	if os.Getenv("NVIM") != project.NvimSocket {
		return task, fmt.Errorf("cx task must be invoked from the Project Root Neovim instance")
	}
	client := codex.New(project.AppServerSocket)
	if project.RootCodexThreadID == "" {
		if err := client.Read(threadID); err != nil {
			return task, fmt.Errorf("validate Root Codex thread: %w", err)
		}
		project.RootCodexThreadID = threadID
		if err := a.Store.SaveProject(project); err != nil {
			return task, err
		}
	} else if project.RootCodexThreadID != threadID {
		return task, fmt.Errorf("cx task can only be invoked by Root thread %s", project.RootCodexThreadID)
	}

	branch, err := domain.BranchFromMessage(message)
	if err != nil {
		return task, err
	}
	branch, err = domain.DisambiguateBranch(branch, project.ScopeRoot, func(candidate string) bool {
		candidatePath := filepath.Join(project.GitRoot, ".agents", "worktrees", filepath.FromSlash(candidate))
		_, pathErr := os.Stat(candidatePath)
		return a.Git.BranchExists(project.GitRoot, candidate) ||
			a.taskBranchExists(project.ID, candidate) ||
			pathErr == nil
	})
	if err != nil {
		return task, err
	}
	clean, err := a.Git.IsClean(project.GitRoot)
	if err != nil || !clean {
		if err != nil {
			return task, err
		}
		return task, fmt.Errorf("Root must be clean before creating a Task")
	}
	inProgress, err := a.Git.OperationInProgress(project.GitRoot)
	if err != nil {
		return task, err
	}
	if inProgress {
		return task, fmt.Errorf("Root has an in-progress Git operation")
	}
	baseCommit, err := a.Git.Output(project.GitRoot, "rev-parse", project.BaseBranch)
	if err != nil {
		return task, err
	}
	worktree := filepath.Join(project.GitRoot, ".agents", "worktrees", filepath.FromSlash(branch))
	scopeRel, err := filepath.Rel(project.GitRoot, project.ScopeRoot)
	if err != nil || strings.HasPrefix(scopeRel, "..") {
		return task, fmt.Errorf("Project Scope root must be inside its Git root")
	}
	taskScope := filepath.Join(worktree, scopeRel)
	taskID := stableID(project.ID + "\x00" + branch + "\x00" + a.Now().UTC().Format(time.RFC3339Nano))
	runtimeDir := filepath.Join(os.TempDir(), "cx-"+strconv.Itoa(os.Getuid()), project.ID[:8])
	socket := filepath.Join(runtimeDir, taskID[:8]+".sock")
	task = domain.Task{
		ID: taskID, ProjectID: project.ID, Message: message, Branch: branch, Worktree: worktree,
		ScopeRoot: taskScope, ForkCommit: baseCommit, NvimSocket: socket, Status: domain.TaskCreating,
		CreatedAt: a.Now().UTC(),
	}
	if err := a.Store.SaveTask(task); err != nil {
		return task, err
	}
	healthy := false
	worktreeCreated := false
	defer func() {
		if err == nil || healthy {
			return
		}
		if worktreeCreated {
			if removeErr := a.Git.RemoveWorktree(project.GitRoot, worktree); removeErr == nil {
				_ = a.Git.DeleteBranchIfAt(project.GitRoot, branch, baseCommit)
			}
		}
		_ = os.Remove(socket)
		_ = a.Store.RemoveTask(project.ID, task.ID)
	}()
	if err = a.Git.CreateWorktree(project.GitRoot, worktree, branch, project.BaseBranch); err != nil {
		return task, err
	}
	worktreeCreated = true
	childID, err := client.Fork(threadID, taskScope)
	if err != nil {
		return task, fmt.Errorf("fork Root Codex thread: %w", err)
	}
	task.CodexThreadID = childID
	if err = os.MkdirAll(runtimeDir, 0o700); err != nil {
		return task, err
	}
	_ = os.Remove(socket)
	logPath := filepath.Join(a.Store.ProjectDir(project.ID), "logs", "task-"+task.ID+".log")
	env := []string{
		"CX_PROJECT_ID=" + project.ID, "CX_TASK_ID=" + task.ID,
		"CX_CODEX_THREAD_ID=" + childID, "CX_APP_SERVER=unix://" + project.AppServerSocket,
		"CX_SCOPE_ROOT=" + taskScope,
	}
	pid, err := startDetached(logPath, taskScope, env, "nvim", "--headless", "--listen", socket,
		"-c", "lua require('user.cx').bootstrap_task()")
	if err != nil {
		return task, fmt.Errorf("start Task Neovim: %w", err)
	}
	task.NvimPID = pid
	if err = nvim.WaitHealthy(socket, 15*time.Second); err != nil {
		_ = stopProcess(pid)
		return task, err
	}
	healthy = true
	task.Status = domain.TaskReady
	if err = a.Store.SaveTask(task); err != nil {
		return task, err
	}
	if os.Getenv("NMUX_HANDOFF_FILE") != "" {
		if handoffErr := nvim.Handoff(project.NvimSocket, task.NvimSocket); handoffErr != nil {
			fmt.Fprintf(a.ErrOut, "Task created, but UI handoff failed: %v\n", handoffErr)
		}
	}
	return task, nil
}

func (a *App) List(cwd string, global bool) ([]ListItem, error) {
	var projects []domain.Project
	var err error
	if global {
		projects, err = a.Store.ListProjects()
	} else {
		project, resolveErr := a.Store.ResolveProject(cwd)
		if resolveErr != nil {
			return nil, resolveErr
		}
		projects = []domain.Project{project}
	}
	if err != nil {
		return nil, err
	}
	var items []ListItem
	for _, project := range projects {
		items = append(items, ListItem{
			Kind: "root", ID: "root", ProjectID: project.ID, ProjectScope: project.ScopeRoot,
			Message: "Root", Branch: project.BaseBranch, Status: "ready", NvimSocket: project.NvimSocket,
			Worktree: project.ScopeRoot, Attached: attached(project.NvimSocket), CodexThreadID: project.RootCodexThreadID,
		})
		tasks, listErr := a.Store.ListTasks(project.ID)
		if listErr != nil {
			return nil, listErr
		}
		for _, task := range tasks {
			items = append(items, ListItem{
				Kind: "task", ID: task.ID, ProjectID: project.ID, ProjectScope: project.ScopeRoot,
				Message: task.Message, Branch: task.Branch, Status: task.Status, NvimSocket: task.NvimSocket,
				Worktree: task.Worktree, Attached: attached(task.NvimSocket), CodexThreadID: task.CodexThreadID,
			})
		}
	}
	return items, nil
}

func (a *App) Attach(cwd, selector string) error {
	project, task, socket, err := a.target(cwd, selector)
	_ = project
	_ = task
	if err != nil {
		return err
	}
	if current := os.Getenv("NVIM"); current != "" {
		return nvim.Handoff(current, socket)
	}
	return attachLoop(socket)
}

func (a *App) Send(cwd, selector, message string) error {
	_, task, _, err := a.target(cwd, selector)
	if err != nil {
		return err
	}
	if task == nil {
		return fmt.Errorf("messages can only be sent to Tasks")
	}
	return nvim.Send(task.NvimSocket, message)
}

func (a *App) Diff(cwd, selector string) (string, error) {
	_, task, _, err := a.target(cwd, selector)
	if err != nil {
		return "", err
	}
	if task == nil {
		return "", fmt.Errorf("diff requires a Task")
	}
	return a.Git.Output(task.Worktree, "diff", task.ForkCommit)
}

func (a *App) Remove(cwd, selector string) error {
	project, task, _, err := a.target(cwd, selector)
	if err != nil {
		return err
	}
	if task == nil {
		return fmt.Errorf("Root cannot be removed")
	}
	lock, err := lockProject(a.Store.ProjectDir(project.ID))
	if err != nil {
		return err
	}
	defer lock.Close()
	clean, err := a.Git.IsClean(task.Worktree)
	if err != nil || !clean {
		return fmt.Errorf("Task worktree must be clean before removal")
	}
	if task.Status != domain.TaskLanded {
		merged, mergeErr := a.Git.Output(project.GitRoot, "branch", "--merged", project.BaseBranch, "--format=%(refname:short)")
		if mergeErr != nil || !lineContains(merged, task.Branch) {
			return fmt.Errorf("Task must be landed or merged before removal")
		}
	}
	if os.Getenv("NVIM") == task.NvimSocket && os.Getenv("CX_DEFER_REMOVE") != "1" {
		_ = lock.Close()
		return a.deferRemove(*project, *task)
	}
	if err := stopProcess(task.NvimPID); err != nil {
		return err
	}
	if err := a.Git.RemoveWorktree(project.GitRoot, task.Worktree); err != nil {
		return err
	}
	if err := a.Git.DeleteBranch(project.GitRoot, task.Branch); err != nil {
		return err
	}
	_ = os.Remove(task.NvimSocket)
	return a.Store.ArchiveTask(*task)
}

func (a *App) Rebase(cwd, selector string, continueOp bool) error {
	project, task, err := a.ownedTask(cwd, selector)
	if err != nil {
		return err
	}
	lock, err := lockProject(a.Store.ProjectDir(project.ID))
	if err != nil {
		return err
	}
	defer lock.Close()
	if !continueOp {
		clean, cleanErr := a.Git.IsClean(task.Worktree)
		if cleanErr != nil {
			return cleanErr
		}
		if !clean {
			return fmt.Errorf("Task must be clean before rebasing")
		}
	}
	args := []string{"rebase", project.BaseBranch}
	if continueOp {
		if task.Operation != "rebase" {
			return fmt.Errorf("Task has no paused rebase operation")
		}
		args = []string{"rebase", "--continue"}
	} else if task.Operation != "" {
		return fmt.Errorf("Task already has an in-progress %s", task.Operation)
	}
	err = a.Git.Run(task.Worktree, []string{"GIT_EDITOR=true"}, args...)
	if err != nil {
		paused, inspectErr := a.Git.OperationInProgress(task.Worktree)
		if inspectErr != nil {
			return inspectErr
		}
		if paused {
			task.Status = domain.TaskConflict
			task.Operation = "rebase"
			_ = a.Store.SaveTask(*task)
			return fmt.Errorf("rebase paused in Task worktree; resolve conflicts there, then run cx rebase --continue: %w", err)
		}
		return fmt.Errorf("rebase failed before Git opened a resumable operation: %w", err)
	}
	task.Status = domain.TaskReady
	task.Operation = ""
	baseHead, headErr := a.Git.Output(project.GitRoot, "rev-parse", project.BaseBranch)
	if headErr != nil {
		return headErr
	}
	task.ForkCommit = baseHead
	return a.Store.SaveTask(*task)
}

func (a *App) Land(cwd, selector, overrideMessage string, continueOp, remove bool) error {
	project, task, err := a.ownedTask(cwd, selector)
	if err != nil {
		return err
	}
	lock, err := lockProject(a.Store.ProjectDir(project.ID))
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := a.requireLandClean(*project, *task, continueOp); err != nil {
		return err
	}
	if !continueOp && task.Operation != "" {
		return fmt.Errorf("Task already has an in-progress %s", task.Operation)
	}
	if continueOp {
		if task.Operation != "land" {
			return fmt.Errorf("Task has no paused land operation")
		}
		if err := a.Git.Run(task.Worktree, []string{"GIT_EDITOR=true"}, "rebase", "--continue"); err != nil {
			return fmt.Errorf("land is still paused: %w", err)
		}
	} else {
		a.reportInterveningTasks(*project, *task)
		message := task.Message
		if overrideMessage != "" {
			message = overrideMessage
		}
		backup := fmt.Sprintf("refs/cx/backups/%s/%d", task.ID, a.Now().Unix())
		if err := a.Git.Run(task.Worktree, nil, "update-ref", backup, "HEAD"); err != nil {
			return err
		}
		if err := a.Git.Run(task.Worktree, nil, "reset", "--soft", task.ForkCommit); err != nil {
			return err
		}
		if err := a.Git.Run(task.Worktree, nil, "commit", "-m", message); err != nil {
			return fmt.Errorf("create canonical Task commit: %w", err)
		}
		if err := a.Git.Run(task.Worktree, []string{"GIT_EDITOR=true"}, "rebase", "--onto", project.BaseBranch, task.ForkCommit, task.Branch); err != nil {
			paused, inspectErr := a.Git.OperationInProgress(task.Worktree)
			if inspectErr != nil {
				return inspectErr
			}
			if paused {
				task.Status = domain.TaskConflict
				task.Operation = "land"
				_ = a.Store.SaveTask(*task)
				return fmt.Errorf("land paused in Task worktree; resolve conflicts there, then run cx land --continue: %w", err)
			}
			return fmt.Errorf("land rebase failed before Git opened a resumable operation: %w", err)
		}
	}
	currentBase, err := a.Git.Output(project.GitRoot, "rev-parse", project.BaseBranch)
	if err != nil {
		return err
	}
	if currentBase != project.BaseCommit {
		// BaseCommit is updated after every successful land; an external movement must be rebased first.
		parent, parentErr := a.Git.Output(task.Worktree, "rev-parse", "HEAD^")
		if parentErr != nil || parent != currentBase {
			return fmt.Errorf("Base branch moved; rebase the Task and land again")
		}
	}
	if err := a.Git.Run(project.GitRoot, nil, "merge", "--ff-only", task.Branch); err != nil {
		return err
	}
	landed, err := a.Git.Head(task.Worktree)
	if err != nil {
		return err
	}
	task.Status, task.Operation, task.LandedCommit = domain.TaskLanded, "", landed
	project.BaseCommit = landed
	if err := a.Store.SaveTask(*task); err != nil {
		return err
	}
	if err := a.Store.SaveProject(*project); err != nil {
		return err
	}
	if remove {
		_ = lock.Close()
		return a.deferRemove(*project, *task)
	}
	return nil
}

func (a *App) deferRemove(project domain.Project, task domain.Task) error {
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	logPath := filepath.Join(a.Store.ProjectDir(project.ID), "logs", "remove-"+task.ID+".log")
	if _, err := startDetached(logPath, project.ScopeRoot, []string{"CX_DEFER_REMOVE=1"}, executable, "remove", task.ID); err != nil {
		return fmt.Errorf("Task is landed but deferred removal could not start: %w", err)
	}
	return nil
}

func (a *App) requireLandClean(project domain.Project, task domain.Task, continueOp bool) error {
	rootBranch, err := a.Git.Branch(project.GitRoot)
	if err != nil || rootBranch != project.BaseBranch {
		return fmt.Errorf("Root must be on Base branch %s", project.BaseBranch)
	}
	rootClean, err := a.Git.IsClean(project.GitRoot)
	if err != nil || !rootClean {
		return fmt.Errorf("Root must be clean before landing")
	}
	rootOperation, err := a.Git.OperationInProgress(project.GitRoot)
	if err != nil {
		return err
	}
	if rootOperation {
		return fmt.Errorf("Root has an in-progress Git operation")
	}
	if !continueOp {
		taskClean, taskErr := a.Git.IsClean(task.Worktree)
		if taskErr != nil || !taskClean {
			return fmt.Errorf("Task must be clean before landing")
		}
	}
	return nil
}

func (a *App) ownedTask(cwd, selector string) (*domain.Project, *domain.Task, error) {
	project, task, _, err := a.target(cwd, selector)
	if err != nil {
		return nil, nil, err
	}
	if task == nil {
		return nil, nil, fmt.Errorf("operation requires a Task")
	}
	if os.Getenv("CODEX_THREAD_ID") != task.CodexThreadID {
		return nil, nil, fmt.Errorf("only this Task's Codex session may mutate its Git state")
	}
	return project, task, nil
}

func (a *App) target(cwd, selector string) (*domain.Project, *domain.Task, string, error) {
	project, err := a.Store.ResolveProject(cwd)
	if err != nil {
		return nil, nil, "", err
	}
	if selector == "" {
		selector = os.Getenv("CX_TASK_ID")
	}
	if selector == "" || selector == "root" {
		return &project, nil, project.NvimSocket, nil
	}
	tasks, err := a.Store.ListTasks(project.ID)
	if err != nil {
		return nil, nil, "", err
	}
	var matches []domain.Task
	for _, task := range tasks {
		if task.ID == selector || strings.HasPrefix(task.ID, selector) || task.Branch == selector || task.Message == selector {
			matches = append(matches, task)
		}
	}
	if len(matches) != 1 {
		return nil, nil, "", fmt.Errorf("Task selector %q matched %d Tasks", selector, len(matches))
	}
	return &project, &matches[0], matches[0].NvimSocket, nil
}

func (a *App) taskBranchExists(projectID, branch string) bool {
	tasks, _ := a.Store.ListTasks(projectID)
	for _, task := range tasks {
		if task.Branch == branch {
			return true
		}
	}
	return false
}

func (a *App) reportInterveningTasks(project domain.Project, current domain.Task) {
	currentFiles, err := a.Git.Output(current.Worktree, "diff", "--name-only", current.ForkCommit)
	if err != nil {
		return
	}
	changed := make(map[string]bool)
	for _, path := range strings.Split(currentFiles, "\n") {
		if path != "" {
			changed[path] = true
		}
	}
	tasks, _ := a.Store.ListTasks(project.ID)
	archived, _ := a.Store.ListArchivedTasks(project.ID)
	tasks = append(tasks, archived...)
	for _, other := range tasks {
		if other.ID == current.ID || other.LandedCommit == "" || a.Git.IsAncestor(project.GitRoot, other.LandedCommit, current.ForkCommit) {
			continue
		}
		otherFiles, showErr := a.Git.Output(project.GitRoot, "show", "--format=", "--name-only", other.LandedCommit)
		if showErr != nil {
			continue
		}
		var overlap []string
		for _, path := range strings.Split(otherFiles, "\n") {
			if changed[path] {
				overlap = append(overlap, path)
			}
		}
		fmt.Fprintf(a.ErrOut, "Intervening Task: %s (%s)", other.Message, other.LandedCommit)
		if len(overlap) > 0 {
			fmt.Fprintf(a.ErrOut, "; overlapping files: %s", strings.Join(overlap, ", "))
		}
		fmt.Fprintln(a.ErrOut)
	}
}

func attachLoop(socket string) error {
	handoff, err := os.CreateTemp("", "cx-handoff-*")
	if err != nil {
		return err
	}
	path := handoff.Name()
	handoff.Close()
	defer os.Remove(path)
	for socket != "" {
		var adopted bool
		if err := nvim.Call(socket, "adopt", map[string]string{"handoff_file": path}, &adopted); err != nil || !adopted {
			return fmt.Errorf("prepare target Neovim: %w", err)
		}
		if err := os.WriteFile(path, nil, 0o600); err != nil {
			return err
		}
		cmd := exec.Command("nvim", "--server", socket, "--remote-ui")
		cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
		if err := cmd.Run(); err != nil {
			return err
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		socket = strings.TrimSpace(string(data))
	}
	return nil
}

func attached(socket string) bool {
	if socket != "" && socket == os.Getenv("CX_CALLER_NVIM") {
		return true
	}
	var snapshot nvim.Snapshot
	return nvim.Call(socket, "snapshot", nil, &snapshot) == nil && snapshot.UICount > 0
}

func stableID(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:8])
}

func lineContains(lines, wanted string) bool {
	for _, line := range strings.Split(lines, "\n") {
		if strings.TrimSpace(line) == wanted {
			return true
		}
	}
	return false
}

func EncodeJSON(out io.Writer, value any) error {
	encoder := json.NewEncoder(out)
	encoder.SetIndent("", "  ")
	return encoder.Encode(value)
}

func IsNotFound(err error) bool { return errors.Is(err, state.ErrProjectNotFound) }

func WaitForSignal() {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	<-ch
}
