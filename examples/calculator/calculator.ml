(* Simple calculator with expression parser and evaluator *)
(* Demonstrates: lexing, parsing, pattern matching, recursive evaluation *)

(* Token type for lexer *)
type token =
  | Number of int
  | Plus
  | Minus
  | Times
  | Divide
  | LParen
  | RParen
  | EOF

(* Expression AST *)
type expr =
  | Num of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr

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
      | '(' -> tokenize_impl (i + 1) (LParen :: acc)
      | ')' -> tokenize_impl (i + 1) (RParen :: acc)
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
          Printf.printf "Warning: Unknown character '%c' at position %d\n" c i;
          tokenize_impl (i + 1) acc
  in
  tokenize_impl 0 []

(* Parser: convert tokens to expression AST *)
(* Grammar:
   expr   -> term (('+' | '-') term)*
   term   -> factor (('*' | '/') factor)*
   factor -> number | '(' expr ')'
*)

let rec parse tokens =
  let (e, rest) = parse_expr tokens in
  match rest with
  | EOF :: _ -> e
  | _ -> failwith "Unexpected tokens after expression"

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
  | LParen :: rest ->
      let (e, rest') = parse_expr rest in
      (match rest' with
       | RParen :: rest'' -> (e, rest'')
       | _ -> failwith "Expected ')'")
  | _ -> failwith "Expected number or '('"

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
        failwith "Division by zero"
      else
        eval e1 / v2

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

(* Calculate and print result *)
let calculate input =
  try
    Printf.printf "Input:  %s\n" input;
    let tokens = tokenize input in
    let expr = parse tokens in
    Printf.printf "Parsed: %s\n" (expr_to_string expr);
    let result = eval expr in
    Printf.printf "Result: %d\n\n" result
  with
  | Failure msg ->
      Printf.printf "Error: %s\n\n" msg
  | Division_by_zero ->
      Printf.printf "Error: Division by zero\n\n"

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

  (* Parentheses *)
  calculate "(2 + 3) * 4";
  calculate "2 * (3 + 4)";
  calculate "(10 - 2) * (5 + 3)";

  (* Complex expressions *)
  calculate "((5 + 3) * 2 - 4) / 3";
  calculate "100 / (2 + 3) * 4";
  calculate "1 + 2 * 3 + 4 * 5 + 6";

  (* Edge cases *)
  calculate "0";
  calculate "42";
  calculate "(((5)))";
  calculate "1 + 2 + 3 + 4 + 5";

  (* Error cases *)
  Printf.printf "=== Testing error handling ===\n\n";
  calculate "5 / 0";
  calculate "(2 + 3";
  calculate "2 +";
