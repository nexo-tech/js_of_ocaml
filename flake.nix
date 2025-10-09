{
  description = "Development environment for lua_of_ocaml";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Lua versions for testing compatibility
        luaEnvs = {
          lua51 = pkgs.lua5_1.withPackages (ps: with ps; [
            luarocks
            busted
            luacheck
            lpeg
            luafilesystem
          ]);

          lua54 = pkgs.lua5_4.withPackages (ps: with ps; [
            luarocks
            busted
            luacheck
            lpeg
            luafilesystem
          ]);

          luajit = pkgs.luajit.withPackages (ps: with ps; [
            luarocks
            busted
            luacheck
            lpeg
            luafilesystem
          ]);
        };

      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              # Native libraries for OCaml packages
              gmp              # for num library
              libiconv         # for sedlex/Unicode

              # Lua runtime for lua_of_ocaml
              lua5_4

              # Build tools
              gnumake
              pkg-config
              git

              # Testing tools
              nodejs_20

              # Documentation
              graphviz

              # Development utilities
              rlwrap
              tree
              jq
              ripgrep
              fd
              bat

              # Benchmarking tools
              hyperfine
            ];

            shellHook = ''
              echo "js_of_ocaml & lua_of_ocaml native dependencies"
              echo "=============================================="
              echo ""
              echo "Native libraries available:"
              echo "  GMP, libiconv, CoreFoundation (macOS)"
              echo "  Node.js: $(node --version)"
              echo "  Lua: $(lua -v 2>&1)"
              echo ""
              echo "OCaml/OPAM managed externally - make sure to activate your switch:"
              echo "  eval \$(opam env --switch=lua_of_ocaml_52)"
              echo ""
              echo "Build commands:"
              echo "  make          - Build all packages"
              echo "  make tests    - Run JavaScript tests"
              echo "  make tests-wasm - Run WebAssembly tests"
              echo "  make fmt      - Format code"
              echo ""
              echo "Available Lua test environments:"
              echo "  nix develop .#lua51  - Lua 5.1"
              echo "  nix develop .#lua54  - Lua 5.4 (default)"
              echo "  nix develop .#luajit - LuaJIT"
              echo ""

              # Create lua_modules directory for local development
              if [ ! -d "lua_modules" ]; then
                mkdir -p lua_modules
              fi

              export LUA_PATH="$PWD/lua_modules/?.lua;$PWD/runtime/lua/?.lua;$LUA_PATH"
              export LUA_CPATH="$PWD/lua_modules/?.so;$LUA_CPATH"
            '';

            # Lua environment variables
            LUA_PATH = "./lua_modules/?.lua;./runtime/lua/?.lua;;";
            LUA_CPATH = "./lua_modules/?.so;;";
          };

          # Lua 5.1 development environment
          lua51 = pkgs.mkShell {
            buildInputs = (with pkgs; [
              gnumake
              gcc
            ]) ++ [ luaEnvs.lua51 ];

            shellHook = ''
              echo "🌙 Lua 5.1 Development Environment"
              echo "================================="
              lua -v
              echo ""
              export LUA_PATH="$PWD/lua_modules/?.lua;$PWD/runtime/lua/?.lua;$LUA_PATH"
              export LUA_CPATH="$PWD/lua_modules/?.so;$LUA_CPATH"
            '';
          };

          # Lua 5.4 development environment (same as default)
          lua54 = self.devShells.${system}.default;

          # LuaJIT development environment
          luajit = pkgs.mkShell {
            buildInputs = (with pkgs; [
              gnumake
              gcc
            ]) ++ [ luaEnvs.luajit ];

            shellHook = ''
              echo "⚡ LuaJIT Development Environment"
              echo "================================"
              luajit -v
              echo ""
              export LUA_PATH="$PWD/lua_modules/?.lua;$PWD/runtime/lua/?.lua;$LUA_PATH"
              export LUA_CPATH="$PWD/lua_modules/?.so;$LUA_CPATH"
            '';
          };
        };

        # Provide a test runner app
        apps.test-lua-versions = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "test-lua-versions" ''
            #!/usr/bin/env bash
            set -e

            echo "Testing Lua compilation across versions..."
            echo "=========================================="

            if [ ! -f "$1" ]; then
              echo "Usage: nix run .#test-lua-versions <lua-file>"
              exit 1
            fi

            echo -e "\n📌 Testing with Lua 5.1:"
            ${luaEnvs.lua51}/bin/lua "$1"

            echo -e "\n📌 Testing with Lua 5.4:"
            ${luaEnvs.lua54}/bin/lua "$1"

            echo -e "\n📌 Testing with LuaJIT:"
            ${luaEnvs.luajit}/bin/luajit "$1"

            echo -e "\n✅ All Lua versions executed successfully!"
          '';
        };

        # Development tools package set
        packages = {
          lua-test-runner = pkgs.writeShellScriptBin "lua-test-runner" ''
            #!/usr/bin/env bash
            # Run Lua tests with proper environment
            export LUA_PATH="$PWD/lua_modules/?.lua;$PWD/runtime/lua/?.lua;;"
            export LUA_CPATH="$PWD/lua_modules/?.so;;"

            if [ "$1" = "--all" ]; then
              echo "Running tests on all Lua versions..."
              for lua in ${luaEnvs.lua51}/bin/lua ${luaEnvs.lua54}/bin/lua ${luaEnvs.luajit}/bin/luajit; do
                echo "Testing with $($lua -v 2>&1)..."
                $lua tests/test_runner.lua
              done
            else
              lua tests/test_runner.lua "$@"
            fi
          '';

          luarocks-sync = pkgs.writeShellScriptBin "luarocks-sync" ''
            #!/usr/bin/env bash
            # Install dependencies from rockspec
            if [ -f "lua_of_ocaml-dev-1.rockspec" ]; then
              luarocks install --deps-only lua_of_ocaml-dev-1.rockspec
            else
              echo "No rockspec file found"
            fi
          '';
        };
      });
}