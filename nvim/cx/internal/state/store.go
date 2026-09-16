package state

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/benjaminlobos/cx/internal/domain"
)

var ErrProjectNotFound = errors.New("no cx project owns this directory")

type Store struct{ Root string }

func New(root string) *Store { return &Store{Root: root} }

func (s *Store) CreateProject(project domain.Project) error {
	projects, err := s.ListProjects()
	if err != nil {
		return err
	}
	cleanScope, err := filepath.Abs(project.ScopeRoot)
	if err != nil {
		return err
	}
	project.ScopeRoot = filepath.Clean(cleanScope)
	for _, existing := range projects {
		if samePath(existing.ScopeRoot, project.ScopeRoot) {
			return fmt.Errorf("a project already exists at %s", project.ScopeRoot)
		}
	}
	return writeJSONAtomic(s.projectPath(project.ID), project)
}

func (s *Store) SaveProject(project domain.Project) error {
	if _, err := os.Stat(s.projectPath(project.ID)); err != nil {
		return fmt.Errorf("save project: %w", err)
	}
	return writeJSONAtomic(s.projectPath(project.ID), project)
}

func (s *Store) Project(id string) (domain.Project, error) {
	var project domain.Project
	err := readJSON(s.projectPath(id), &project)
	return project, err
}

func (s *Store) ResolveProject(path string) (domain.Project, error) {
	abs, err := filepath.Abs(path)
	if err != nil {
		return domain.Project{}, err
	}
	projects, err := s.ListProjects()
	if err != nil {
		return domain.Project{}, err
	}
	var matches []domain.Project
	for _, project := range projects {
		if contains(project.ScopeRoot, abs) {
			matches = append(matches, project)
			continue
		}
		for _, task := range s.tasksIgnoringErrors(project.ID) {
			if contains(task.ScopeRoot, abs) || contains(task.Worktree, abs) {
				matches = append(matches, project)
				break
			}
		}
	}
	if len(matches) == 0 {
		return domain.Project{}, ErrProjectNotFound
	}
	sort.Slice(matches, func(i, j int) bool { return len(matches[i].ScopeRoot) > len(matches[j].ScopeRoot) })
	return matches[0], nil
}

func (s *Store) ListProjects() ([]domain.Project, error) {
	paths, err := filepath.Glob(filepath.Join(s.Root, "projects", "*", "project.json"))
	if err != nil {
		return nil, err
	}
	projects := make([]domain.Project, 0, len(paths))
	for _, path := range paths {
		var project domain.Project
		if err := readJSON(path, &project); err != nil {
			return nil, fmt.Errorf("read %s: %w", path, err)
		}
		projects = append(projects, project)
	}
	sort.Slice(projects, func(i, j int) bool { return projects[i].ScopeRoot < projects[j].ScopeRoot })
	return projects, nil
}

func (s *Store) SaveTask(task domain.Task) error {
	return writeJSONAtomic(s.taskPath(task.ProjectID, task.ID), task)
}

func (s *Store) Task(projectID, taskID string) (domain.Task, error) {
	var task domain.Task
	err := readJSON(s.taskPath(projectID, taskID), &task)
	return task, err
}

func (s *Store) ListTasks(projectID string) ([]domain.Task, error) {
	return s.listTasksAt(filepath.Join(s.Root, "projects", projectID, "tasks", "*.json"))
}

func (s *Store) ListArchivedTasks(projectID string) ([]domain.Task, error) {
	return s.listTasksAt(filepath.Join(s.Root, "projects", projectID, "archive", "*.json"))
}

func (s *Store) listTasksAt(pattern string) ([]domain.Task, error) {
	paths, err := filepath.Glob(pattern)
	if err != nil {
		return nil, err
	}
	tasks := make([]domain.Task, 0, len(paths))
	for _, path := range paths {
		var task domain.Task
		if err := readJSON(path, &task); err != nil {
			return nil, err
		}
		tasks = append(tasks, task)
	}
	sort.Slice(tasks, func(i, j int) bool { return tasks[i].CreatedAt.Before(tasks[j].CreatedAt) })
	return tasks, nil
}

func (s *Store) RemoveTask(projectID, taskID string) error {
	return os.Remove(s.taskPath(projectID, taskID))
}

func (s *Store) RemoveProject(projectID string) error {
	return os.RemoveAll(s.ProjectDir(projectID))
}

func (s *Store) ArchiveTask(task domain.Task) error {
	if err := writeJSONAtomic(filepath.Join(s.Root, "projects", task.ProjectID, "archive", task.ID+".json"), task); err != nil {
		return err
	}
	return s.RemoveTask(task.ProjectID, task.ID)
}

func (s *Store) ProjectDir(id string) string { return filepath.Join(s.Root, "projects", id) }

func (s *Store) projectPath(id string) string { return filepath.Join(s.ProjectDir(id), "project.json") }
func (s *Store) taskPath(projectID, taskID string) string {
	return filepath.Join(s.ProjectDir(projectID), "tasks", taskID+".json")
}

func (s *Store) tasksIgnoringErrors(projectID string) []domain.Task {
	tasks, _ := s.ListTasks(projectID)
	return tasks
}

func contains(root, path string) bool {
	rel, err := filepath.Rel(filepath.Clean(root), filepath.Clean(path))
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

func samePath(a, b string) bool { return filepath.Clean(a) == filepath.Clean(b) }

func readJSON(path string, value any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(data, value); err != nil {
		return fmt.Errorf("decode %s: %w", path, err)
	}
	return nil
}

func writeJSONAtomic(path string, value any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if err := tmp.Chmod(0o600); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(append(data, '\n')); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}
