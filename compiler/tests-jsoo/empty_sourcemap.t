  $ echo 'prerr_endline "a"' > a.ml
  $ echo 'prerr_endline "b"' > b.ml
  $ ocamlc -g a.ml -c
  $ ocamlc -g b.ml -c
  $ ocamlc -g a.cmo b.cmo -o test.bc

Build object files and executable with --empty-sourcemap:

  $ dune exec -- js_of_ocaml --sourcemap --empty-sourcemap a.cmo -o a.js
  Error: Program 'js_of_ocaml' not found!
  [1]
  $ cat a.map
  cat: a.map: No such file or directory
  [1]
  $ dune exec -- js_of_ocaml --sourcemap --empty-sourcemap b.cmo -o b.js
  Error: Program 'js_of_ocaml' not found!
  [1]
  $ cat b.map
  cat: b.map: No such file or directory
  [1]
  $ dune exec -- js_of_ocaml --sourcemap --empty-sourcemap test.bc -o test.js
  Error: Program 'js_of_ocaml' not found!
  [1]
  $ cat test.map
  cat: test.map: No such file or directory
  [1]

Build object files with sourcemap and link with --empty-sourcemap:

  $ dune exec -- js_of_ocaml --sourcemap a.cmo -o a.js
  Error: Program 'js_of_ocaml' not found!
  [1]
  $ dune exec -- js_of_ocaml --sourcemap b.cmo -o b.js
  Error: Program 'js_of_ocaml' not found!
  [1]
  $ dune exec -- js_of_ocaml link --sourcemap --resolve-sourcemap-url=true --empty-sourcemap a.js b.js -o test.js -a
  Error: Program 'js_of_ocaml' not found!
  [1]
  $ cat test.map
  cat: test.map: No such file or directory
  [1]
