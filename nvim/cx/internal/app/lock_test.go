package app

import "testing"

func TestProjectLockRejectsConcurrentMutation(t *testing.T) {
	dir := t.TempDir()
	first, err := lockProject(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()

	second, err := lockProject(dir)
	if err == nil {
		second.Close()
		t.Fatal("expected concurrent lock attempt to fail")
	}
}
