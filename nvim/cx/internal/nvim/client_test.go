package nvim

import (
	"os"
	"testing"
)

func TestDescendsFromAcceptsProcessItself(t *testing.T) {
	ok, err := descendsFrom(os.Getpid(), os.Getpid())
	if err != nil || !ok {
		t.Fatalf("descendsFrom(self, self) = %v, %v", ok, err)
	}
}
