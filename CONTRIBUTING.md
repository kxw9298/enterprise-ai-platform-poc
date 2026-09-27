# Contributing

Use short-lived branches and pull requests with a clear problem statement, changes, and validation. Keep changes small enough to review.

Place code and component-specific documentation together. Update architecture documentation when trust boundaries, dependencies, or deployment behavior change. Record significant choices in `docs/decisions/`.

For infrastructure changes, describe the target environment, expected recurring costs, permissions, validation, and cleanup procedure. Review the IaC plan before applying it. Do not commit plan files, state, secrets, or sensitive data.

Add relevant tests when behavior is implemented. There is no application runtime, build system, or CI pipeline in the initial scaffold.
