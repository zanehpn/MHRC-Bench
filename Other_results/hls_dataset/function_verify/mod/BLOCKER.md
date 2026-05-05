# Blocker

- Folder: `mod`
- Local source: `mod/mod.cpp`
- Local original: `mod/mod_original.cpp`
- Inferred DUT entry: `reduction(...) / modular_multiplication(...) helpers in mod.cpp`
- Reason: The target logic is bit-window modular reduction over ap_int/ap_uint values; validating it in isolation needs real arbitrary-width integer semantics, not the lightweight local support used for stream-only designs.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
