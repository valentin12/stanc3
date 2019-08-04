open Core_kernel
open Common
open State.Cps

type litType = Mir_pattern.litType = Int | Real | Str
[@@deriving sexp, hash, compare]

type 'a index = 'a Mir_pattern.index =
  | All
  | Single of 'a
  | Upfrom of 'a
  | Between of 'a * 'a
  | MultiIndex of 'a
[@@deriving sexp, hash, map, compare, fold]

let pp_index pp_e ppf x = Mir_pretty_printer.pp_index pp_e ppf x

let pp_indexed pp_e ppf (ident, indices) =
  Fmt.pf ppf {|@[%s%a@]|} ident
    ( if List.is_empty indices then fun _ _ -> ()
    else Fmt.(list (pp_index pp_e) ~sep:comma |> brackets) )
    indices

module Fixed = struct
  module Pattern = struct
    type 'a t = 'a Mir_pattern.expr =
      | Var of string
      | Lit of litType * string
      | FunApp of Fun_kind.t * string * 'a list
      | TernaryIf of 'a * 'a * 'a
      | EAnd of 'a * 'a
      | EOr of 'a * 'a
      | Indexed of 'a * 'a index list
    [@@deriving sexp, hash, map, compare, fold]

    let pp pp_e ppf = Mir_pretty_printer.pp_expr pp_e ppf

    include Foldable.Make (struct type nonrec 'a t = 'a t

                                  let fold = fold
    end)

    module Make_traversable = Mir_pattern.Make_traversable_expr
    module Make_traversable2 = Mir_pattern.Make_traversable_expr2
  end

  (** Fixed-point of `expr` *)
  include Fix.Make (Pattern)
end

(** Expressions without meta data *)
module NoMeta = struct
  module Meta = struct
    type t = unit [@@deriving compare, sexp, hash]

    let pp _ _ = ()
  end

  include Specialized.Make (Fixed) (Meta)

  let remove_meta x = Fixed.map (Fn.const ()) x
end

(** Expressions with associated location and type *)
module Typed = struct
  module Meta = struct
    type t =
      { type_: UnsizedType.t
      ; loc: Location_span.t sexp_opaque [@compare.ignore]
      ; adlevel: UnsizedType.autodifftype }
    [@@deriving compare, create, sexp, hash]

    let empty =
      create ~type_:UnsizedType.uint ~adlevel:UnsizedType.DataOnly
        ~loc:Location_span.empty ()

    let adlevel {adlevel; _} = adlevel
    let type_ {type_; _} = type_
    let loc {loc; _} = loc
    let pp _ _ = ()
    let with_type ty meta = {meta with type_= ty}
  end

  include Specialized.Make (Fixed) (Meta)

  let type_of x = Meta.type_ @@ Fixed.meta x
  let loc_of x = Meta.loc @@ Fixed.meta x
  let adlevel_of x = Meta.adlevel @@ Fixed.meta x
end

(** Expressions with associated location, type and label *)
module Labelled = struct
  module Meta = struct
    type t =
      { type_: UnsizedType.t
      ; loc: Location_span.t sexp_opaque [@compare.ignore]
      ; adlevel: UnsizedType.autodifftype
      ; label: Label.t [@compare.ignore] }
    [@@deriving compare, create, sexp, hash]

    let label {label; _} = label
    let adlevel {adlevel; _} = adlevel
    let type_ {type_; _} = type_
    let loc {loc; _} = loc
    let pp _ _ = ()
  end

  include Specialized.Make (Fixed) (Meta)

  let label_of x = Meta.label @@ Fixed.meta x
  let type_of x = Meta.type_ @@ Fixed.meta x
  let loc_of x = Meta.loc @@ Fixed.meta x
  let adlevel_of x = Meta.adlevel @@ Fixed.meta x

  module Traversable_state = Fixed.Make_traversable2 (State)

  (** Statefully traverse a typed expression adding unique labels *)
  let label ?(init = Label.init) (expr : Typed.t) : t =
    let f {Typed.Meta.adlevel; type_; loc} =
      State.(
        get
        >>= fun label ->
        put (Label.next label)
        >>= fun _ -> return @@ Meta.create ~label ~adlevel ~type_ ~loc ())
    in
    Traversable_state.traverse ~f expr |> State.run_state ~init |> fst

  (** Build a map from expression labels to expressions *)
  let rec associate ?init:(assocs = Label.Map.empty) (expr : t) =
    let assocs_result : t Label.Map.t Map_intf.Or_duplicate.t =
      Label.Map.add ~key:(label_of expr) ~data:expr
        (associate_pattern assocs @@ Fixed.pattern expr)
    in
    match assocs_result with `Ok x -> x | _ -> assocs

  and associate_pattern assocs = function
    | Mir_pattern.Lit _ | Var _ -> assocs
    | FunApp (_, _, args) ->
        List.fold args ~init:assocs ~f:(fun accu x -> associate ~init:accu x)
    | EAnd (e1, e2) | EOr (e1, e2) ->
        associate ~init:(associate ~init:assocs e2) e1
    | TernaryIf (e1, e2, e3) ->
        associate ~init:(associate ~init:(associate ~init:assocs e3) e2) e1
    | Indexed (e, idxs) ->
        List.fold idxs ~init:(associate ~init:assocs e) ~f:associate_index

  and associate_index assocs = function
    | Mir_pattern.All -> assocs
    | Single e | Upfrom e | MultiIndex e -> associate ~init:assocs e
    | Between (e1, e2) -> associate ~init:(associate ~init:assocs e2) e1
end

(* == Helpers =============================================================== *)
let fix = Fixed.fix
let inj = Fixed.inj
let proj = Fixed.proj
let meta = Fixed.meta
let pattern = Fixed.pattern
let var meta name = Fixed.fix meta @@ Var name

(* == Literals ============================================================== *)

let lit meta lit_type str_value = Fixed.fix meta @@ Lit (lit_type, str_value)
let lit_int meta value = lit meta Int @@ string_of_int value
let lit_real meta value = lit meta Real @@ string_of_float value
let lit_string meta value = lit meta Str value

let is_lit ?type_ expr =
  match Fixed.pattern expr with
  | Lit (lit_ty, _) ->
      Option.value_map ~default:true ~f:(fun ty -> ty = lit_ty) type_
  | _ -> false

(* == Logical =============================================================== *)

let and_ meta e1 e2 = Fixed.fix meta @@ EAnd (e1, e2)
let or_ meta e1 e2 = Fixed.fix meta @@ EOr (e1, e2)

(* == Indexed expressions =================================================== *)
let indexed meta e idxs = Fixed.fix meta @@ Indexed (e, idxs)
let index_all meta e = indexed meta e [All]
let index_single meta e ~idx = indexed meta e [Single idx]
let index_multi meta e ~idx = indexed meta e [MultiIndex idx]
let index_upfrom meta e ~idx = indexed meta e [Upfrom idx]
let index_between meta e ~lower ~upper = indexed meta e [Between (lower, upper)]

let index_bounds = function
  | All -> []
  | Single e | MultiIndex e | Upfrom e -> [e]
  | Between (e1, e2) -> [e1; e2]

let indices_of expr =
  match Fixed.pattern expr with Indexed (_, indices) -> indices | _ -> []

(* == Ternary If ============================================================ *)
let if_ meta pred e_true e_false =
  Fixed.fix meta @@ TernaryIf (pred, e_true, e_false)

(* == Function application ================================================== *)

let fun_app meta fun_kind name args =
  Fixed.fix meta @@ FunApp (fun_kind, name, args)

let internal_fun meta fn args =
  fun_app meta CompilerInternal (Internal_fun.to_string fn) args

let stanlib_fun meta name args = Fixed.fix meta @@ FunApp (StanLib, name, args)
let user_fun meta name args = Fixed.fix meta @@ FunApp (UserDefined, name, args)

let is_fun ?kind ?name expr =
  match Fixed.pattern expr with
  | FunApp (fun_kind, fun_name, _) ->
      let same_name =
        Option.value_map ~default:true ~f:(fun name -> name = fun_name) name
      and same_kind =
        Option.value_map ~default:true ~f:(fun kind -> kind = fun_kind) kind
      in
      same_name && same_kind
  | _ -> false

let is_internal_fun ?fn expr =
  is_fun expr ~kind:CompilerInternal
    ?name:(Option.map ~f:Internal_fun.to_string fn)

let is_operator ?op expr =
  is_fun expr ~kind:StanLib ?name:(Option.map ~f:Operator.to_string op)

let contains_fun_algebra ?kind ?name = function
  | _, Fixed.Pattern.FunApp (fun_kind, fun_name, args) ->
      Option.(
        value_map ~default:true ~f:(fun name -> name = fun_name) name
        && value_map ~default:true ~f:(fun kind -> kind = fun_kind) kind)
      || List.exists ~f:Fn.id args
  | _, Var _ | _, Lit _ -> false
  | _, TernaryIf (e1, e2, e3) -> e1 || e2 || e3
  | _, EAnd (e1, e2) | _, EOr (e1, e2) -> e1 || e2
  | _, Indexed (e, idxs) ->
      e
      || List.exists idxs ~f:(fun idx ->
             List.exists ~f:Fn.id @@ index_bounds idx )

let contains_fun ?kind ?name expr =
  Fixed.cata (contains_fun_algebra ?kind ?name) expr

let contains_operator ?op expr =
  contains_fun ~kind:StanLib ?name:(Option.map ~f:Operator.to_string op) expr

let contains_internal_fun ?fn expr =
  contains_fun ~kind:StanLib
    ?name:(Option.map ~f:Internal_fun.to_string fn)
    expr

(* == Binary operations ===================================================== *)
let binop meta op a b = stanlib_fun meta (Operator.to_string op) [a; b]
let plus meta a b = binop meta Operator.Plus a b
let minus meta a b = binop meta Operator.Minus a b
let times meta a b = binop meta Operator.Times a b
let divide meta a b = binop meta Operator.Divide a b
let pow meta a b = binop meta Operator.Pow a b
let modulo meta a b = binop meta Operator.Modulo a b
let eq meta a b = binop meta Operator.Equals a b
let neq meta a b = binop meta Operator.NEquals a b
let gt meta a b = binop meta Operator.Greater a b
let gteq meta a b = binop meta Operator.Geq a b
let lt meta a b = binop meta Operator.Less a b
let lteq meta a b = binop meta Operator.Leq a b
let l_and meta a b = binop meta Operator.And a b
let l_or meta a b = binop meta Operator.Or a b

(* == Unary operations ====================================================== *)

let unop meta op e = stanlib_fun meta (Operator.to_string op) [e]
let transpose meta e = unop meta Operator.Transpose e
let l_not meta e = unop meta Operator.PNot e
let negate meta e = unop meta Operator.PMinus e

(* == General derived helpers =============================================== *)

let incr expr =
  let meta = Fixed.meta expr in
  binop meta Operator.Plus expr @@ lit_int meta 1

let decr expr =
  let meta = Fixed.meta expr in
  binop meta Operator.Minus expr @@ lit_int meta 1

(* == Constants ============================================================= *)

let zero = lit_int Typed.Meta.empty 0
let loop_bottom = lit_int Typed.Meta.empty 1


(* == StanLib smart constructors ============================================ *)

(* == Binary distributions ================================================== *)

(** Bernoulli-Logit Generalised Linear Model (Logistic Regression) *)
module Bernoulli_logit_glm = struct 
  
  let lpmf meta y x alpha beta = 
    stanlib_fun meta "bernoulli_logit_glm_lpmf" [y;x;alpha;beta]

  let lpmf_checked meta y x alpha beta = 
    match Typed.(type_of y , type_of x , type_of alpha , type_of beta) with 
    | UArray UInt , UMatrix , UReal ,UVector 
    | UArray UInt , UMatrix , UVector ,UVector -> 
          Some (lpmf meta y x alpha beta)
    | _ -> None

end 

(** Bernoulli Distribution, Logit Parameterization *)
module Bernoulli_logit = struct

  let rng meta theta = 
    stanlib_fun meta "bernoulli_logit_rng" [theta]

  let lpmf meta y alpha = 
    match Fixed.proj2 alpha with 
    | _,FunApp(StanLib,"Plus__"
                          ,[alpha
                          ;(_,FunApp(StanLib,"Times__",[x;beta]))
                          ]) when Typed.type_of x = UMatrix -> 
      Bernoulli_logit_glm.lpmf meta y x (inj alpha) beta        
    
    | _,FunApp(StanLib,"Plus__"
                          ,[(_,FunApp(StanLib,"Times__",[x;beta]))
                          ;alpha
                          ]) when Typed.type_of x = UMatrix -> 
      Bernoulli_logit_glm.lpmf meta y x (inj alpha) beta        
    | _ -> 
      stanlib_fun meta "bernoulli_logit_lpmf" [y;alpha]

  let lpmf_checked meta y alpha = 
    match Typed.type_of alpha with
    | UReal -> Some (lpmf meta y alpha)
    | _ -> None
end 

(** Bernoulli Distribution  *)
module Bernoulli = struct
  let lpmf meta y theta = 
    match Fixed.proj3 theta with 
    (* bernoulli_lpmf(y | inv_logit(alpha + x*beta)) 
        === bernoulli_logit_glm_lpmf(y | x , alpha, beta) 
    *)
    | _ , FunApp(StanLib,"inv_logit"
                      ,[(_,FunApp(StanLib,"Plus__"
                          ,[alpha
                          ;(_,FunApp(StanLib,"Times__",[x;beta]))
                          ]))
                        ]
                      )
        when Typed.type_of x = UMatrix ->
      
      Bernoulli_logit_glm.lpmf meta y x (inj alpha) beta

    (* bernoulli_lpmf(y | inv_logit(x*beta + alpha)) 
        === bernoulli_logit_glm_lpmf(y | x , alpha, beta) 
    *)
    | _ , FunApp(StanLib,"inv_logit"
                      ,[(_,FunApp(StanLib,"Plus__"
                          ,[(_,FunApp(StanLib,"Times__",[x;beta]))
                          ;alpha
                          ]))
                        ]
                      ) 
        when Typed.type_of x = UMatrix ->
    
          Bernoulli_logit_glm.lpmf meta y x (inj alpha) beta

    (* bernoulli_lpmf(y | inv_logit(x*beta)) 
        === bernoulli_logit_glm_lpmf(y | x , 0, beta) 
    *)
    | _ , FunApp(StanLib,"inv_logit",[(_,FunApp(StanLib,"Times__",[x;beta]))])
        when Typed.Meta.type_ (fst x) = UMatrix ->
    
          Bernoulli_logit_glm.lpmf meta y (inj x) zero (inj beta)


    (* bernoulli_lpmf(y | inv_logit(alpha)) 
        === bernoulli_logit_lpmf(y | alpha) 
    *)
    | _ , FunApp(StanLib,"inv_logit",[alpha])  ->    
          Bernoulli_logit.lpmf meta y (Fixed.inj2 alpha)

    | _ -> 
      fun_app meta StanLib "bernoulli_lpmf" [y;theta]
  let cdf meta y theta = 
    stanlib_fun meta "bernoulli_cdf" [y;theta]
    
  let lcdf meta y theta = 
    stanlib_fun meta "bernoulli_lcdf" [y;theta]

  let lccdf meta y theta = 
    stanlib_fun meta "bernoulli_lcdf" [y;theta]

  let rng meta theta = 
    match pattern theta with 
    | FunApp(StanLib,"inv_logit",[alpha]) -> 
      Bernoulli_logit.rng meta alpha
    | _ -> 
      stanlib_fun meta "bernoulli_rng" [theta]

end

(* == Bounded discrete distributions ======================================== *)

(** Binomial Distribution, Logit Parameterization *)
module Binomial_logit = struct 
  let lpmf meta successes trials alpha =
    stanlib_fun meta "binomial_logit_lpmf" [successes;trials;alpha]

end 

(** Binomial Distribution *)
module Binomial = struct 

  let lpmf meta successes trials theta =
    match pattern theta with     
    | FunApp(StanLib,"inv_logit",[alpha])  ->    
          Binomial_logit.lpmf meta successes trials alpha

    | _ -> 
      stanlib_fun meta "binomial_lpmf" [successes;trials;theta]

  let cdf meta y theta = 
    stanlib_fun meta "binomial_cdf" [y;theta]
    
  let lcdf meta y theta = 
    stanlib_fun meta "binomial_lcdf" [y;theta]

  let lccdf meta y theta = 
    stanlib_fun meta "binomial_lcdf" [y;theta]

  let rng meta theta = 
    stanlib_fun meta "binomial_rng" [theta]

end 


(** Beta-Binomial Distribution *)
module Beta_binomial = struct 
  let distribution_prefix suffix = "beta_binomial_" ^ suffix

  let lpmf meta successes trials alpha beta =
    stanlib_fun meta (distribution_prefix "lpmf") [successes;trials;alpha;beta]

  let cdf meta successes trials alpha beta =
    stanlib_fun meta (distribution_prefix "cdf") [successes;trials;alpha;beta]
    
  let lcdf meta successes trials alpha beta =
    stanlib_fun meta (distribution_prefix "lcdf") [successes;trials;alpha;beta]

  let lccdf meta successes trials alpha beta =
    stanlib_fun meta (distribution_prefix "lccdf") [successes;trials;alpha;beta]

  let rng meta trials alpha beta = 
    stanlib_fun meta (distribution_prefix "rng") [trials;alpha;beta]    
end 


(** Hypergeometric Distribution *)
module Hypergeometric = struct 
  let distribution_prefix suffix = "hypergeometric_" ^ suffix

  let lpmf meta successes trials a b  =
    stanlib_fun meta (distribution_prefix "lpmf") [successes;trials;a;b]  

  let rng meta trials a b = 
    stanlib_fun meta (distribution_prefix "rng") [trials;a;b]    
end 

(** Categorical Distribution, Logit Parameterization *)
module Categorical_logit = struct 
  let distribution_prefix suffix = "categorical_logit_" ^ suffix

  let lpmf meta y beta   =
    stanlib_fun meta (distribution_prefix "lpmf") [y;beta]  

  let rng meta beta = 
    stanlib_fun meta (distribution_prefix "rng") [beta]    
end 


(** Categorical Distribution *)
module Categorical = struct 
  let distribution_prefix suffix = "categorical_" ^ suffix

  let lpmf meta y theta   =
    match pattern theta with     
    | FunApp(StanLib,"inv_logit",[alpha])  ->    
      Categorical_logit.lpmf meta y alpha
    | _ -> 
      stanlib_fun meta (distribution_prefix "lpmf") [y;theta]  

  let rng meta theta = 
    stanlib_fun meta (distribution_prefix "rng") [theta]    
end 


(** Ordered Logistic Distribution *)
module Ordered_logistic = struct 
  let distribution_prefix suffix = "ordered_logistic_" ^ suffix

  let lpmf meta k eta c  =
    stanlib_fun meta (distribution_prefix "lpmf") [k;eta;c]  

  let rng meta eta c = 
    stanlib_fun meta (distribution_prefix "rng") [eta;c]    
end 




(** Ordered Probit Distribution *)
module Ordered_probit = struct 
  let distribution_prefix suffix = "ordered_probit_" ^ suffix

  let lpmf meta k eta c  =
    stanlib_fun meta (distribution_prefix "lpmf") [k;eta;c]  

  let rng meta eta c = 
    stanlib_fun meta (distribution_prefix "rng") [eta;c]    
end 

(* == Unbounded discrete distributions ====================================== *)

 
(** Negative Binomial Distribution (log alternative parameterization) *)
module Neg_binomial_2_log_glm = struct 
  let distribution_prefix suffix = "neg_binomial_2_log_glm_" ^ suffix

  let lpmf meta n x alpha beta inv_overdispersion =
    stanlib_fun meta (distribution_prefix "lpmf") [n;x;alpha;beta;inv_overdispersion]

  let rng meta x alpha beta inv_overdispersion = 
    stanlib_fun meta (distribution_prefix "rng") [x;alpha;beta;inv_overdispersion]

end

(** Negative Binomial Distribution (log alternative parameterization) *)
module Neg_binomial_2_log = struct 
  let distribution_prefix suffix = "neg_binomial_2_log_" ^ suffix

  let lpmf meta n log_location inv_overdispersion =
    stanlib_fun meta (distribution_prefix "lpmf") [n;log_location;inv_overdispersion]

  let rng meta log_location inv_overdispersion = 
    stanlib_fun meta (distribution_prefix "rng") [log_location;inv_overdispersion]
end

(** Negative Binomial Distribution (alternative parameterization) *)
module Neg_binomial_2 = struct 
  let distribution_prefix suffix = "neg_binomial_2_" ^ suffix

  let lpmf meta n location precision =
    stanlib_fun meta (distribution_prefix "lpmf") [n;location;precision]

  let cdf meta n location precision =
    stanlib_fun meta (distribution_prefix "cdf") [n;location;precision]
    
  let lcdf meta n location precision =
    stanlib_fun meta (distribution_prefix "lcdf") [n;location;precision]

  let lccdf meta n location precision =
    stanlib_fun meta (distribution_prefix "lccdf") [n;location;precision]

  let rng meta location precision = 
    stanlib_fun meta (distribution_prefix "rng") [location;precision]
end 


(** Negative Binomial Distribution *)
module Neg_binomial = struct 
  let distribution_prefix suffix = "neg_binomial_" ^ suffix

  let lpmf meta n shape inverse_scale =
    stanlib_fun meta (distribution_prefix "lpmf") [n;shape;inverse_scale]

  let cdf meta n shape inverse_scale =
    stanlib_fun meta (distribution_prefix "cdf") [n;shape;inverse_scale]
    
  let lcdf meta n shape inverse_scale =
    stanlib_fun meta (distribution_prefix "lcdf") [n;shape;inverse_scale]

  let lccdf meta n shape inverse_scale =
    stanlib_fun meta (distribution_prefix "lccdf") [n;shape;inverse_scale]

  let rng meta shape inverse_scale = 
    stanlib_fun meta (distribution_prefix "rng") [shape;inverse_scale]
end

module Poisson_log_glm = struct 
  let distribution_prefix suffix = "poisson_log_glm_" ^ suffix

  let lpmf meta y x alpha beta =
    stanlib_fun meta (distribution_prefix "lpmf") [y;x;alpha;beta]

  let rng meta x alpha beta = 
    stanlib_fun meta (distribution_prefix "rng") [x;alpha;beta]
end

module Poisson_log = struct 
  let distribution_prefix suffix = "poisson_log_" ^ suffix

  let lpmf meta n alpha =
    stanlib_fun meta (distribution_prefix "lpmf") [n;alpha]

  let rng meta alpha = 
    stanlib_fun meta (distribution_prefix "rng") [alpha]
end

(** Poisson Distribution *)
module Poisson = struct 
  let distribution_prefix suffix = "poisson_" ^ suffix

  let lpmf meta n lambda =
    stanlib_fun meta (distribution_prefix "lpmf") [n;lambda]

  let cdf meta n lambda =
    stanlib_fun meta (distribution_prefix "cdf") [n;lambda]
    
  let lcdf meta n lambda=
    stanlib_fun meta (distribution_prefix "lcdf") [n;lambda]

  let lccdf meta n lambda =
    stanlib_fun meta (distribution_prefix "lccdf") [n;lambda]

  let rng meta lambda = 
    stanlib_fun meta (distribution_prefix "rng") [lambda]    
end 

