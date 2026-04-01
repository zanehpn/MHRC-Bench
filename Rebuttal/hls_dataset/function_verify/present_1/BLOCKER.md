# Blocker

- Folder: `present_1`
- Local source: `present_1/present.cpp`
- Local original: `present_1/present_original.cpp`
- Inferred DUT entry: `present_encrypt(...) and round helpers`
- Reason: Masked PRESENT uses bit-sliced arbitrary-width crypto datatypes and helper headers where lightweight integer aliases would not exercise the real logic correctly.

A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
