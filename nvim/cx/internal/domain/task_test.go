package domain

import "testing"

func TestBranchFromMessage(t *testing.T) {
	t.Parallel()

	tests := map[string]string{
		"feat: add login":            "feat/add-login",
		"feat(auth): rotate tokens":  "feat(auth)/rotate-tokens",
		"docs: update setup":         "docs/update-setup",
		"new parser":                 "new-parser",
		"fix: HTTP 500 on /v1/users": "fix/http-500-on-v1-users",
	}
	for message, want := range tests {
		message, want := message, want
		t.Run(message, func(t *testing.T) {
			t.Parallel()
			got, err := BranchFromMessage(message)
			if err != nil {
				t.Fatalf("BranchFromMessage() error = %v", err)
			}
			if got != want {
				t.Fatalf("BranchFromMessage() = %q, want %q", got, want)
			}
		})
	}
}

func TestBranchFromMessageRejectsUnsafeOrEmptyMessages(t *testing.T) {
	t.Parallel()

	for _, message := range []string{"", "   ", ": empty", "../oops: no", "feat/: nope"} {
		if got, err := BranchFromMessage(message); err == nil {
			t.Errorf("BranchFromMessage(%q) = %q, want error", message, got)
		}
	}
}

func TestDisambiguateBranchOnlyUsesScopeSuffixOnCollision(t *testing.T) {
	t.Parallel()

	exists := func(name string) bool { return name == "feat/add-login" }
	got, err := DisambiguateBranch("feat/add-login", "/src/api", exists)
	if err != nil {
		t.Fatal(err)
	}
	if got != "feat/add-login-api" {
		t.Fatalf("DisambiguateBranch() = %q", got)
	}

	got, err = DisambiguateBranch("fix/cache", "/src/api", exists)
	if err != nil || got != "fix/cache" {
		t.Fatalf("non-conflicting branch = %q, %v", got, err)
	}
}

func TestDisambiguateBranchFailsWhenFallbackAlsoExists(t *testing.T) {
	t.Parallel()

	_, err := DisambiguateBranch("feat/add-login", "/src/api", func(string) bool { return true })
	if err == nil {
		t.Fatal("expected collision error")
	}
}
