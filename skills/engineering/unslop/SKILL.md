---
name: unslop
description: Remove AI-generated code slop from diffs. Use when reviewing branches with AI-generated code, cleaning up PRs, or when user mentions removing comments, defensive checks, type casts, or making code more consistent.
---

# Unslop

Remove AI-generated code slop introduced in branch diffs.

## Process

1. **Get the diff** - run:
   ```bash
   git diff main...HEAD
   # or for staged:
   git diff --staged
   ```

2. **Scan for slop patterns:**
   - Extra comments that explain the obvious
   - Defensive checks in trusted codepaths
   - `as any` or `@ts-ignore` casts
   - Try/catch blocks where errors can't occur
   - Style that differs from rest of file
   - Comments with "AI", "generated", "NOTE", "IMPORTANT"

3. **Remove slop:**
   - Delete unnecessary comments
   - Remove defensive checks called by validated code
   - Fix types properly instead of casting
   - Match existing file style

4. **Report:**
   - Summarize in 1-3 sentences what was changed
   - Keep tone clinical, not editorializing

## Examples

### Bad: Obvious comment
```typescript
// Increment the counter by 1
counter += 1
```

### Bad: Defensive check in trusted path
```typescript
// Called by validated router
function handleRequest(req: Request) {
  if (!req) {  // Remove this
    throw new Error("No request");
  }
}
```

### Bad: Cast instead of proper typing
```typescript
const data = response.body as any
```

### Good: Strategic comment
```typescript
// Race condition: must check AFTER acquiring lock
if (shouldProceed()) { ... }
```

## Review Checklist

- [ ] Checked against main (not just last commit)
- [ ] Removed obvious/unnecessary comments
- [ ] Removed defensive checks in trusted paths
- [ ] Fixed types instead of casting to any
- [ ] Matched file's existing style
- [ ] Summary is 1-3 sentences
