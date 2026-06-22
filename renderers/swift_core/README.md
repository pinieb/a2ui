# A2UI Swift Core

The `A2UISwiftCore` library contains shared Swift core logic, models, and utility targets
used to build A2UI renderers and integrations in Swift-based environments (such as iOS, macOS,
and other Swift client applications).

To keep the codebase modular and reusable, functionality is divided into independent,
focused targets.

---

## Target Architecture

The library is organized into multiple Swift targets under the root directory. Each target
represents a distinct module with its own target subdirectory containing `Sources` and `Tests`.

### Current Targets

- **[JSONSchema](JSONSchema/README.md)**: A generic JSON Schema Draft 2020-12
  validator and DSL builder. This target is completely independent of A2UI-specific concepts
  or protocols.

### Adding New Targets

To add new targets to the library (e.g., A2UI-specific parser or renderer core):

1. Create a new directory under the root: `<TargetName>`.
2. Under the new target directory, create `Sources` and optionally `Tests` directories.
3. Add a `README.md` at the target's root directory detailing its purpose and usage.
4. Update `Package.swift` at the repository root to register the target and its paths.
5. Add a list item under **Current Targets** above linking to your new target's README.

---

## Development

### Setup and Testing

To run the unit test suites for all targets:

```bash
cd renderers/swift_core
./run_tests.sh
```

### Coding Standards

All development under this directory must follow the
[Coding Standards Guide](CODING_STANDARDS.md) and conform to target boundaries as defined in
[AGENTS.md](AGENTS.md).
