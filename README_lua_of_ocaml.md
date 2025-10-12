
### OPAM Switch Setup

Create an OPAM switch for lua_of_ocaml_52 development:

```bash
# Create switch with OCaml 5.2.0
opam switch create lua_of_ocaml_52 5.2.0

# Install dependencies
eval $(opam env --switch=lua_of_ocaml_52)
opam pin add . --no-action --yes
opam install . --deps-only --yes

# Activate switch
opam switch lua_of_ocaml_52
eval $(opam env)
```

Verify setup:
```bash
dune --version  # Should be >= 3.17
ocaml --version  # Should be 5.2.0
```

### Lua Installation (for lua_of_ocaml testing)

**CRITICAL**: Lua_of_ocaml targets **Lua 5.1 and LuaJIT** for maximum compatibility.

Install Lua 5.1 using Nix package manager:

```bash
# Install Nix (if not already installed)
# See: https://nixos.org/download.html

# Install Lua 5.1 (NOT 5.2, 5.3, or 5.4)
nix-env -iA nixpkgs.lua5_1

# Verify installation
lua -v  # Should show: Lua 5.1.x
```

