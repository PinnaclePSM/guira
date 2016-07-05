open Sexp
open Core.Std
open Month
open Day_of_week

exception Syntax of string

let err ?e () =
  let s = match e with None -> "invalid expression" | Some a -> a in
  raise (Syntax s)

let expect want got =
  let s = match want with
    | s :: [] -> s
    | s :: ss ->
      let f a b = a ^ ", '" ^ b ^ "'" in
      "one of " ^ (List.fold ~init:("'" ^ s ^ "'") ~f ss)
    | _ -> "nothing" in
  err ~e:("expected " ^ s ^ " but got '" ^ got ^ "'") ()

type exp =
  | Variable
  | Constant of int
  | Modulo of exp * exp
  | Sum of exp list

let rec sexp_of_exp = function
  | Variable -> Atom "n"
  | Constant i -> Atom (string_of_int i)
  | Modulo (a, b) -> List [Atom "mod"; sexp_of_exp a; sexp_of_exp b]
  | Sum a -> List (Atom "+" :: List.map ~f:sexp_of_exp a)

let rec exp_of_sexp = function
  | Atom "n" -> Variable
  | Atom i -> Constant (int_of_string i)
  | List (Atom "mod" :: a :: b :: []) -> Modulo (exp_of_sexp a, exp_of_sexp b)
  | List (Atom "+" :: ints) -> Sum (List.map ~f:exp_of_sexp ints)
  | List (Atom s :: _) -> expect ["+"; "mod"] s
  | List [] -> err ~e:"empty nth selector" ()
  | _ -> err ()

type bexp =
  | Nth of exp
  | Equal_to of exp * exp

let sexp_of_bexp = function
  | Nth exp -> sexp_of_exp exp
  | Equal_to (x, y) -> List [Atom "eq"; sexp_of_exp x; sexp_of_exp y]

let bexp_of_sexp = function
  | List (Atom "eq" :: x :: y :: []) -> Equal_to (exp_of_sexp x, exp_of_sexp y)
  | sexp -> Nth (exp_of_sexp sexp)

type dayopt =
  | NthDay of bexp
  | Weekday of Day_of_week.t

let sexp_of_dayopt = function
  | NthDay exp -> List [Atom "nth"; sexp_of_bexp exp]
  | Weekday day -> Atom begin match day with
    | Mon -> "mon"
    | Tue -> "tue"
    | Wed -> "wed"
    | Thu -> "thu"
    | Fri -> "fri"
    | Sat -> "sat"
    | Sun -> "sun"
  end

let dayopt_of_sexp = function
  | List (Atom "nth" :: exp :: []) -> NthDay (bexp_of_sexp exp)
  | Atom s -> Weekday begin match s with
    | "mon" -> Mon
    | "tue" -> Tue
    | "wed" -> Wed
    | "thu" -> Thu
    | "fri" -> Fri
    | "sat" -> Sat
    | "sun" -> Sun
    | s -> expect ["a weekday"] s
  end
  | _ -> err ()

type dayopts =
  | IncDay of dayopt list
  | ExclDay of dayopt list

let sexp_of_dayopts opts =
  let f n x = List (Atom n :: List.map ~f:sexp_of_dayopt x) in
  match opts with
    | IncDay x -> f "inc" x
    | ExclDay x -> f "excl" x

let dayopts_of_sexp sexp =
  match sexp with
    | List (Atom s :: opts) ->
      begin match s with
        | "inc" -> IncDay (List.map ~f:dayopt_of_sexp opts)
        | "excl" -> ExclDay (List.map ~f:dayopt_of_sexp opts)
        | s -> expect ["inc"; "excl"] s
      end
    | _ -> err ()

type monthopt =
  | NthMonth of bexp
  | Mensis of Month.t

let sexp_of_monthopt = function
  | NthMonth exp -> List [Atom "nth"; sexp_of_bexp exp]
  | Mensis m -> Atom begin match m with
    | Jan -> "jan" | Feb -> "feb" | Mar -> "mar" | Apr -> "apr"
    | May -> "may" | Jun -> "jun" | Jul -> "jul" | Aug -> "aug"
    | Sep -> "sep" | Oct -> "oct" | Nov -> "nov" | Dec -> "dec"
  end

let monthopt_of_sexp = function
  | List (Atom "nth" :: exp :: []) -> NthMonth (bexp_of_sexp exp)
  | Atom m ->
    Mensis begin match m with
      | "jan" -> Jan | "feb" -> Feb | "mar" -> Mar | "apr" -> Apr
      | "may" -> May | "jun" -> Jun | "jul" -> Jul | "aug" -> Aug
      | "sep" -> Sep | "oct" -> Oct | "nov" -> Nov | "dec" -> Dec
      | s -> expect ["a month"] s
    end
  | _ -> err ()

type monthopts =
  | IncMonth of monthopt list
  | ExclMonth of monthopt list
  | Day of dayopts list

let sexp_of_monthopts = function
  | IncMonth o -> List (Atom "inc" :: List.map ~f:sexp_of_monthopt o)
  | ExclMonth o -> List (Atom "excl" :: List.map ~f:sexp_of_monthopt o)
  | Day o -> List (Atom "day" :: List.map ~f:sexp_of_dayopts o)

let monthopts_of_sexp = function
  | List (Atom s :: opts) ->
    begin match s with
      | "inc" -> IncMonth (List.map ~f:monthopt_of_sexp opts)
      | "excl" -> ExclMonth (List.map ~f:monthopt_of_sexp opts)
      | "day" -> Day (List.map ~f:dayopts_of_sexp opts)
      | s -> expect ["inc"; "excl"; "day";] s
    end
  | _ -> err ()

type yearopt =
  | NthYear of bexp
  | Annus of int

let sexp_of_yearopt = function
  | NthYear exp -> List [Atom "nth"; sexp_of_bexp exp]
  | Annus i -> Atom (string_of_int i)

let yearopt_of_sexp sexp =
  match sexp with
    | List (Atom "nth" :: exp :: []) -> NthYear (bexp_of_sexp exp)
    | Atom s -> Annus (int_of_string s)
    | _ -> err ()

type yearopts =
  | IncYear of yearopt list
  | ExclYear of yearopt list
  | Month of monthopts list
  | Day of dayopts list

let sexp_of_yearopts opts =
  match opts with
    | IncYear o -> List (Atom "inc" :: List.map ~f:sexp_of_yearopt o)
    | ExclYear o -> List (Atom "excl" :: List.map ~f:sexp_of_yearopt o)
    | Month o -> List (Atom "month" :: List.map ~f:sexp_of_monthopts o)
    | Day o -> List (Atom "day" :: List.map ~f:sexp_of_dayopts o)

let yearopts_of_sexp sexp =
  match sexp with
    | List (Atom s :: opts) ->
      begin match s with
        | "inc" -> IncYear (List.map ~f:yearopt_of_sexp opts)
        | "excl" -> ExclYear (List.map ~f:yearopt_of_sexp opts)
        | "month" -> Month (List.map ~f:monthopts_of_sexp opts)
        | "day" -> Day (List.map ~f:dayopts_of_sexp opts)
        | s -> expect ["inc"; "excl"; "month"; "day"] s
      end
    | _ -> err ()

type selector =
  | Or of selector list
  | And of selector list
  | Year of yearopts list
  | Month of monthopts list
  | Day of dayopts list

let rec sexp_of_selector = function
  | Or s -> List (Atom "or" :: List.map ~f:sexp_of_selector s)
  | And s -> List (Atom "and" :: List.map ~f:sexp_of_selector s)
  | Year o -> List (Atom "year" :: List.map ~f:sexp_of_yearopts o)
  | Month o -> List (Atom "month" :: List.map ~f:sexp_of_monthopts o)
  | Day o -> List (Atom "day" :: List.map ~f:sexp_of_dayopts o)

let rec selector_of_sexp sexp =
  match sexp with
    | List (Atom s :: opts) ->
      begin match s with
        | "or" -> Or (List.map ~f:selector_of_sexp opts)
        | "and" -> And (List.map ~f:selector_of_sexp opts)
        | "year" -> Year (List.map ~f:yearopts_of_sexp opts)
        | "month" -> Month (List.map ~f:monthopts_of_sexp opts)
        | "day" -> Day (List.map ~f:dayopts_of_sexp opts)
        | s -> expect ["or"; "and"; "year"; "month"; "day"] s
      end
    | _ -> err ()
