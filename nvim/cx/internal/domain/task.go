package domain

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strings"
	"unicode"
)

var safePrefix = regexp.MustCompile(`^[a-z0-9][a-z0-9()._-]*$`)

func BranchFromMessage(message string) (string, error) {
	message = strings.TrimSpace(message)
	if message == "" {
		return "", fmt.Errorf("task message cannot be empty")
	}

	prefix := ""
	description := message
	if before, after, ok := strings.Cut(message, ":"); ok {
		prefix = strings.ToLower(strings.TrimSpace(before))
		description = strings.TrimSpace(after)
		if prefix == "" || !safePrefix.MatchString(prefix) || strings.Contains(prefix, "..") {
			return "", fmt.Errorf("unsafe task prefix %q", before)
		}
	}

	slug := slugify(description)
	if slug == "" {
		return "", fmt.Errorf("task message must contain a branch-safe description")
	}
	if prefix == "" {
		return slug, nil
	}
	return prefix + "/" + slug, nil
}

func slugify(value string) string {
	var out strings.Builder
	dash := false
	for _, r := range strings.ToLower(value) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			if dash && out.Len() > 0 {
				out.WriteByte('-')
			}
			out.WriteRune(r)
			dash = false
		} else {
			dash = true
		}
	}
	return strings.Trim(out.String(), "-")
}

func DisambiguateBranch(branch, scopeRoot string, exists func(string) bool) (string, error) {
	if !exists(branch) {
		return branch, nil
	}
	suffix := slugify(filepath.Base(filepath.Clean(scopeRoot)))
	if suffix == "" {
		return "", fmt.Errorf("branch %q already exists and scope has no usable suffix", branch)
	}
	dir, base := filepath.Split(branch)
	candidate := filepath.ToSlash(filepath.Join(dir, base+"-"+suffix))
	if exists(candidate) {
		return "", fmt.Errorf("branch %q and fallback %q already exist", branch, candidate)
	}
	return candidate, nil
}
