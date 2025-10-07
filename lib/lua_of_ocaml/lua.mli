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

(** Lua FFI bindings for OCaml-Lua interop *)

(** {1 Lua Value Types} *)

(** Abstract type representing a Lua value *)
type +'a t

(** Type for any Lua value *)
type any = < > t

(** {1 Basic Types} *)

(** Lua nil type *)
type nil

(** Lua boolean type *)
type bool_t = bool

(** Lua number type (floating point) *)
type number = float

(** Lua integer type (Lua 5.3+) *)
type integer = int

(** Lua string type *)
type string_t = string

(** Lua table type *)
type 'a table

(** Lua function type *)
type (-'a, +'b) fn

(** Lua userdata type *)
type userdata

(** Lua thread (coroutine) type *)
type thread

(** {1 Type Classification} *)

type lua_type =
  | Nil
  | Boolean
  | Number
  | String
  | Table
  | Function
  | Userdata
  | Thread

(** {1 Unsafe Operations} *)

module Unsafe : sig
  (** Inject any OCaml value as a Lua value *)
  external inject : 'a -> any = "%identity"

  (** Coerce between Lua types *)
  external coerce : _ t -> _ t = "%identity"

  (** Get a field from a Lua table *)
  external get : 'a table t -> 'b -> 'c = "caml_lua_get"

  (** Set a field in a Lua table *)
  external set : 'a table t -> 'b -> 'c -> unit = "caml_lua_set"

  (** Call a Lua function *)
  external call : ('a, 'b) fn t -> any array -> 'b = "caml_lua_call"

  (** Create a Lua table from key-value pairs *)
  external table : (string * any) array -> 'a table t = "caml_lua_table"

  (** Check equality using Lua's == operator *)
  external equals : 'a -> 'b -> bool = "caml_lua_equals"

  (** Get the Lua global table *)
  val global : any table t

  (** Get a Lua global variable *)
  external get_global : string -> 'a = "caml_lua_get_global"

  (** Set a Lua global variable *)
  external set_global : string -> 'a -> unit = "caml_lua_set_global"

  (** Evaluate Lua code *)
  external eval : string -> 'a = "caml_lua_eval"

  (** Create a Lua callback from an OCaml function *)
  external callback : ('a -> 'b) -> ('a, 'b) fn t = "caml_lua_wrap_callback"
end

(** {1 Type Conversions} *)

(** [to_any x] converts any Lua value to the [any] type *)
val to_any : 'a t -> any

(** [typeof x] returns the Lua type of a value *)
external typeof : 'a t -> lua_type = "caml_lua_type"

(** {2 Nil} *)

(** The Lua nil value *)
val nil : nil t

(** [is_nil x] checks if a value is nil *)
val is_nil : 'a t -> bool

(** {2 Booleans} *)

(** [bool b] converts an OCaml bool to a Lua boolean *)
val bool : bool -> bool_t t

(** [to_bool x] converts a Lua value to an OCaml bool *)
val to_bool : 'a t -> bool

(** {2 Numbers} *)

(** [number f] creates a Lua number from a float *)
val number : float -> number t

(** [to_number x] converts a Lua value to a float *)
val to_number : 'a t -> float

(** [integer i] creates a Lua integer *)
val integer : int -> integer t

(** [to_integer x] converts a Lua value to an int *)
val to_integer : 'a t -> int

(** {2 Strings} *)

(** [string s] creates a Lua string *)
val string : string -> string_t t

(** [to_string x] converts a Lua value to a string *)
val to_string : 'a t -> string

(** {2 Tables} *)

(** [table ()] creates an empty Lua table *)
val table : unit -> 'a table t

(** [get tbl key] gets a value from a table *)
val get : 'a table t -> 'b t -> 'c t

(** [set tbl key value] sets a value in a table *)
val set : 'a table t -> 'b t -> 'c t -> unit

(** [array arr] creates a Lua array from an OCaml array *)
val array : 'a t array -> 'a table t

(** [to_array tbl] converts a Lua array to an OCaml array *)
val to_array : 'a table t -> 'a t array

(** {2 Functions} *)

(** [callback f] creates a Lua function from an OCaml function *)
val callback : ('a t -> 'b t) -> ('a, 'b) fn t

(** [call fn args] calls a Lua function with arguments *)
val call : ('a, 'b) fn t -> 'a t array -> 'b t

(** {1 Option Types} *)

(** Optional value type (can be nil) *)
type 'a opt = 'a

(** [some x] wraps a value as present *)
external some : 'a t -> 'a opt t = "%identity"

(** [test_opt x] checks if an optional value is present *)
val test_opt : 'a opt t -> bool

(** [to_option x] converts a Lua optional to an OCaml option *)
val to_option : 'a opt t -> 'a t option

(** [of_option x] converts an OCaml option to a Lua optional *)
val of_option : 'a t option -> 'a opt t

module Opt : sig
  type 'a t = 'a opt

  val empty : 'a t

  val return : 'a -> 'a t

  val map : 'a t -> ('a -> 'b) -> 'b t

  val bind : 'a t -> ('a -> 'b t) -> 'b t

  val test : 'a t -> bool

  val iter : 'a t -> ('a -> unit) -> unit

  val case : 'a t -> (unit -> 'b) -> ('a -> 'b) -> 'b

  val get : 'a t -> (unit -> 'a) -> 'a

  val option : 'a option -> 'a t

  val to_option : 'a t -> 'a option
end

(** {1 Convenience Functions for Calling Lua from OCaml} *)

(** {2 Function Call Helpers} *)

(** [call0 fn] calls a Lua function with no arguments *)
val call0 : (unit, 'b) fn t -> 'b t

(** [call1 fn arg] calls a Lua function with one argument *)
val call1 : ('a, 'b) fn t -> 'a t -> 'b t

(** [call2 fn arg1 arg2] calls a Lua function with two arguments *)
val call2 : ('a * 'b, 'c) fn t -> 'a t -> 'b t -> 'c t

(** [call3 fn arg1 arg2 arg3] calls a Lua function with three arguments *)
val call3 : ('a * 'b * 'c, 'd) fn t -> 'a t -> 'b t -> 'c t -> 'd t

(** [calln fn args] calls a Lua function with an array of arguments *)
val calln : ('a, 'b) fn t -> any array -> 'b t

(** {2 Global Variable Helpers} *)

(** [get_global_fn name] gets a global Lua function *)
val get_global_fn : string -> ('a, 'b) fn t

(** [get_global_table name] gets a global Lua table *)
val get_global_table : string -> 'a table t

(** [get_global_int name] gets a global Lua integer *)
val get_global_int : string -> int

(** [get_global_number name] gets a global Lua number *)
val get_global_number : string -> float

(** [get_global_string name] gets a global Lua string *)
val get_global_string : string -> string

(** [get_global_bool name] gets a global Lua boolean *)
val get_global_bool : string -> bool

(** [set_global_int name value] sets a global Lua integer *)
val set_global_int : string -> int -> unit

(** [set_global_number name value] sets a global Lua number *)
val set_global_number : string -> float -> unit

(** [set_global_string name value] sets a global Lua string *)
val set_global_string : string -> string -> unit

(** [set_global_bool name value] sets a global Lua boolean *)
val set_global_bool : string -> bool -> unit

(** {2 Table Access Helpers} *)

(** [get_int tbl key] gets an integer field from a table *)
val get_int : 'a table t -> 'b t -> int

(** [get_number tbl key] gets a number field from a table *)
val get_number : 'a table t -> 'b t -> float

(** [get_string tbl key] gets a string field from a table *)
val get_string : 'a table t -> 'b t -> string

(** [get_bool tbl key] gets a boolean field from a table *)
val get_bool : 'a table t -> 'b t -> bool

(** [get_table tbl key] gets a table field from a table *)
val get_table : 'a table t -> 'b t -> 'c table t

(** [get_fn tbl key] gets a function field from a table *)
val get_fn : 'a table t -> 'b t -> ('c, 'd) fn t

(** [set_int tbl key value] sets an integer field in a table *)
val set_int : 'a table t -> 'b t -> int -> unit

(** [set_number tbl key value] sets a number field in a table *)
val set_number : 'a table t -> 'b t -> float -> unit

(** [set_string tbl key value] sets a string field in a table *)
val set_string : 'a table t -> 'b t -> string -> unit

(** [set_bool tbl key value] sets a boolean field in a table *)
val set_bool : 'a table t -> 'b t -> bool -> unit

(** {2 Index Operators} *)

(** [tbl.%{key}] gets a field from a table (equivalent to tbl[key] in Lua) *)
val ( .%{} ) : 'a table t -> 'b t -> 'c t

(** [tbl.%{key} <- value] sets a field in a table (equivalent to tbl[key] = value in Lua) *)
val ( .%{}<- ) : 'a table t -> 'b t -> 'c t -> unit

(** {2 Module Loading} *)

(** [require name] requires a Lua module and returns it as a table *)
val require : string -> 'a table t

(** {2 Method Calls} *)

(** [call_method tbl method_name args] calls a method on a Lua table (equivalent to tbl:method(args)) *)
val call_method : 'a table t -> string -> any array -> 'b t

(** {1 Exporting OCaml to Lua} *)

(** {2 Function Export} *)

(** [export_fn0 name f] exports a 0-argument OCaml function to Lua globals *)
val export_fn0 : string -> (unit -> 'a t) -> unit

(** [export_fn1 name f] exports a 1-argument OCaml function to Lua globals *)
val export_fn1 : string -> ('a t -> 'b t) -> unit

(** [export_fn2 name f] exports a 2-argument OCaml function to Lua globals *)
val export_fn2 : string -> ('a t -> 'b t -> 'c t) -> unit

(** [export_fn3 name f] exports a 3-argument OCaml function to Lua globals *)
val export_fn3 : string -> ('a t -> 'b t -> 'c t -> 'd t) -> unit

(** [export_fnn name f] exports an n-argument OCaml function to Lua globals *)
val export_fnn : string -> (any array -> 'a t) -> unit

(** {2 Module Export} *)

(** [export_module name fields] exports an OCaml module as a Lua table with the given fields *)
val export_module : string -> (string * any) array -> unit

(** [make_module fields] creates a Lua table from field definitions *)
val make_module : (string * any) array -> 'a table t

(** {2 Type Marshalling Helpers} *)

(** Module signature for type-safe marshalling *)
module type Marshallable = sig
  (** The OCaml type *)
  type t

  (** Convert from Lua value to OCaml value *)
  val of_lua : any -> t

  (** Convert from OCaml value to Lua value *)
  val to_lua : t -> any
end

(** Int marshalling *)
module Int_marshal : Marshallable with type t = int

(** Float marshalling *)
module Float_marshal : Marshallable with type t = float

(** String marshalling *)
module String_marshal : Marshallable with type t = string

(** Bool marshalling *)
module Bool_marshal : Marshallable with type t = bool

(** List marshalling *)
module List_marshal (E : Marshallable) : Marshallable with type t = E.t list

(** Option marshalling *)
module Option_marshal (E : Marshallable) : Marshallable with type t = E.t option

(** {2 Wrapped Function Export} *)

(** [export_wrapped1 name f] exports a function with automatic marshalling *)
val export_wrapped1 :
     string
  -> (module Marshallable with type t = 'a)
  -> (module Marshallable with type t = 'b)
  -> ('a -> 'b)
  -> unit

(** [export_wrapped2 name f] exports a 2-arg function with automatic marshalling *)
val export_wrapped2 :
     string
  -> (module Marshallable with type t = 'a)
  -> (module Marshallable with type t = 'b)
  -> (module Marshallable with type t = 'c)
  -> ('a -> 'b -> 'c)
  -> unit
