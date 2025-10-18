(* Simple calculator with expression parser and evaluator *)
(* Demonstrates: lexing, parsing, pattern matching, recursive evaluation *)

(* Token type for lexer *)
type token =
  | Number of int
  | Plus
  | Minus
  | Times
  | Divide
  | EOF

(* Expression AST *)
type expr =
  | Num of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr
  | Error

(* Lexer: convert string to list of tokens *)
let tokenize input =
  let rec tokenize_impl i acc =
    if i >= String.length input then
      List.rev (EOF :: acc)
    else
      let c = input.[i] in
      match c with
      | ' ' | '\t' | '\n' -> tokenize_impl (i + 1) acc
      | '+' -> tokenize_impl (i + 1) (Plus :: acc)
      | '-' -> tokenize_impl (i + 1) (Minus :: acc)
      | '*' -> tokenize_impl (i + 1) (Times :: acc)
      | '/' -> tokenize_impl (i + 1) (Divide :: acc)
      | '0'..'9' ->
          (* Read full number *)
          let rec read_number j num =
            if j >= String.length input then
              (j, num)
            else
              let d = input.[j] in
              match d with
              | '0'..'9' ->
                  let digit = Char.code d - Char.code '0' in
                  read_number (j + 1) (num * 10 + digit)
              | _ -> (j, num)
          in
          let digit = Char.code c - Char.code '0' in
          let (next_i, num) = read_number (i + 1) digit in
          tokenize_impl next_i (Number num :: acc)
      | _ ->
          (* Skip unknown characters silently *)
          tokenize_impl (i + 1) acc
  in
  tokenize_impl 0 []

(* Parser: convert tokens to expression AST *)
(* Grammar:
   expr   -> term (('+' | '-') term)*
   term   -> factor (('*' | '/') factor)*
   factor -> number
*)

let rec parse tokens =
  let (e, rest) = parse_expr tokens in
  match rest with
  | EOF :: _ -> e
  | _ -> Error

and parse_expr tokens =
  let (left, rest) = parse_term tokens in
  parse_expr_rest left rest

and parse_expr_rest left tokens =
  match tokens with
  | Plus :: rest ->
      let (right, rest') = parse_term rest in
      parse_expr_rest (Add (left, right)) rest'
  | Minus :: rest ->
      let (right, rest') = parse_term rest in
      parse_expr_rest (Sub (left, right)) rest'
  | _ -> (left, tokens)

and parse_term tokens =
  let (left, rest) = parse_factor tokens in
  parse_term_rest left rest

and parse_term_rest left tokens =
  match tokens with
  | Times :: rest ->
      let (right, rest') = parse_factor rest in
      parse_term_rest (Mul (left, right)) rest'
  | Divide :: rest ->
      let (right, rest') = parse_factor rest in
      parse_term_rest (Div (left, right)) rest'
  | _ -> (left, tokens)

and parse_factor tokens =
  match tokens with
  | Number n :: rest -> (Num n, rest)
  | _ -> (Error, tokens)

(* Evaluator: compute result of expression *)
let rec eval expr =
  match expr with
  | Num n -> n
  | Add (e1, e2) -> eval e1 + eval e2
  | Sub (e1, e2) -> eval e1 - eval e2
  | Mul (e1, e2) -> eval e1 * eval e2
  | Div (e1, e2) ->
      let v2 = eval e2 in
      if v2 = 0 then
        0 (* Return 0 for division by zero instead of raising *)
      else
        eval e1 / v2
  | Error -> -1 (* Return -1 for parse errors *)

(* Pretty print expression *)
let rec expr_to_string expr =
  match expr with
  | Num n -> string_of_int n
  | Add (e1, e2) ->
      Printf.sprintf "(%s + %s)" (expr_to_string e1) (expr_to_string e2)
  | Sub (e1, e2) ->
      Printf.sprintf "(%s - %s)" (expr_to_string e1) (expr_to_string e2)
  | Mul (e1, e2) ->
      Printf.sprintf "(%s * %s)" (expr_to_string e1) (expr_to_string e2)
  | Div (e1, e2) ->
      Printf.sprintf "(%s / %s)" (expr_to_string e1) (expr_to_string e2)
  | Error -> "Error"

(* Calculate and print result *)
let calculate input =
  Printf.printf "Input:  %s\n" input;
  let tokens = tokenize input in
  let expr = parse tokens in
  Printf.printf "Parsed: %s\n" (expr_to_string expr);
  let result = eval expr in
  if result = -1 then
    Printf.printf "Result: Error\n\n"
  else
    Printf.printf "Result: %d\n\n" result

let () =
  Printf.printf "=== Simple Calculator ===\n\n";

  (* Basic arithmetic *)
  calculate "2 + 3";
  calculate "10 - 4";
  calculate "5 * 6";
  calculate "20 / 4";

  (* Operator precedence *)
  calculate "2 + 3 * 4";
  calculate "2 * 3 + 4";
  calculate "10 - 2 - 3";
  calculate "20 / 4 / 2";

  (* Complex expressions *)
  calculate "1 + 2 * 3 + 4 * 5 + 6";
  calculate "100 / 5 * 2";

  (* Edge cases *)
  calculate "0";
  calculate "42";
  calculate "1 + 2 + 3 + 4 + 5";

  (* Division by zero *)
  calculate "5 / 0";
