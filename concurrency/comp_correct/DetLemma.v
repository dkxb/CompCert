Require Import GMemory FMemory InteractionSemantics.
Lemma step_det_loc1_loc2:
  forall L,
    lang_det L->
    corestep_locality_1 (InteractionSemantics.step L) ->
    corestep_locality_2 (InteractionSemantics.step L).
Proof.
  unfold lang_det,step_det,corestep_locality_1,corestep_locality_2;intros.
  destruct H_step as (fp1&q1&m1&stepa).

  (* following is vibe-proved *)

  (* fp1 is captured by fp0 *)
  specialize (H1 _ _ _ stepa) as Hsub.
  (* hence m and m0 also agree on fp1 *)
  eapply LPre_subset in H2 as Hpre1;eauto.
  (* locality_1: the m-step [stepa] can be replayed from m0 with same fp1,q1 *)
  eapply H0 in stepa as Hex;eauto.
  destruct Hex as (m0'' & S0 & Hpost).
  (* determinism: S0 (from m0, fp1/q1) and H3 (from m0, fp/q') coincide *)
  eapply H in S0 as (Efp & Eq & Em);[|exact H3].
  subst.
  (* now [stepa] itself is the required m-step with fp/q' *)
  eexists. eassumption.
Qed.
Lemma GMem_eq_unchanged_on:
  forall m m' locs,
    GMem.eq m m'->
    GMem.unchanged_on locs m m'.
Proof.
  destruct 1.
  constructor;intros;auto.
  unfold GMem.perm. unfold Memperm.perm_order'.
  specialize (eq_access b ofs k).
  apply GMem.eq_access_eq_perm in eq_access.
  rewrite eq_access. split;auto.

  rewrite eq_contents;auto.
Qed.
Lemma GMem_eq_unchanged_content:
  forall m m' locs,
    GMem.eq' m m'->
    unchanged_content locs m m'.
Proof.
  destruct 1.
  constructor. constructor.
  constructor;intros;apply eq_validblocks';auto.
  unfold GMem.eq_perm.
  intros.
  unfold GMem.perm.
  specialize (eq_access' b ofs k).
  apply GMem.eq_access_eq_perm in eq_access'.
  rewrite eq_access'. split;auto.

  intros.
  erewrite eq_contents'. auto.
  unfold GMem.perm in H0.
  auto.
Qed.
  
Lemma GMem_eq_MemPre:
  forall m m' fp,
    GMem.eq' m m'->
    MemPre m m' fp.
Proof.
  intros.
  inversion H;subst.
  constructor.

  constructor. constructor.
  unfold unchanged_validity.
  split;intro;apply eq_validblocks';eauto.
  unfold GMem.eq_perm.
  intros. 
  specialize (eq_access' b ofs k).
  apply GMem.eq_access_eq_perm in eq_access'.
  unfold GMem.perm. rewrite eq_access'. split;intro;auto.

  intros. rewrite eq_contents';auto.

  constructor.
  unfold unchanged_validity.
  split;intro;apply eq_validblocks';eauto.
  unfold GMem.eq_perm.
  intros. 
  specialize (eq_access' b ofs k).
  apply GMem.eq_access_eq_perm in eq_access'.
  unfold GMem.perm. rewrite eq_access'. split;intro;auto.
  intros.
  specialize (eq_access' b ofs k).
  apply GMem.eq_access_eq_perm in eq_access'.
  unfold GMem.perm. rewrite eq_access'. split;intro;auto.
Qed.
Lemma GMem_eq_Fleq:
  forall m m' fl,
    GMem.eq' m m'->
    FreelistEq m m' fl.
Proof.
  destruct 1;constructor;intro;apply eq_validblocks';auto.
Qed.
Definition  step_mem_injc (L:Language):Prop:=
  forall ge fl q m1 fp q' m1',
    InteractionSemantics.step L ge fl q m1 fp q' m1'->
    exists fm,
      embed m1 fl fm.
Lemma eff_loc1_memeqcorestep:
  forall L (step_mem_inj:step_mem_injc L),
    corestep_local_eff (InteractionSemantics.step L)->
    corestep_locality_1 (InteractionSemantics.step L)->
    eq_mem_eq_corestep (InteractionSemantics.step L).
Proof.
  unfold corestep_local_eff,corestep_locality_1,eq_mem_eq_corestep.
  intros.
  apply step_mem_inj in H2 as H3;destruct H3 as [fm1 H3]. 
  pose proof GMem_eq_Fleq m1 m2 fl .
  inversion H3;clear H3;subst.
  assert(LPre (strip fm1) m2 fp (Mem.freelist fm1)).
  split;auto. eapply GMem_eq_MemPre;eauto.

  eapply H0 in H3 as ?;eauto.
  destruct H5 as [?[]].
  eexists;split;eauto.

  apply H in H5 as [[? _ _ _] _].
  apply H in H2 as [[? _ _ _] _].
  destruct H6 as [? _].
  unfold MemPost in H2.
  eapply unchanged_content_memeq;eauto.
  eapply unchanged_content_trans;eauto.
  apply unchanged_content_comm in MemContentPreserve0.
  eapply unchanged_content_trans;eauto.
  eapply GMem_eq_unchanged_content;eauto.
Qed.
