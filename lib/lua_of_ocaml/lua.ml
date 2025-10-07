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

(* Convenience functions for calling Lua from OCaml *)

(* Function call helpers *)
let call0 (fn : (unit, 'b) fn t) : 'b t = call fn [||]

let call1 (fn : ('a, 'b) fn t) (arg : 'a t) : 'b t = call fn [| arg |]

let call2 (fn : ('a * 'b, 'c) fn t) (arg1 : 'a t) (arg2 : 'b t) : 'c t =
  let any_args = [| Unsafe.inject arg1; Unsafe.inject arg2 |] in
  Obj.magic (Unsafe.call (Obj.magic fn) any_args)

let call3 (fn : ('a * 'b * 'c, 'd) fn t) (arg1 : 'a t) (arg2 : 'b t) (arg3 : 'c t) : 'd t
    =
  let any_args = [| Unsafe.inject arg1; Unsafe.inject arg2; Unsafe.inject arg3 |] in
  Obj.magic (Unsafe.call (Obj.magic fn) any_args)

let calln (fn : ('a, 'b) fn t) (args : any array) : 'b t = Obj.magic (Unsafe.call (Obj.magic fn) args)

(* Global variable helpers *)
let get_global_fn (name : string) : ('a, 'b) fn t = Unsafe.get_global name

let get_global_table (name : string) : 'a table t = Unsafe.get_global name

let get_global_int (name : string) : int = to_integer (Unsafe.get_global name)

let get_global_number (name : string) : float = to_number (Unsafe.get_global name)

let get_global_string (name : string) : string = to_string (Unsafe.get_global name)

let get_global_bool (name : string) : bool = to_bool (Unsafe.get_global name)

let set_global_int (name : string) (value : int) : unit =
  Unsafe.set_global name (integer value)

let set_global_number (name : string) (value : float) : unit =
  Unsafe.set_global name (number value)

let set_global_string (name : string) (value : string) : unit =
  Unsafe.set_global name (string value)

let set_global_bool (name : string) (value : bool) : unit =
  Unsafe.set_global name (bool value)

(* Table access helpers *)
let get_int (tbl : 'a table t) (key : 'b t) : int = to_integer (get tbl key)

let get_number (tbl : 'a table t) (key : 'b t) : float = to_number (get tbl key)

let get_string (tbl : 'a table t) (key : 'b t) : string = to_string (get tbl key)

let get_bool (tbl : 'a table t) (key : 'b t) : bool = to_bool (get tbl key)

let get_table (tbl : 'a table t) (key : 'b t) : 'c table t = Obj.magic (get tbl key)

let get_fn (tbl : 'a table t) (key : 'b t) : ('c, 'd) fn t = Obj.magic (get tbl key)

let set_int (tbl : 'a table t) (key : 'b t) (value : int) : unit =
  set tbl key (integer value)

let set_number (tbl : 'a table t) (key : 'b t) (value : float) : unit =
  set tbl key (number value)

let set_string (tbl : 'a table t) (key : 'b t) (value : string) : unit =
  set tbl key (string value)

let set_bool (tbl : 'a table t) (key : 'b t) (value : bool) : unit =
  set tbl key (bool value)

(* Index operators *)
let ( .%{} ) (tbl : 'a table t) (key : 'b t) : 'c t = get tbl key

let ( .%{}<- ) (tbl : 'a table t) (key : 'b t) (value : 'c t) : unit = set tbl key value

(* Module loading *)
external require : string -> 'a table t = "caml_lua_require"

(* Method calls *)
let call_method (tbl : 'a table t) (method_name : string) (args : any array) : 'b t =
  let method_fn : ('c, 'b) fn t = get_fn tbl (string method_name) in
  (* Prepend table as first argument for method call *)
  let all_args = Array.append [| Unsafe.inject tbl |] args in
  calln method_fn all_args

(* Exporting OCaml to Lua *)

(* Function export *)
let export_fn0 (name : string) (f : unit -> 'a t) : unit =
  let wrapped = callback (fun _ -> f ()) in
  Unsafe.set_global name wrapped

let export_fn1 (name : string) (f : 'a t -> 'b t) : unit =
  let wrapped = callback f in
  Unsafe.set_global name wrapped

let export_fn2 (name : string) (f : 'a t -> 'b t -> 'c t) : unit =
  let wrapped =
    callback (fun args ->
        let arg_arr = to_array args in
        if Array.length arg_arr >= 2
        then f (Obj.magic arg_arr.(0)) (Obj.magic arg_arr.(1))
        else f (Obj.magic 0) (Obj.magic 0))
  in
  Unsafe.set_global name wrapped

let export_fn3 (name : string) (f : 'a t -> 'b t -> 'c t -> 'd t) : unit =
  let wrapped =
    callback (fun args ->
        let arg_arr = to_array args in
        if Array.length arg_arr >= 3
        then f (Obj.magic arg_arr.(0)) (Obj.magic arg_arr.(1)) (Obj.magic arg_arr.(2))
        else f (Obj.magic 0) (Obj.magic 0) (Obj.magic 0))
  in
  Unsafe.set_global name wrapped

let export_fnn (name : string) (f : any array -> 'a t) : unit =
  let wrapped = callback (fun args -> f (Obj.magic args)) in
  Unsafe.set_global name wrapped

(* Module export *)
let make_module (fields : (string * any) array) : 'a table t = Unsafe.table fields

let export_module (name : string) (fields : (string * any) array) : unit =
  let mod_table = make_module fields in
  Unsafe.set_global name mod_table

(* Type marshalling helpers *)
module type Marshallable = sig
  type t

  val of_lua : any -> t

  val to_lua : t -> any
end

module Int_marshal : Marshallable with type t = int = struct
  type t = int

  let of_lua (x : any) : int = to_integer (Unsafe.coerce x)

  let to_lua (x : int) : any = Unsafe.inject (integer x)
end

module Float_marshal : Marshallable with type t = float = struct
  type t = float

  let of_lua (x : any) : float = to_number (Unsafe.coerce x)

  let to_lua (x : float) : any = Unsafe.inject (number x)
end

module String_marshal : Marshallable with type t = string = struct
  type t = string

  let of_lua (x : any) : string = to_string (Unsafe.coerce x)

  let to_lua (x : string) : any = Unsafe.inject (string x)
end

module Bool_marshal : Marshallable with type t = bool = struct
  type t = bool

  let of_lua (x : any) : bool = to_bool (Unsafe.coerce x)

  let to_lua (x : bool) : any = Unsafe.inject (bool x)
end

module List_marshal (E : Marshallable) : Marshallable with type t = E.t list = struct
  type t = E.t list

  let of_lua (x : any) : E.t list =
    let tbl = Unsafe.coerce x in
    let arr = to_array tbl in
    Array.to_list arr |> List.map (fun elem -> E.of_lua (Unsafe.inject elem))

  let to_lua (lst : E.t list) : any =
    let arr = List.map E.to_lua lst |> Array.of_list in
    Unsafe.inject (array (Array.map Unsafe.coerce arr))
end

module Option_marshal (E : Marshallable) : Marshallable with type t = E.t option =
struct
  type t = E.t option

  let of_lua (x : any) : E.t option =
    let opt = Unsafe.coerce x in
    if test_opt opt
    then (
      let val_any : any = Unsafe.coerce opt in
      Some (E.of_lua val_any))
    else None

  let to_lua (opt : E.t option) : any =
    match opt with
    | None -> Unsafe.inject nil
    | Some v -> E.to_lua v
end

(* Wrapped function export with automatic marshalling *)
let export_wrapped1 (type a b) (name : string)
    (module A : Marshallable with type t = a) (module B : Marshallable with type t = b)
    (f : a -> b) : unit =
  let wrapped (x_lua : any) : any =
    let x = A.of_lua x_lua in
    let result = f x in
    B.to_lua result
  in
  export_fn1 name (fun x -> Unsafe.coerce (wrapped (Unsafe.inject x)))

let export_wrapped2 (type a b c) (name : string)
    (module A : Marshallable with type t = a) (module B : Marshallable with type t = b)
    (module C : Marshallable with type t = c) (f : a -> b -> c) : unit =
  let wrapped (x_lua : any) (y_lua : any) : any =
    let x = A.of_lua x_lua in
    let y = B.of_lua y_lua in
    let result = f x y in
    C.to_lua result
  in
  export_fn2 name (fun x y ->
      Unsafe.coerce (wrapped (Unsafe.inject x) (Unsafe.inject y)))
