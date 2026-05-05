# Blocker

- Folder: `forward-unrolling`
- Local source: `forward-unrolling/forward-unrolling.cpp`
- Local original: `forward-unrolling/forward-unrolling_original.cpp`
- Inferred DUT entry: `forward(...) plus helper templates in forward-unrolling.cpp`
- Reason: The BitNet forward path relies on multiple mutated config/typedef headers and large templated model structures, so isolating a trustworthy DUT harness here would require reconstructing substantial project context.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
