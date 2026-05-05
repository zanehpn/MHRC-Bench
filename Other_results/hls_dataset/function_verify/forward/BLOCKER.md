# Blocker

- Folder: `forward`
- Local source: `forward/forward.cpp`
- Local original: `forward/forward_original.cpp`
- Inferred DUT entry: `forward(...) plus helper templates in forward.cpp`
- Reason: The forward kernel depends on multiple damaged model/config headers and large transformer state definitions, so an isolated local bench would be more reconstruction than validation.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
