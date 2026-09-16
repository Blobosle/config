package main

import "testing"

func TestParseRebaseArgsAcceptsFlagsAfterTask(t *testing.T) {
	selector, continuing, err := parseRebaseArgs([]string{"feat/auth", "--continue"})
	if err != nil || selector != "feat/auth" || !continuing {
		t.Fatalf("parseRebaseArgs() = %q, %v, %v", selector, continuing, err)
	}
}

func TestParseLandArgsAcceptsInterspersedFlags(t *testing.T) {
	selector, message, continuing, remove, err := parseLandArgs([]string{
		"task-id", "--remove", "-m", "feat: final", "--continue",
	})
	if err != nil || selector != "task-id" || message != "feat: final" || !continuing || !remove {
		t.Fatalf("parseLandArgs() = %q, %q, %v, %v, %v", selector, message, continuing, remove, err)
	}
}
