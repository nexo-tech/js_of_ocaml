(* Lua_of_ocaml compiler
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

let version = Js_of_ocaml_compiler.Compiler_version.s

let make ~name ~doc ~description:_ =
  let man =
    [ `S Cmdliner.Manpage.s_bugs
    ; `P "Report bugs to https://github.com/ocsigen/js_of_ocaml/issues"
    ; `S Cmdliner.Manpage.s_see_also
    ; `P "lua_of_ocaml(1)"
    ]
  in
  Cmdliner.Cmd.info name ~version ~doc ~man ~docs:"DESCRIPTION" ~sdocs:"OPTIONS"
