(** The executable argument/result checks used by [ClightLang].

    CASCompCert's larger [val_casted] module also imports backend calling-
    convention files.  The Clight interaction semantics uses only these five
    architecture-independent checks, so keeping them in this small module
    avoids making the source-language boundary depend on the backend. *)

Require Import Coqlib Integers Values AST Ctypes Cop.
Require Archi.

Definition val_casted_func (v : val) (ty : type) : bool :=
  match v, ty with
  | Vint n, Tint sz si _ =>
      if Int.eq_dec (cast_int_int sz si n) n then true else false
  | Vfloat _, Tfloat F64 _ => true
  | Vsingle _, Tfloat F32 _ => true
  | Vlong _, Tlong _ _ => true
  | Vptr _ _, Tpointer _ _ => true
  | Vint _, Tpointer _ _ => negb Archi.ptr64
  | Vptr _ _, Tint I32 _ _ => negb Archi.ptr64
  | Vlong _, Tpointer _ _ => Archi.ptr64
  | Vptr _ _, Tlong _ _ => Archi.ptr64
  | Vptr _ _, Tstruct _ _ => true
  | Vptr _ _, Tunion _ _ => true
  | _, Tvoid => true
  | _, _ => false
  end.

Fixpoint val_casted_list_func (vs : list val) (ts : list type) : bool :=
  match vs, ts with
  | nil, nil => true
  | v :: vs', ty :: ts' =>
      val_casted_func v ty && val_casted_list_func vs' ts'
  | _, _ => false
  end.

Definition val_has_rettype_func (v : val) (t : xtype) : bool :=
  match v with
  | Vundef => true
  | Vint n =>
      match t with
      | Xbool => Int.eq n Int.zero || Int.eq n Int.one
      | Xint8signed => Int.eq (Int.sign_ext 8 n) n
      | Xint8unsigned => Int.eq (Int.zero_ext 8 n) n
      | Xint16signed => Int.eq (Int.sign_ext 16 n) n
      | Xint16unsigned => Int.eq (Int.zero_ext 16 n) n
      | Xint => true
      | Xptr => negb Archi.ptr64
      | Xany32 | Xany64 => true
      | _ => false
      end
  | Vlong _ =>
      match t with
      | Xlong => true
      | Xptr => Archi.ptr64
      | Xany64 => true
      | _ => false
      end
  | Vfloat _ =>
      match t with
      | Xfloat | Xany64 => true
      | _ => false
      end
  | Vsingle _ =>
      match t with
      | Xsingle | Xany32 | Xany64 => true
      | _ => false
      end
  | Vptr _ _ =>
      match t with
      | Xint => negb Archi.ptr64
      | Xlong => Archi.ptr64
      | Xptr => true
      | Xany32 => negb Archi.ptr64
      | Xany64 => true
      | _ => false
      end
  end.

Fixpoint tys_nonvoid (tyl : list type) : bool :=
  match tyl with
  | nil => true
  | Tvoid :: _ => false
  | _ :: tyl' => tys_nonvoid tyl'
  end.

Fixpoint vals_defined (vl : list val) : bool :=
  match vl with
  | nil => true
  | Vundef :: _ => false
  | _ :: vl' => vals_defined vl'
  end.
