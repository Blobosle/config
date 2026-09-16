package state

import (
	"path/filepath"
	"testing"

	"github.com/benjaminlobos/cx/internal/domain"
)

func TestResolveProjectUsesNearestRegisteredAncestor(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	store := New(filepath.Join(t.TempDir(), "state"))
	outer := domain.Project{ID: "outer", ScopeRoot: root}
	inner := domain.Project{ID: "inner", ScopeRoot: filepath.Join(root, "services", "api")}
	if err := store.CreateProject(outer); err != nil {
		t.Fatal(err)
	}
	if err := store.CreateProject(inner); err != nil {
		t.Fatal(err)
	}

	got, err := store.ResolveProject(filepath.Join(root, "services", "api", "internal"))
	if err != nil {
		t.Fatal(err)
	}
	if got.ID != "inner" {
		t.Fatalf("ResolveProject() = %q, want inner", got.ID)
	}

	got, err = store.ResolveProject(filepath.Join(root, "web"))
	if err != nil {
		t.Fatal(err)
	}
	if got.ID != "outer" {
		t.Fatalf("ResolveProject() = %q, want outer", got.ID)
	}
}

func TestCreateProjectRejectsDuplicateScope(t *testing.T) {
	t.Parallel()

	store := New(t.TempDir())
	project := domain.Project{ID: "one", ScopeRoot: t.TempDir()}
	if err := store.CreateProject(project); err != nil {
		t.Fatal(err)
	}
	project.ID = "two"
	if err := store.CreateProject(project); err == nil {
		t.Fatal("expected duplicate scope error")
	}
}
