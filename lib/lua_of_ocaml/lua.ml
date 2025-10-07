(* Lua_of_ocaml library
 * FFI bindings for OCaml-Lua interop
 * Copyright (C) 2025
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

(** Lua FFI bindings for OCaml-Lua interop - Implementation *)

type +'a t

type any = < > t

type nil

type bool_t = bool

type number = float

type integer = int

type string_t = string

type 'a table

type (-'a, +'b) fn

type userdata

type thread

type lua_type =
  | Nil
  | Boolean
  | Number
  | String
  | Table
  | Function
  | Userdata
  | Thread

module Unsafe = struct
  external inject : 'a -> any = "%identity"

  external coerce : _ t -> _ t = "%identity"

  external get : 'a table t -> 'b -> 'c = "caml_lua_get"

  external set : 'a table t -> 'b -> 'c -> unit = "caml_lua_set"

  external call : ('a, 'b) fn t -> any array -> 'b = "caml_lua_call"

  external table : (string * any) array -> 'a table t = "caml_lua_table"

  external equals : 'a -> 'b -> bool = "caml_lua_equals"

  external get_global : string -> 'a = "caml_lua_get_global"

  external set_global : string -> 'a -> unit = "caml_lua_set_global"

  external eval : string -> 'a = "caml_lua_eval"

  external callback : ('a -> 'b) -> ('a, 'b) fn t = "caml_lua_wrap_callback"

  let global = table [||]
end

external typeof : 'a t -> lua_type = "caml_lua_type"

let to_any x = Unsafe.coerce x

let nil : nil t = Obj.magic 0

let is_nil x =
  let t = typeof x in
  match t with
  | Nil -> true
  | _ -> false

let bool b : bool_t t = Obj.magic b

let to_bool x = Obj.magic x

let number f : number t = Obj.magic f

let to_number x = Obj.magic x

let integer i : integer t = Obj.magic i

let to_integer x = Obj.magic x

let string s : string_t t = Obj.magic s

let to_string x = Obj.magic x

let table () : 'a table t = Unsafe.table [||]

let get tbl key : 'c t = Unsafe.get tbl (Unsafe.inject key)

let set tbl key value = Unsafe.set tbl (Unsafe.inject key) (Unsafe.inject value)

let array arr : 'a table t =
  let pairs = Array.mapi (fun i v -> (string_of_int (i + 1), Unsafe.inject v)) arr in
  Unsafe.table pairs

let to_array (tbl : 'a table t) : 'a t array =
  (* Lua arrays are 1-indexed, extract all numeric indices *)
  let rec gather acc i =
    let key = Obj.magic (string_of_int i) in
    try
      let v : 'a t = Unsafe.get tbl key in
      if is_nil (Obj.magic v) then acc else gather (v :: acc) (i + 1)
    with
    | _ -> acc
  in
  List.rev (gather [] 1) |> Array.of_list

let callback (f : 'a t -> 'b t) : ('a, 'b) fn t =
  let wrapped x = f (Obj.magic x) in
  Obj.magic (Unsafe.callback wrapped)

let call (fn : ('a, 'b) fn t) (args : 'a t array) : 'b t =
  let any_args = Array.map (fun x -> Unsafe.inject x) args in
  Obj.magic (Unsafe.call fn any_args)

type 'a opt = 'a

external some : 'a t -> 'a opt t = "%identity"

let test_opt (x : 'a opt t) : bool =
  let x_any : any = Unsafe.coerce x in
  not (is_nil (Unsafe.coerce x_any))

let to_option (x : 'a opt t) : 'a t option =
  if test_opt x then Some (Unsafe.coerce x) else None

let of_option (x : 'a t option) : 'a opt t =
  match x with
  | None -> Unsafe.coerce nil
  | Some v -> Unsafe.coerce v

module Opt = struct
  type 'a t = 'a opt

  let empty : 'a t = Obj.magic 0

  let return (x : 'a) : 'a t = x

  let test (x : 'a t) : bool = Obj.magic x <> Obj.magic 0

  let map (x : 'a t) (f : 'a -> 'b) : 'b t = if test x then f x else Obj.magic 0

  let bind (x : 'a t) (f : 'a -> 'b t) : 'b t = if test x then f x else Obj.magic 0

  let iter (x : 'a t) (f : 'a -> unit) : unit = if test x then f x

  let case (x : 'a t) (f : unit -> 'b) (g : 'a -> 'b) : 'b = if test x then g x else f ()

  let get (x : 'a t) (f : unit -> 'a) : 'a = if test x then x else f ()

  let option (x : 'a option) : 'a t =
    match x with
    | None -> Obj.magic 0
    | Some v -> v

  let to_option (x : 'a t) : 'a option = if test x then Some x else None
end
