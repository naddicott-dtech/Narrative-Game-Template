# inkgd runtime

This folder contains the pure-GDScript runtime portion of
[ephread/inkgd](https://github.com/ephread/inkgd), pinned from its `godot4`
branch at commit:

`fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a`

The editor plugin, compiler integration, examples, upstream test tools, and C#
bridge are deliberately not included. Students write and test `.ink` files in
Inky, then export compiled JSON for this Godot project to play.

The runtime is MIT licensed. See [LICENSE](LICENSE) in this folder. Keep the
commit above and any local compatibility patches documented when updating it.

## Local compatibility patches

- `runtime/extra/ink_utils.gd`: use `get_node_or_null("__InkRuntime")` when
  checking whether the runtime singleton already exists. Upstream's
  `get_node()` logs an error during normal first initialization; Godot 4.5 and
  GdUnit4 correctly surface that false-positive as a runtime failure.
