# Blocker

- Folder: `memwb`
- Local source: `memwb/memwb.cpp`
- Local original: `memwb/memwb_original.cpp`
- Inferred DUT entry: `memwb::behavior() via memwb.cpp`
- Reason: This `hl5` unit is a SystemC/Stratus-style module and needs the broader processor simulation harness plus real SystemC types to exercise the DUT meaningfully.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
