#######################################################################
#                                                                     #
#              The Compcert verified compiler                         #
#                                                                     #
#          Xavier Leroy, INRIA Paris-Rocquencourt                     #
#                                                                     #
#  Copyright Institut National de Recherche en Informatique et en     #
#  Automatique.  All rights reserved.  This file is distributed       #
#  under the terms of the GNU Lesser General Public License as        #
#  published by the Free Software Foundation, either version 2.1 of   #
#  the License, or (at your option) any later version.                #
#  This file is also distributed under the terms of the               #
#  INRIA Non-Commercial License Agreement.                            #
#                                                                     #
#######################################################################

include Makefile.config
include VERSION

BUILDVERSION ?= $(version)
BUILDNR ?= $(buildnr)
TAG ?= $(tag)
BRANCH ?= $(branch)

ifeq ($(wildcard $(ARCH)_$(BITSIZE)),)
ARCHDIRS=$(ARCH)
else
ARCHDIRS=$(ARCH)_$(BITSIZE) $(ARCH)
endif

CONCUR_DIRS := \
  concurrency concurrency/framework concurrency/framework/NPDefs concurrency/framework/NPDefs/DRFLemmas \
  concurrency/framework/GlobUSim concurrency/framework/GlobDSim \
  concurrency/framework/Compositionality concurrency/comp_correct/cfrontend \
  concurrency/common concurrency/comp_correct \
  concurrency/comp_correct/localize \
  concurrency/comp_correct/backend \
  concurrency/comp_correct/x86 \
  concurrency/x86TSO concurrency/x86TSO/lock_proof

DIRS := lib common $(ARCHDIRS) backend cfrontend driver cparser

ifeq ($(CLIGHTGEN),true)
DIRS += export
endif

COQINCLUDES := $(foreach d, $(DIRS), -R $(d) compcert.$(d))
COQINCLUDES += -R concurrency compcert.concurrency

ifeq ($(LIBRARY_FLOCQ),local)
DIRS += flocq/Core flocq/Prop flocq/Calc flocq/IEEE754
COQINCLUDES += -R flocq Flocq
endif

ifeq ($(LIBRARY_MENHIRLIB),local)
DIRS += MenhirLib
COQINCLUDES += -R MenhirLib MenhirLib
endif

# Notes on silenced Coq warnings:
#
# unused-pattern-matching-variable:
#    warning introduced in 8.13
#    the code rewrite that avoids the warning is not desirable
# undeclared-scope:
#    warning introduced in 8.12, addressed in the main CompCert files
#    triggered by MenhirLib, to be solved upstream
# deprecated-instance-without-locality:
#    warning introduced in 8.14
#    triggered by Menhir-generated files, to be solved upstream in Menhir
# deprecated-since-8.19
# deprecated-since-8.20
#    renamings performed in Coq's standard library;
#    using the new names would break compatibility with earlier Coq versions.
# deprecated-from-Coq
#    Rocq wants "From Stdlib Require" while Coq wants "From Coq Require".

COQCOPTS ?= \
  -w -unused-pattern-matching-variable \
  -w -deprecated-since-8.19 \
  -w -deprecated-since-8.20 \
  -w -deprecated-from-Coq

cparser/Parser.vo: COQCOPTS += -w -deprecated-instance-without-locality
MenhirLib/Interpreter.vo: COQCOPTS += -w -undeclared-scope

# Flocq and Menhirlib run into other renaming issues.
# These warnings can only be addressed upstream.

flocq/%.vo: COQCOPTS+=-w -deprecated-syntactic-definition -w -deprecated-since-9.0
MenhirLib/%.vo: COQCOPTS+=-w -deprecated-syntactic-definition -w -deprecated-since-9.0

# Concurrency files were written for Coq 8.6; suppress accumulated deprecation warnings.
concurrency/%.vo: COQCOPTS+= \
  -w -deprecated-hint-without-locality \
  -w -deprecated-instance-without-locality \
  -w -deprecated-syntactic-definition \
  -w -omega-is-deprecated \
  -w -omega-flag-deprecated

# For the extraction phase, we silence other warnings:
# change-dir-deprecated:
#    warning introduced in 8.20, no alternative before 8.20
# extraction-default-directory:
#    warning introduced in 8.20, no alternative before 8.20
# deprecated-from-Coq:
#    see above
COQEXTRACTOPTS ?= \
  -w -change-dir-deprecated \
  -w -extraction-default-directory \
  -w -deprecated-from-Coq

ifneq ($(INSTALL_COQDEV),true)
# Disable costly generation of .cmx files, which are not used locally
  COQCOPTS += -w -deprecated-native-compiler-option -native-compiler no
endif

ifneq (,$(TIMING))
  # does this coq version support -time-file ? (Coq >= 8.18)
  ifeq (,$(shell "$(COQBIN)coqc" -time-file /dev/null 2>&1))
    COQCOPTS += -time-file $<.timing
  endif
endif

ifneq (,$(PROFILING))
  # does this coq version dupport -profile ? (Coq >= 8.19)
  ifeq (,$(shell "$(COQBIN)coqc" -profile /dev/null 2>&1))
    COQCOPTS += -profile $<.prof.json
    PROFILE_ZIP = gzip -f $<.prof.json
  else
  endif
endif
PROFILE_ZIP ?= true

COQC="$(COQBIN)coqc" -q $(COQINCLUDES) $(COQCOPTS)
COQDEP="$(COQBIN)coqdep" $(COQINCLUDES)
COQDOC="$(COQBIN)coqdoc"
COQEXEC="$(COQBIN)coqtop" $(COQINCLUDES) $(COQEXTRACTOPTS) -batch -load-vernac-source
COQCHK="$(COQBIN)coqchk" $(COQINCLUDES)
COQ2HTML=coq2html
MENHIR=menhir
CP=cp

VPATH=$(DIRS) $(CONCUR_DIRS)
GPATH=$(DIRS) $(CONCUR_DIRS)

# Concurrency-Part

CCOMMON =\
  Memperm.v Blockset.v GMemory.v Footprint.v InteractionSemantics.v         \
  Injections.v MemClosures.v GAST.v LDSimDefs.v GlobDefs.v ETrace.v         \
  GlobSemantics.v DRF.v ReachClose.v SeqCorrect.v LDSim.v ListDom.v\
  FMemPerm.v FMemory.v FMemOpFP.v FMemtype.v MemAux.v GlobSemantics_Lemmas.v FMemLemmas.v

CCOMP =\
  val_casted.v FCop.v FMemAux.v Cop_fp.v CminorLang.v CminorWD.v AsmLang.v AsmWD.v AsmDET.v \
  MemClosures_local.v LDSimDefs_local.v LDSim_local.v MemInterpolant.v Localize.v  ValRels.v \
  IS_local.v MemOpFP.v ValFP.v Cop_fp_local.v DetLemma.v VundefInj.v FiniteMaps.v\
  ClightLang.v\
  CminorLocalize.v AsmLocalize.v LDSim_local_transitive.v\
  AsmIDTransCorrect.v CompCorrect.v \
  LangProps.v DisableDebug.v InjRels.v renumber.v renumber_proof.v\
  Cminor_op_footprint.v Op_fp.v infp.v \
  CUAST.v \
  helpers.v Cminor_local.v selectop_proof.v splitlong_proof.v selectlong_proof.v selectdiv_proof.v \
  selection.v selection_proof.v\
  CminorSel_local.v rtlgen.v rtlgen_proof.v \
  RTL_local.v RTLtyping_local.v \
  tailcall.v tailcall_proof.v \
  allocation.v alloc_proof.v \
  LTL_local.v  tunneling.v tunneling_proof.v linearize.v linearize_proof.v \
  cleanuplabels.v cleanuplabels_proof.v \
  Linear_local.v Lineartyping_local.v loadframe.v \
  cleanuplabels.v \
  Mach_local.v stacking.v stacking_proof.v \
  ASM_local.v asmgen.v asmgen_proof0.v asmgen_proof1.v  asmgen_proof.v \
  Clight.v ClightLang.v ClightWD.v Clight_local.v cshmgen.v cshmgen_proof.v cminorgen.v cminorgen_proof.v  Csharpminor_local.v \
  ClightLocalize.v 

CFRAME =\
  NPSemantics.v NPDet.v NPDRF.v NPEquiv.v GSimDefs.v GlobUSim.v SimDRF.v\
  USimDRF.v GDefLemmas.v TypedSemantics.v FPLemmas.v RefineEquiv.v SmileReorder.v ConflictReorder.v PRaceLemmas.v DRFLemmas.v\
  GlobUSimRefine.v GlobDSim.v GlobSim.v Flipping.v SimEtr.v\
  AuxLDSim.v Invs.v Compositionality.v Soundness.v \
  AuxLDSim.v Init.v

TSOREF =\
  SpecLang.v SpecLangIDtrans.v SpecLangWDDET.v \
  TSOMem.v AsmTSO.v TSOGlobSem.v TSOGlobUSim.v TSOAuxDefs.v\
  RGRels.v LockSim.v ClientSim.v AsmClientSim.v ObjectSim.v TSOMemLemmas.v TSOStepAuxLemmas.v SpecLangSim.v \
  code.v InvRG.v LibTactics.v AuxTacLemmas.v MemLemmas.v ObjRGIProp.v LockAcqProof.v LockRelProof.v ObjLemmas.v LockProof.v \
  SCSemLemmas.v TSOSemLemmas.v \
  TSOCompInvs.v TSOCompositionality.v \
  FinalTheoremExt.v

CONCUR =$(CCOMMON) $(CCOMP) $(CFRAME) $(TSOREF) FinalTheorem.v Languages.v FinalTheoremExt.v 

WORKINGON = $(CONCUR) 

# Flocq

ifeq ($(LIBRARY_FLOCQ),local)
FLOCQ=\
  Raux.v Zaux.v Defs.v Digits.v Float_prop.v FIX.v FLT.v FLX.v FTZ.v \
  Generic_fmt.v Round_pred.v Round_NE.v Ulp.v Core.v \
  Bracket.v Div.v Operations.v Plus.v Round.v Sqrt.v \
  Div_sqrt_error.v Mult_error.v Plus_error.v \
  Relative.v Sterbenz.v Round_odd.v Double_rounding.v \
  BinarySingleNaN.v Binary.v Bits.v
else
FLOCQ=
endif

# General-purpose libraries (in lib/)

VLIB=Axioms.v Coqlib.v Intv.v Maps.v Heaps.v Lattice.v Ordered.v \
  Iteration.v Zbits.v Integers.v Archi.v IEEE754_extra.v Floats.v \
  Parmov.v UnionFind.v Wfsimpl.v \
  Postorder.v FSetAVLplus.v IntvSets.v Decidableplus.v BoolEqual.v

# Parts common to the front-ends and the back-end (in common/)

COMMON=Errors.v AST.v Linking.v \
  Events.v Globalenvs.v Memdata.v Memtype.v Memory.v \
  Values.v Smallstep.v Behaviors.v Switch.v Determinism.v Unityping.v \
  Separation.v Builtins0.v Builtins1.v Builtins.v

# Back-end modules (in backend/, $(ARCH)/)

# backend/ files
BACKEND= \
  Allocation.v Asmgenproof0.v Bounds.v CleanupLabels.v \
  Cminor.v Cminortyping.v CminorSel.v Conventions.v Kildall.v LTL.v \
  Linear.v Linearize.v Lineartyping.v Locations.v \
  Mach.v RTL.v RTLgen.v RTLgenspec.v RTLtyping.v \
  Registers.v Renumber.v SelectDiv.v SelectDivproof.v \
  Selection.v SplitLong.v SplitLongproof.v Stacking.v \
  Tailcall.v Tunneling.v

# x86 files
BACKEND+= \
  Asm.v Asmgen.v Asmgenproof1.v Conventions1.v Machregs.v Op.v \
  SelectLong.v SelectLongproof.v SelectOp.v SelectOpproof.v Stacklayout.v

# C front-end modules (in cfrontend/)

CFRONTEND=Ctypes.v Cop.v Csyntax.v Csem.v Ctyping.v Cstrategy.v Cexec.v \
  Initializers.v Initializersproof.v \
  SimplExpr.v SimplExprspec.v SimplExprproof.v \
  Clight.v ClightBigstep.v SimplLocals.v SimplLocalsproof.v \
  Cshmgen.v Cshmgenproof.v \
  Csharpminor.v Cminorgen.v Cminorgenproof.v

# Parser

PARSER=Cabs.v Parser.v

# MenhirLib

ifeq ($(LIBRARY_MENHIRLIB),local)
MENHIRLIB=Alphabet.v Automaton.v Grammar.v Interpreter_complete.v \
  Interpreter_correct.v Interpreter.v Main.v Validator_complete.v \
  Validator_safe.v Validator_classes.v
else
MENHIRLIB=
endif

# Putting everything together (in driver/)

DRIVER=Compopts.v Compiler.v Complements.v

# Library for .v files generated by clightgen

ifeq ($(CLIGHTGEN),true)
EXPORTLIB=Ctypesdefs.v Clightdefs.v Csyntaxdefs.v
else
EXPORTLIB=
endif

# Concurrency extension files
CONCUR=$(shell find concurrency -name "*.v" | sort | tr '\n' ' ')

# All source files

FILES=$(VLIB) $(COMMON) $(BACKEND) $(CFRONTEND) $(DRIVER) $(FLOCQ) \
  $(MENHIRLIB) $(PARSER) $(EXPORTLIB) $(WORKINGON) \
  $(CCOMMON) $(CFRAME) $(CCOMP) $(TSOREF)

# Generated source files

GENERATED=\
  $(ARCH)/ConstpropOp.v $(ARCH)/SelectOp.v $(ARCH)/SelectLong.v \
  backend/SelectDiv.v backend/SplitLong.v \
  cparser/Parser.v

# Build targets for file categories

.PHONY: common backend cfrontend

common: $(COMMON:.v=.vo)

backend: $(BACKEND:.v=.vo)

cfrontend: $(CFRONTEND:.v=.vo)

concur : $(CONCUR:.v=.vo)

clean_concur:
	rm -f $(patsubst %, %/*.vo, $(CONCUR_DIRS))
	rm -f $(patsubst %, %/.*.aux, $(CONCUR_DIRS))

all:
	@test -f .depend || $(MAKE) depend
	$(MAKE) proof
	$(MAKE) extraction
	$(MAKE) ccomp
ifeq ($(HAS_RUNTIME_LIB),true)
	$(MAKE) runtime
endif
ifeq ($(CLIGHTGEN),true)
	$(MAKE) clightgen
endif
ifeq ($(INSTALL_COQDEV),true)
	$(MAKE) compcert.config
endif

proof: $(FILES:.v=.vo)

extraction: extraction/STAMP

extraction/STAMP: $(FILES:.v=.vo) extraction/extraction.v $(ARCH)/extractionMachdep.v
	rm -f extraction/*.ml extraction/*.mli
	$(COQEXEC) extraction/extraction.v
	@if grep 'AXIOM TO BE REALIZED' extraction/*.ml; then \
            echo "An error occured during extraction to OCaml code."; \
            echo "Check the versions of Flocq and MenhirLib used."; \
            exit 2; \
         fi
	touch extraction/STAMP

.depend.extr: extraction/STAMP tools/modorder driver/Version.ml
	$(MAKE) -f Makefile.extr depend

ccomp: .depend.extr compcert.ini driver/Version.ml FORCE
	$(MAKE) -f Makefile.extr ccomp
ccomp.byte: .depend.extr compcert.ini driver/Version.ml FORCE
	$(MAKE) -f Makefile.extr ccomp.byte

clightgen: .depend.extr compcert.ini driver/Version.ml FORCE
	$(MAKE) -f Makefile.extr clightgen
clightgen.byte: .depend.extr compcert.ini driver/Version.ml FORCE
	$(MAKE) -f Makefile.extr clightgen.byte

runtime:
	$(MAKE) -C runtime

FORCE:

.PHONY: proof extraction runtime FORCE

documentation: $(FILES)
	mkdir -p doc/html
	rm -f doc/html/*.html
	$(COQ2HTML) -d doc/html/ -base compcert -short-names \
	  $(patsubst %, %/*.glob, $(DIRS)) \
          $(filter-out cparser/Parser.v, $^)

tools/ndfun: tools/ndfun.ml
ifeq ($(OCAML_NATIVE_COMP),true)
	ocamlopt -o tools/ndfun -I +str str.cmxa tools/ndfun.ml
else
	ocamlc -o tools/ndfun -I +str str.cma tools/ndfun.ml
endif

tools/modorder: tools/modorder.ml
ifeq ($(OCAML_NATIVE_COMP),true)
	ocamlopt -o tools/modorder -I +str str.cmxa tools/modorder.ml
else
	ocamlc -o tools/modorder -I +str str.cma tools/modorder.ml
endif

latexdoc:
	cd doc; $(COQDOC) --latex -o doc/doc.tex -g $(FILES)

%.vo: %.v depend
	@rm -f doc/$(*F).glob
	@echo "COQC $*.v"
	@$(COQC) $*.v
	@$(PROFILE_ZIP)

%.v: %.vp tools/ndfun
	@rm -f $*.v
	@echo "Preprocessing $*.vp"
	@tools/ndfun $*.vp > $*.v || { rm -f $*.v; exit 2; }
	@chmod a-w $*.v

compcert.ini: Makefile.config
	(echo "stdlib_path=$(RELLIBDIR)"; \
         echo "prepro=$(CPREPRO)"; \
         echo "linker=$(CLINKER)"; \
         echo "asm=$(CASM)"; \
	 echo "prepro_options=$(CPREPRO_OPTIONS)";\
	 echo "asm_options=$(CASM_OPTIONS)";\
	 echo "linker_options=$(CLINKER_OPTIONS)";\
         echo "arch=$(ARCH)"; \
         echo "model=$(MODEL)"; \
         echo "abi=$(ABI)"; \
         echo "endianness=$(ENDIANNESS)"; \
         echo "system=$(SYSTEM)"; \
         echo "has_runtime_lib=$(HAS_RUNTIME_LIB)"; \
         echo "has_standard_headers=$(HAS_STANDARD_HEADERS)"; \
         echo "asm_supports_cfi=$(ASM_SUPPORTS_CFI)"; \
	 echo "response_file_style=$(RESPONSEFILE)"; \
	 echo "pic_supported=$(PIC_SUPPORTED)") \
        > compcert.ini

compcert.config: Makefile.config
	(echo "# CompCert configuration parameters"; \
        echo "COMPCERT_ARCH=$(ARCH)"; \
        echo "COMPCERT_MODEL=$(MODEL)"; \
        echo "COMPCERT_ABI=$(ABI)"; \
        echo "COMPCERT_ENDIANNESS=$(ENDIANNESS)"; \
        echo "COMPCERT_BITSIZE=$(BITSIZE)"; \
        echo "COMPCERT_SYSTEM=$(SYSTEM)"; \
        echo "COMPCERT_VERSION=$(BUILDVERSION)"; \
        echo "COMPCERT_BUILDNR=$(BUILDNR)"; \
        echo "COMPCERT_TAG=$(TAG)"; \
        echo "COMPCERT_BRANCH=$(BRANCH)" \
        ) > compcert.config

driver/Version.ml: VERSION
	(echo 'let version = "$(BUILDVERSION)"'; \
         echo 'let buildnr = "$(BUILDNR)"'; \
         echo 'let tag = "$(TAG)"'; \
         echo 'let branch = "$(BRANCH)"') > driver/Version.ml

cparser/Parser.v: cparser/Parser.vy
	@rm -f $@
	$(MENHIR) --coq --coq-no-version-check cparser/Parser.vy
	@chmod a-w $@

depend: $(GENERATED) depend1

depend1: $(FILES)
	@echo "Analyzing Coq dependencies"
	@$(COQDEP) $^ > .depend

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 0755 ./ccomp $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(SHAREDIR)
	install -m 0644 ./compcert.ini $(DESTDIR)$(SHAREDIR)
	install -d $(DESTDIR)$(MANDIR)/man1
	install -m 0644 ./doc/ccomp.1 $(DESTDIR)$(MANDIR)/man1
	$(MAKE) -C runtime install
ifeq ($(CLIGHTGEN),true)
	install -m 0755 ./clightgen $(DESTDIR)$(BINDIR)
endif
ifeq ($(INSTALL_COQDEV),true)
	install -d $(DESTDIR)$(COQDEVDIR)
	for d in $(DIRS); do \
          set -e; \
          install -d $(DESTDIR)$(COQDEVDIR)/$$d; \
          install -m 0644 $$d/*.v $$d/*.vo $$d/*.glob $(DESTDIR)$(COQDEVDIR)/$$d/; \
          if test -d $$d/.coq-native; then \
            install -d $(DESTDIR)$(COQDEVDIR)/$$d/.coq-native; \
            install -m 0644 $$d/.coq-native/* $(DESTDIR)$(COQDEVDIR)/$$d/.coq-native/; \
          fi \
	done
	install -m 0644 ./VERSION $(DESTDIR)$(COQDEVDIR)
	install -m 0644 ./compcert.config $(DESTDIR)$(COQDEVDIR)
	@(echo "To use, pass the following to coq_makefile or add the following to _CoqProject:"; echo "-R $(COQDEVDIR) compcert") > $(DESTDIR)$(COQDEVDIR)/README
endif


clean: clean_concur
	rm -f $(patsubst %, %/*.vo*, $(DIRS))
	rm -f $(patsubst %, %/.*.aux, $(DIRS))
	rm -rf $(patsubst %, %/.coq-native, $(DIRS))
	rm -f $(patsubst %, %/*.glob, $(DIRS))
	rm -rf doc/html
	rm -f driver/Version.ml
	rm -f compcert.ini compcert.config
	rm -f extraction/STAMP extraction/*.ml extraction/*.mli .depend.extr
	rm -f tools/ndfun tools/modorder tools/*.cm? tools/*.o
	rm -f $(GENERATED) .depend
	rm -f .lia.cache
	$(MAKE) -f Makefile.extr clean
	$(MAKE) -C runtime clean

distclean:
	$(MAKE) clean
	rm -f Makefile.config

check-admitted: $(FILES)
	@if grep -w 'admit\|Admitted\|ADMITTED' $^; \
         then exit 2; else echo "Nothing admitted."; fi

check-leftovers: $(FILES)
	@if grep -w '^Check\|^Print\|^Search' $^; \
         then exit 2; else echo "No leftover interactive commands."; fi

check-proof: $(FILES)
	$(COQCHK) compcert.driver.Complements

print-includes:
	@echo $(COQINCLUDES)

CoqProject:
	@echo $(COQINCLUDES) > _CoqProject

-include .depend

FORCE:
