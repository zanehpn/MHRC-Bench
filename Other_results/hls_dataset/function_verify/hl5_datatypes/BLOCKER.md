# Blocker

- Folder: `hl5_datatypes`
- Local source: `hl5_datatypes/hl5_datatypes.hpp`
- Local original: `hl5_datatypes/hl5_datatypes_original.hpp`
- Inferred DUT entry: `operator== / datatype methods in hl5_datatypes.hpp`
- Reason: This candidate is a SystemC-heavy datatype header rather than a standalone callable DUT; validating it needs the surrounding `hl5` simulation environment.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
