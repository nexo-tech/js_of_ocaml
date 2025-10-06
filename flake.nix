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
        
        # OCaml packages
        ocamlPackages = pkgs.ocaml-ng.ocamlPackages_5_2;
        
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
              # OCaml toolchain
              ocamlPackages.ocaml
              ocamlPackages.findlib
              ocamlPackages.dune_3
              ocamlPackages.merlin
              ocamlPackages.ocaml-lsp
              ocamlPackages.ocamlformat
              ocamlPackages.utop
              ocamlPackages.odoc
              
              # OCaml libraries
              ocamlPackages.cmdliner
              ocamlPackages.ppxlib
              ocamlPackages.sedlex
              ocamlPackages.menhir
              ocamlPackages.menhirLib
              ocamlPackages.yojson
              ocamlPackages.lwt
              ocamlPackages.num
              ocamlPackages.ppx_expect
              ocamlPackages.qcheck
              ocamlPackages.re
              
              # Primary Lua environment (5.4)
              luaEnvs.lua54
              
              # Build tools
              gnumake
              gcc
              pkg-config
              git
              opam
              
              # JavaScript tools (for existing js_of_ocaml)
              nodejs_20
              nodePackages.npm
              
              # WebAssembly tools
              binaryen
              wabt
              
              # Development utilities
              rlwrap
              tree
              jq
              ripgrep
              fd
              bat
              
              # Benchmarking tools
              hyperfine
              valgrind
            ];

            shellHook = ''
              echo "🌙 Lua_of_ocaml Development Environment"
              echo "======================================="
              echo "OCaml version: $(ocaml -version)"
              echo "Dune version: $(dune --version)"
              echo "Lua version: $(lua -v 2>&1)"
              echo "LuaRocks version: $(luarocks --version | head -1)"
              echo ""
              echo "Available Lua environments:"
              echo "  nix develop .#lua51  - Lua 5.1 environment"
              echo "  nix develop .#lua54  - Lua 5.4 environment (default)"
              echo "  nix develop .#luajit - LuaJIT environment"
              echo ""
              echo "Useful commands:"
              echo "  make              - Build all packages"
              echo "  make tests        - Run tests"
              echo "  dune build        - Build with dune"
              echo "  lua script.lua    - Run Lua script"
              echo "  luarocks install  - Install Lua packages"
              echo ""
              
              # Set up OPAM environment if needed
              if [ ! -d "$HOME/.opam" ]; then
                echo "ℹ️  OPAM not initialized. Run 'opam init' if needed."
              fi
              
              # Create lua_modules directory for local development
              if [ ! -d "lua_modules" ]; then
                mkdir -p lua_modules
                echo "📁 Created lua_modules/ directory for local Lua packages"
              fi
              
              export LUA_PATH="$PWD/lua_modules/?.lua;$PWD/runtime/lua/?.lua;$LUA_PATH"
              export LUA_CPATH="$PWD/lua_modules/?.so;$LUA_CPATH"
            '';

            # Environment variables
            OCAMLRUNPARAM = "b";
            LUA_PATH = "./lua_modules/?.lua;./runtime/lua/?.lua;;";
            LUA_CPATH = "./lua_modules/?.so;;";
          };

          # Lua 5.1 development environment
          lua51 = pkgs.mkShell {
            buildInputs = (with pkgs; [
              ocamlPackages.ocaml
              ocamlPackages.findlib
              ocamlPackages.dune_3
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
              ocamlPackages.ocaml
              ocamlPackages.findlib
              ocamlPackages.dune_3
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