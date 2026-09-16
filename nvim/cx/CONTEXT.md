# Codex worktree management

This context defines the projects and tasks managed by `cx`.

## Language

**Project**:
A directory tree registered with `cx`. The nearest registered ancestor owns a directory and its descendants.

**Scope root**:
The directory where a Project begins. A nested Project has its own Scope root and takes ownership of its subtree.
_Avoid_: Project directory, workspace root

**Git root**:
The top-level directory of the Git repository that contains a Project. Several nested Projects may share one Git root.
_Avoid_: Scope root, project root

**Task**:
An isolated unit of work owned by a Project. A Task has a Git worktree, branch, persistent editor session, and Codex session.
_Avoid_: Workspace, Managed worktree, feature session

**Task message**:
The exact text passed to `cx task -m`. It names the Task and becomes its final commit message, but it is not sent to Codex as an instruction.
_Avoid_: Prompt, label, Task name

**Git worktree**:
The checked-out directory created and tracked by Git for a Task.
_Avoid_: Task, workspace

**Root**:
The original checkout, persistent editor session, and Codex context associated with a Project. The Root is not a Task.
_Avoid_: Root Task, main workspace

**Base branch**:
The Root branch recorded when a Project is initialized. New Tasks begin from this branch until the Project is initialized again.
_Avoid_: Current branch, default branch

**Landing**:
The operation that turns a Task's committed tree into one commit on the current Base branch. Landing preserves the Task until the user removes it.
_Avoid_: Merge, cleanup
