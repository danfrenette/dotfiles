# Domain Context

## Glossary

### Baseline technology

The software and tooling a machine must have before personal configuration can
be refreshed. Setup establishes this state; Refresh assumes it already exists.

### Setup workflow

The new-machine workflow. It establishes baseline technology in dependency
order, then installs the personal configuration that depends on it.

Setup stops at the first phase that fails, reports the error, and returns a
failure status. A successful Setup means the complete promised machine state
was established.

### Refresh workflow

The routine workflow for updating dotfiles and skills on an already set-up
machine. It does not repair missing baseline technology; it fails with a clear
instruction to run Setup.
