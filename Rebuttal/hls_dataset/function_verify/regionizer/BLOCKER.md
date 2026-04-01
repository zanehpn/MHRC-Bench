# Blocker

- Folder: `regionizer`
- Local source: `regionizer/regionizer.cpp`
- Local original: `regionizer/regionizer_original.cpp`
- Inferred DUT entry: `regionize_* and merge helpers in regionizer.cpp`
- Reason: The firmware regionizer depends on GlobalCorrelator type definitions and multi-header HLS object plumbing that are not practical to reconstruct locally here.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
