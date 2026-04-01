# Blocker

- Folder: `cnn`
- Local source: `cnn/cnn.cc`
- Local original: `cnn/cnn_original.cc`
- Inferred DUT entry: `cnn(...)`
- Reason: The top-level CNN integrates multiple sibling kernels and several mutated headers, so standing up a credible isolated DUT harness would require reconstructing most of the project build context.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
