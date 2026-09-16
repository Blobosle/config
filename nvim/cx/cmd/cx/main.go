package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/benjaminlobos/cx/internal/app"
)

const usage = `cx coordinates Codex Tasks backed by Git worktrees and Neovim.

Usage:
  cx init
  cx task -m <message>
  cx list [--global] [--json]
  cx attach <root-or-task>
  cx send <task> <message>
  cx diff <task>
  cx rebase [task] [--continue]
  cx land [task] [--continue] [-m <message>] [--remove]
  cx remove <task>
`

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "cx:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		fmt.Print(usage)
		return nil
	}
	application, err := app.New()
	if err != nil {
		return err
	}
	cwd, err := os.Getwd()
	if err != nil {
		return err
	}

	switch args[0] {
	case "init":
		if len(args) != 1 {
			return fmt.Errorf("usage: cx init")
		}
		return application.Init(cwd)
	case "task":
		flags := newFlags("task")
		message := flags.String("m", "", "Task message and eventual commit message")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		if *message == "" || flags.NArg() != 0 {
			return fmt.Errorf("usage: cx task -m <message>")
		}
		task, err := application.Task(cwd, *message)
		if err == nil {
			fmt.Printf("Created Task %s on %s\n", task.Message, task.Branch)
		}
		return err
	case "list":
		flags := newFlags("list")
		global := flags.Bool("global", false, "list every Project")
		jsonOutput := flags.Bool("json", false, "emit JSON")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		if flags.NArg() != 0 {
			return fmt.Errorf("usage: cx list [--global] [--json]")
		}
		items, err := application.List(cwd, *global)
		if err != nil {
			return err
		}
		if *jsonOutput {
			return app.EncodeJSON(os.Stdout, items)
		}
		for _, item := range items {
			attached := "detached"
			if item.Attached {
				attached = "attached"
			}
			fmt.Printf("%-5s %-24s %-28s %s %s\n", item.Kind, item.Message, item.Branch, item.Status, attached)
		}
		return nil
	case "attach":
		if len(args) != 2 {
			return fmt.Errorf("usage: cx attach <root-or-task>")
		}
		return application.Attach(cwd, args[1])
	case "send":
		if len(args) < 3 {
			return fmt.Errorf("usage: cx send <task> <message>")
		}
		return application.Send(cwd, args[1], strings.Join(args[2:], " "))
	case "diff":
		if len(args) != 2 {
			return fmt.Errorf("usage: cx diff <task>")
		}
		text, err := application.Diff(cwd, args[1])
		if err == nil {
			fmt.Print(text)
			if text != "" && !strings.HasSuffix(text, "\n") {
				fmt.Println()
			}
		}
		return err
	case "rebase":
		selector, continueOp, err := parseRebaseArgs(args[1:])
		if err != nil {
			return err
		}
		return application.Rebase(cwd, selector, continueOp)
	case "land":
		selector, message, continueOp, remove, err := parseLandArgs(args[1:])
		if err != nil {
			return err
		}
		return application.Land(cwd, selector, message, continueOp, remove)
	case "remove":
		if len(args) != 2 {
			return fmt.Errorf("usage: cx remove <task>")
		}
		if os.Getenv("CX_DEFER_REMOVE") == "1" {
			time.Sleep(500 * time.Millisecond)
		}
		return application.Remove(cwd, args[1])
	case "fork":
		return fmt.Errorf("there is no cx fork command; Root Codex creates a Task with cx task -m <message>")
	default:
		return fmt.Errorf("unknown command %q\n\n%s", args[0], usage)
	}
}

func newFlags(name string) *flag.FlagSet {
	flags := flag.NewFlagSet(name, flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	return flags
}

func parseRebaseArgs(args []string) (selector string, continueOp bool, err error) {
	for _, arg := range args {
		switch arg {
		case "--continue":
			continueOp = true
		default:
			if strings.HasPrefix(arg, "-") || selector != "" {
				return "", false, fmt.Errorf("usage: cx rebase [task] [--continue]")
			}
			selector = arg
		}
	}
	return selector, continueOp, nil
}

func parseLandArgs(args []string) (selector, message string, continueOp, remove bool, err error) {
	for index := 0; index < len(args); index++ {
		arg := args[index]
		switch {
		case arg == "--continue":
			continueOp = true
		case arg == "--remove":
			remove = true
		case arg == "-m" || arg == "--message":
			index++
			if index >= len(args) {
				return "", "", false, false, fmt.Errorf("-m requires a commit message")
			}
			message = args[index]
		case strings.HasPrefix(arg, "-m="):
			message = strings.TrimPrefix(arg, "-m=")
		case strings.HasPrefix(arg, "--message="):
			message = strings.TrimPrefix(arg, "--message=")
		default:
			if strings.HasPrefix(arg, "-") || selector != "" {
				return "", "", false, false, fmt.Errorf("usage: cx land [task] [--continue] [-m <message>] [--remove]")
			}
			selector = arg
		}
	}
	return selector, message, continueOp, remove, nil
}
