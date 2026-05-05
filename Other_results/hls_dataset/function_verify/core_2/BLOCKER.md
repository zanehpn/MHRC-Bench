# Blocker

- Folder: `core_2`
- Local source: `core_2/core.cpp`
- Local original: `core_2/core_original.cpp`
- Inferred DUT entry: `anisotropic_diffusion(...)`
- Reason: This anisotropic-diffusion kernel depends on project-specific image container types and Vivado-HLS/OpenCV support code outside the candidate folder.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
