(* ::Package:: *)

(* ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ *)

(* :Title: DiracSimplify													*)

(*
	This software is covered by the GNU General Public License 3.
	Copyright (C) 1990-2016 Rolf Mertig
	Copyright (C) 1997-2016 Frederik Orellana
	Copyright (C) 2014-2016 Vladyslav Shtabovenko
*)

(* :Summary:  Like DiracTrick, but including non-commutative expansion		*)

(* ------------------------------------------------------------------------ *)

ChisholmSpinor::usage =
"ChisholmSpinor[x] uses the Chisholm identity on a DiraGamma between spinors. \
As an optional second argument 1 or 2 may be \
given, indicating that ChisholmSpinor should only act on the first \
resp. second part of a product of spinor chains.";

DiracCanonical::usage =
"DiracCanonical is an option for DiracSimplify. \
If set to True DiracSimplify uses the function DiracOrder \
internally.";

InsideDiracTrace::usage =
"InsideDiracTrace is an option of DiracSimplify. \
If set to True, DiracSimplify assumes to operate \
inside a DiracTrace, i.e., products of an odd number \
of Dirac matrices are discarded. Furthermore simple \
traces are calculated (but divided by a factor 4, \
i.e. :  DiracSimplify[DiracMatrix[a,b], InsideDiracTrace->True] \
yields  ScalarProduct[a,b]) \n
Traces involving more than \
four DiracGammas and DiracGamma[5] are not performed.";

DiracSimplify::usage =
"DiracSimplify[expr] simplifies products of Dirac matrices \
in expr and expands non-commutative products. \
Double Lorentz indices and four vectors are contracted. \
The Dirac equation is applied. \
All DiracMatrix[5], DiracMatrix[6] and DiracMatrix[7] are moved to \
the right. The order of the Dirac matrices is not changed.";

$SpinorMinimal::usage =
"$SpinorMinimal is a global switch for an additional simplification \
attempt in DiracSimplify for more than one Spinor-line. \
The default is False, since otherwise it costs too much time.";

DiracSimpCombine::usage =
"DiracSimpCombine is an option for DiracSimplify. If set to \
True, sums of DiracGamma's will be merged as much as \
possible in DiracGamma[ .. + .. + ]'s.";

DiracSubstitute67::usage =
"DiracSubstitute67 is an option for DiracSimplify. If set to \
True the chirality-projectors DiracGamma[6] and DiracGamma[7] are \
substituted by their definitions.";

SirlinRelations::usage =
"SirlinRelations is an option for DiracSimplify. If set to\
True the spinor chains that contain Dirac matrices are simplified \
using relations derived by Sirlin in Nuclear Physics B192 (1981) 93-99 \
Contrary to the original paper, the sign of the Levi-Civita tensor is \
choosen as epsilon^{0123} = 1 which is the standard choice in FeynCalc.";

DiracSimplify::noncom =
"Wrong syntax! `1` contains Dirac or SU(N) matrices multiplied via \
Times (commutative multiplication) instead of DOT (non-commutative multiplication). \
Evaluation aborted!";

DiracSimplify2::usage =
"DiracSimplify2[exp] simplifies the Dirac structure but leaves \
any DiracGamma[5] untouched. \
DiracGamma[6] and DiracGamma[7] are inserted by their definitions.";

(* ------------------------------------------------------------------------ *)

Begin["`Package`"]
End[]

Begin["`DiracSimplify`Private`"]

dsVerbose::usage="";
optInsideDiracTrace::usage="";
optExpanding::usage="";
optExpandScalarProduct::usage="";
optDiracGammaExpand::usage="";
optDiracSubstitute67::usage="";
optDiracSigmaExplicit::usage="";
optDiracEquation::usage="";
optSirlinRelations::usage="";
optDiracOrder::usage="";
optFactoring::usage="";
optContract::usage="";

DiracSimplify2[exp_] :=
	Block[ {nn,tt},

		If[	!FreeQ2[{exp}, FeynCalc`Package`NRStuff],
			Message[FeynCalc::nrfail];
			Abort[]
		];

		If[ FreeQ[exp,DOT],
			exp,
			nn = DotSimplify[DiracGammaExpand[FeynCalcInternal[exp]] /.
					DiracGamma[6] -> (1/2 + DiracGamma[5]/2) /.
					DiracGamma[7] -> (1/2 - DiracGamma[5]/2)];
			If[ FreeQ[nn, DiracGamma[5]],
				DiracSimplify[nn],
				tt = Cases2[nn, DOT];
				nn/.(Table[tt[[ij]] -> DotSimplify[
					Contract[ tt[[ij]] //.
					{doot[a__, DiracGamma[5], b__] :>
						If[ FreeQ[{a}, DiracGamma[5]],
							DiracSimplify[DOT[a]],
							DiracSimplify2[DOT[b]]
						].DiracGamma[5].
						If[ FreeQ[{b}, DiracGamma[5] ],
							DiracSimplify2[DOT[a]],
							DiracSimplify[DOT[b]]
						]
					}]], {ij,Length[tt]}])
			]
		]
	];


Options[DiracSimplify] = {
	DiracCanonical		-> False,
	DiracEquation		-> True,
	DiracSigmaExplicit	-> True,
	DiracSimpCombine	-> False,
	DiracSubstitute67	-> False,
	Expanding			-> True,
	ExpandScalarProduct	-> True,
	FCCheckSyntax		-> False,
	FCDiracIsolate		-> True,
	FCVerbose			-> False,
	Factoring			-> False,
	FeynCalcInternal    -> False,
	InsideDiracTrace    -> False,
	SirlinRelations		-> True
};



(*TODO: This syntax is really bad and should be blacklisted! *)
DiracSimplify[x_,y__, z___?OptionQ] :=
	DiracSimplify[DOT[x,y], z] /; FreeQ[{x,y}, Rule] && FreeQ[{x,y}, RuleDelayed];

(*TODO: SpinorAndPairs downvalues lookup	*)
(*TODO: Need an option that makes DiracSimplify behave like DiracSimplify2!!! *)
DiracSimplify[expr_, OptionsPattern[]] :=
	Block[{ex,res,time, null1, null2, holdDOT, freePart=0, dsPart, diracObjects,
			diracObjectsEval, repRule, tmp},

		If [OptionValue[FCVerbose]===False,
			dsVerbose=$VeryVerbose,
			If[MatchQ[OptionValue[FCVerbose], _Integer?Positive | 0],
				dsVerbose=OptionValue[FCVerbose]
			];
		];

		optInsideDiracTrace		= OptionValue[InsideDiracTrace];
		optExpanding  			= OptionValue[Expanding];
		optExpandScalarProduct	= OptionValue[ExpandScalarProduct];
		optDiracSubstitute67	= OptionValue[DiracSubstitute67];
		optDiracSigmaExplicit	= OptionValue[DiracSigmaExplicit];
		optDiracEquation		= OptionValue[DiracEquation];
		optSirlinRelations		= OptionValue[SirlinRelations];
		optDiracOrder			= OptionValue[DiracCanonical];
		optDiracGammaExpand		= !OptionValue[DiracSimpCombine];

		If[ OptionValue[Factoring] === Automatic,
			optFactoring =
				Function[x, If[ LeafCount[x] <  5000,
								Factor[x],
								x
							]
				],
			optFactoring = OptionValue[Factoring]
		];

		FCPrint[1, "DiracSimplify: Entering.", FCDoControl->dsVerbose];
		FCPrint[3, "DiracSimplify: Entering with ", expr, FCDoControl->dsVerbose];

		If[	OptionValue[FCI],
			ex = expr,
			ex = FCI[expr]
		];

		If[	OptionValue[FCCheckSyntax],
			time=AbsoluteTime[];
			FCPrint[1, "DiracSimplify: Checking the syntax", FCDoControl->dsVerbose];
			FCCheckSyntax[ex,FCI->True];
			FCPrint[1, "DiracSimplify: Checking the syntax done", FCDoControl->dsVerbose];
			FCPrint[1,"DiracSimplify: Done checking the syntax, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose]
		];

		If[ FreeQ2[ex,DiracHeadsList],
			Return[ex]
		];


		(* Two main questions: Expanding true or false? Are there spinors or not?*)
		(* TODO: Need to fish out Dirac traces and handle them separately *)


		(* Here we separately simplify each chain of Dirac matrices	*)
		If[	OptionValue[FCDiracIsolate],
			(*	This is the standard mode for calling DiracSimplify	*)
			FCPrint[1,"DiracSimplify: Normal mode.", FCDoControl->dsVerbose];
			time=AbsoluteTime[];
			FCPrint[1, "DiracSimplify: Extracting Dirac objects.", FCDoControl->dsVerbose];
			(* 	First of all we need to extract all the Dirac structures in the input. *)
			ex = FCDiracIsolate[ex,FCI->True,Head->dsHead, DotSimplify->True, DiracGammaCombine->OptionValue[DiracSimpCombine],
				DiracSigmaExplicit->OptionValue[DiracSigmaExplicit], LorentzIndex->True];

			{freePart,dsPart} = FCSplit[ex,{dsHead}];
			FCPrint[3,"DiracSimplify: dsPart: ",dsPart , FCDoControl->dsVerbose];
			FCPrint[3,"DiracSimplify: freePart: ",freePart , FCDoControl->dsVerbose];
			FCPrint[1, "DiracSimplify: Done extracting Dirac objects, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose];

			diracObjects = Cases[dsPart+null1+null2, dsHead[_], Infinity]//Sort//DeleteDuplicates;
			FCPrint[3,"DiracSimplify: diracObjects: ",diracObjects , FCDoControl->dsVerbose];

			time=AbsoluteTime[];
			FCPrint[1, "DiracSimplify: Applying diracSimplifyEval", FCDoControl->dsVerbose];

			diracObjectsEval = Map[(diracSimplifyEvalFast[#]/. diracSimplifyEvalFast->diracSimplifyEval)&, (diracObjects/.dsHead->Identity)];
			FCPrint[3,"DiracSimplify: After diracSimplifyEval: ", diracObjectsEval, FCDoControl->dsVerbose];
			FCPrint[1,"DiracSimplify: diracSimplifyEval done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose];

			If[ !FreeQ2[diracObjectsEval,{diracSimplifyEvalFast,diracSimplifyEval,holdDOT}],
				Message[DiracSimplify::failmsg,"Evaluation of isolated objects failed."];
				Abort[]
			];

			FCPrint[1, "DiracSimplify: Inserting Dirac objects back.", FCDoControl->dsVerbose];
			time=AbsoluteTime[];
			repRule = MapThread[Rule[#1,#2]&,{diracObjects,diracObjectsEval}];
			FCPrint[3,"DiracSimplify: repRule: ",repRule , FCDoControl->dsVerbose];
			tmp =  ( dsPart/.repRule);
			FCPrint[1, "DiracSimplify: Done inserting Dirac objects back, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose],

			(* 	This is a fast mode for input that is already isolated, e.g. for calling DiracSimplify/@exprList
				from internal functions	*)
			FCPrint[1,"DiracSimplify: Fast mode.", FCDoControl->dsVerbose];

			tmp = diracSimplifyEvalFast[ex];
			(* It might happen that after diracSimplifyEvalFast there are no Dirac matrices left.*)

			FCPrint[3,"DiracSimplify: After diracSimplifyEvalFast: ", tmp , FCDoControl->dsVerbose];

			If[ !FreeQ2[tmp,{DiracHeadsList,diracSimplifyEvalFast}],
				tmp = tmp /. diracSimplifyEvalFast->diracSimplifyEval
			];

			If[ !FreeQ2[tmp,{diracSimplifyEvalFast,diracSimplifyEval,holdDOT}],
				Message[DiracSimplify::failmsg,"Evaluation of isolated objects failed."];
				Abort[]
			]
		];

		(* To simplify products of spinor chains we need to work with the full expression	*)
		If[	!FreeQ[tmp,Spinor],

			FCPrint[1, "DiracSimplify: Simplifying spinor chains.", FCDoControl->dsVerbose];

			tmp = FCDiracIsolate[tmp,FCI->True, Head->dsHead, DotSimplify->True, DiracGammaCombine->OptionValue[DiracSimpCombine],
				DiracSigmaExplicit->optDiracSigmaExplicit, LorentzIndex->True, Spinor->Join, DiracGamma->False,
				Isolate->True, IsolateNames->dsIso] /. dsHead->Identity;

			(* First of all, let us canonicalize dummy Lorentz and Cartesian indices *)
			tmp = FCCanonicalizeDummyIndices[tmp, FCI->True, Head->{LorentzIndex,CartesianIndex}];

			(* then do the contractions *)
			tmp = tmp /. dsHead[x_] :> Contract[x, FCI->True];
			tmp = FRH[tmp, IsolateNames->dsIso];

			(* and collect again *)
			tmp = FCDiracIsolate[tmp,FCI->True,Head->dsHead, DotSimplify->True, DiracGammaCombine->OptionValue[DiracSimpCombine],
				DiracSigmaExplicit->OptionValue[DiracSigmaExplicit], LorentzIndex->True, Spinor->Join, DiracGamma->False];

			diracObjects = Cases[tmp+null1+null2, dsHead[_], Infinity]//Sort//DeleteDuplicates;

			(* Contract and recollect ... *)

			FCPrint[3,"DiracSimplify: diracObjects: ",diracObjects , FCDoControl->dsVerbose];



			diracObjectsEval = Map[(diracSimplifySpinors[#])&, (diracObjects/.dsHead->Identity)];

			If[ !FreeQ2[diracObjectsEval,{diracSimplifySpinors,holdDOT}],
				Message[DiracSimplify::failmsg,"Evaluation of isolated objects failed."];
				Abort[]
			];

			FCPrint[1, "DiracSimplify: Inserting Dirac objects back.", FCDoControl->dsVerbose];
			time=AbsoluteTime[];
			repRule = MapThread[Rule[#1,#2]&,{diracObjects,diracObjectsEval}];
			FCPrint[3,"DiracSimplify: repRule: ",repRule , FCDoControl->dsVerbose];
			tmp =  ( tmp/.repRule);
			FCPrint[1, "DiracSimplify: Done inserting Dirac objects back, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose]
		];



		res = freePart + tmp;

		If[	optExpanding,
			time=AbsoluteTime[];
			FCPrint[1, "DiracSimplify: Expanding the result.", FCDoControl->diTrVerbose];
			res = Expand[res];
			FCPrint[1,"DiracSimplify: Expanding done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];
			FCPrint[3, "DiracSimplify: After expanding: ", res, FCDoControl->diTrVerbose]
		];




		(*
		If[ !OptionValue[Expanding],
			(* If Expanding is set to False, just use the Dirac equation and apply DotSimplify.*)
			If[ OptionValue[DiracSigmaExplicit],
				ex = DiracSigmaExplicit[ex,FCI->True]
			];
			ex = DotSimplify[ex, Expanding -> False];
			If[ OptionValue[DiracEquation] && !FreeQ[ex,Spinor],
				ex = DiracEquation[ex, FCI->True]
			],
			(*If Expanding is set to True, the main simplification function (oldDiracSimplify) is applied.*)
			time=AbsoluteTime[];
			FCPrint[1, "DiracSimplify: Applying PairContract.", FCDoControl->dsVerbose];
			FCPrint[3,"DiracSimplify: Doing contractions on ", ex, FCDoControl->dsVerbose];
			ex = ex /. Pair -> PairContract;
			If[ OptionValue[DiracSigmaExplicit],
				ex = DiracSigmaExplicit[ex, FCI->True]
			];
			FCPrint[1,"DiracSimplify: Done applying PairContract, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose];
			time=AbsoluteTime[];
			FCPrint[1, "DiracSimplify: Starting oldDiracSimplify", FCDoControl->dsVerbose];
			FCPrint[3,"DiracSimplify: Doing oldDiracSimplify on ", ex, FCDoControl->dsVerbose];
			ex = oldDiracSimplify[ex,Flatten[Join[{opts}, FilterRules[Options[DiracSimplify], Except[{opts}]]]]]/. PairContract -> Pair;
			FCPrint[1,"DiracSimplify: Done doing oldDiracSimplify, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose];
		];*)

		(*res = ex;*)
		FCPrint[3,"DiracSimplify: Leaving with ", res, FCDoControl->dsVerbose];
		res
	];



(*
dit[x_,ops___Rule] :=
	DiracTrace[diracSimplify@@Join[{x},{ops}, Flatten[Prepend[{Options[DiracSimplify]}, InsideDiracTrace -> True]]]];

diracSimplify[z_, OptionsPattern[]] :=
	(Contract[z]/.DiracTrace->dit)/;!FreeQ[z,DiracTrace];

dS[x___] :=
	If[ $BreitMaison === True,
		dSBM[x],
		dSNV[x]
	];

dSBM[x___] :=
	MemSet[dSBM[x], DiracTrick[x]];
dSNV[x___] :=
	MemSet[dSNV[x], DiracTrick[x]];
*)


(* ****************************************************************** *)
(*
(*this is oldDiracSimplify for spinor free expressions*)
oldDiracSimplify[x_, opts:OptionsPattern[]] :=
	diracSimplify[x, opts] /; FreeQ[x, Spinor];
*)
(*this is oldDiracSimplify for expressions that contain spinors*)
oldDiracSimplify[x_,opts:OptionsPattern[]] :=
	Block[ {ex=x,dre, factoring,dooo,diracga67},
		FCPrint[2,"DiracSimplify: oldDiracSimplify: Entering with ", ex, FCDoControl->dsVerbose];

		factoring = OptionValue[DiracSimplify,{opts},Factoring];
		diracga67    = OptionValue[DiracSimplify,{opts},DiracSubstitute67];
		If[ factoring === True,
			factoring = Factor2
		];

		If[ diracga67,
			ex = DiracSubstitute67[ex];
		];

		dre = Collect[DotSimplify[DiracTrick[DiracGammaCombine[ex,FCI->True]]]/.
		DOT->dooo,dooo[__]]/.dooo->DOT;
		dre =  FixedPoint[ SpinorChainEvaluate[#,opts]&, dre, 142];
		If[ !FreeQ[dre, Eps],
			dre = Contract[dre, EpsContract -> True];
			dre = FixedPoint[ SpinorChainEvaluate[#,opts]&, dre, 142],
			If[ !FreeQ[dre, LorentzIndex],
				dre = Contract[dre, Expanding -> False]
			];
			dre = FixedPoint[ SpinorChainEvaluate[#,opts]&, dre, 142];
		];

		FCPrint[2,"DiracSimplify: oldDiracSimplify: Doing contractions in ", dre, FCDoControl->dsVerbose];

		If[ !FreeQ[dre, LorentzIndex],
			FCPrint[2,"contracting in oldDiracSimpify"];
			dre = Contract[dre];
			FCPrint[2,"contracting in oldDiracSimpify done"]
		];

		If[ Length[DownValues[SpinorsandPairs]] > 1,
			dre = (dre /. DOT -> SpinorsandPairs/. SpinorsandPairs->DOT)//DotSimplify[#, Expanding -> False]&
		];

		If[ !FreeQ[dre, DiracGamma],
			dre = Expand2[dre, DiracGamma]
		];

		If[ factoring =!= False,
			dre = factoring[dre]
		];

		FCPrint[2,"DiracSimplify: oldDiracSimplify: Leaving with ", dre, FCDoControl->dsVerbose];

		dre
	]/; !FreeQ[x,Spinor];

DiracSubstitute67[x_] :=
	x/. {DiracGamma[6] :> (1/2 + DiracGamma[5]/2),
		DiracGamma[7] :> (1/2 - DiracGamma[5]/2)};
(*
(*if the expression doesn't contain any non-commutative objects, return it unevaluated*)
diracSimplify[x_, OptionsPattern[]] :=
	x /; NonCommFreeQ[x];
*)
(*CHANGE 1298 *)
(*
diracSimplify[x_, in:OptionsPattern[]] :=
	If[ $BreitMaison === True,
		diracSimplifyBM[x,in],
		diracSimplifyNV[x,in]
	];
*)
(*
diracSimplifyBM[x_,in:OptionsPattern[]] :=
	MemSet[diracSimplifyBM[x,in], diracSimplifyGEN[x,in]];
diracSimplifyNV[x_,in:OptionsPattern[]] :=
	MemSet[diracSimplifyNV[x,in], diracSimplifyGEN[x,in]];

diracSimplifyInsideTrace[ex_] :=
	Block[{diracdt=ex,holdDOT},
		(* bug fix 2005-02-05: this is a problem because of Flat and OneIdentity of Dot ... *)
		(*    diracdt = diracdt/.DOT->trIC/. *)
		(*  only do cyclicity simplification if there is a simple structure of Dirac matrices *)
		If[ FreeQ[diracdt/. DOT -> holdDOT, holdDOT[a__/; !FreeQ[{a}, holdDOT]]],
			diracdt = diracdt/.DOT->trIC/.
			(* bug fix on September 25th 2003 (RM): due to earlier changes this was overseen:*)
			{trI:>dS, spursav:> dS};
		];


		(* careful: can run into infinite loop ..., adding a cut in FixedPoint, 10.9.2003 *)
		(* even be more careful: and get rid of cyclic simplifications hrere ... *)
		diracdt =
			FixedPoint[Collect2[#/.DOT->dS, DOT, Factoring -> False]&, diracdt, 5](*/.DOT ->trIC/.trI->dS*);
		FCPrint[2,"dir2done, diracdt=", FullForm[diracdt]];
		If[ FreeQ[ diracdt, DOT ],
			diracdt = diracdt/.DiracGamma[_[__],___]->0;
			diracpag = PartitHead[diracdt,DiracGamma];
			If[ diracpag[[2]] === DiracGamma[5],
				diracdt = 0
			];
			If[ diracpag[[2]] === DiracGamma[6] || diracpag[[2]] === DiracGamma[7],
				diracdt = 1/2  diracpag[[1]]
			]
		];
		diracdt
	];
*)

diracSimplifyEval[expr_]:=
	Block[{tmp=expr, time, time2, res},

		(*	General algorithm of diracSimplifyEval:

			1)	Apply DiracTrick to the unexpanded expression
			2)	Expand the expression using DotSimplify and apply DiracTrick again
			3)	If there are uncontracted indices, contract them
			4)	If needed, expand scalar products
			5) 	If needed, replace chiral projectors by their explicit values and apply DotSimplify
				afterwards

			6) 	If the expression contains spinors
				6.1) If needed, apply the Dirac equation
				6.2) If needed, apply Sirlin's relations

			7)	If needed, order the remaining Dirac matrices canonically
			8)	If needed, factor the result

		*)



		FCPrint[1, "DiracSimplify: diracSimplifyEval: Entering", FCDoControl->dsVerbose];
		FCPrint[3, "DiracSimplify: diracSimplifyEval: Entering with: ", tmp, FCDoControl->dsVerbose];



		(* First application of DiracTrick, no expansions so far *)
		time=AbsoluteTime[];
		FCPrint[1,"DiracSimplify: diracSimplifyEval: Applying DiracTrick.", FCDoControl->dsVerbose];
		tmp = DiracTrick[tmp, FCI -> True, InsideDiracTrace-> optInsideDiracTrace, FCDiracIsolate->False];
		FCPrint[1,"DiracSimplify: diracSimplifyEval: DiracTrick done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose];
		FCPrint[3,"DiracSimplify: diracSimplifyEval: After DiracTrick: ", tmp, FCDoControl->dsVerbose];

		(*	Expansion of Dirac slashes	*)
		If[	optDiracGammaExpand,
			tmp = DiracGammaExpand[tmp,FCI->True];
		];



		time=AbsoluteTime[];
		If[ !FreeQ[tmp, DiracGamma] && optExpanding,
			(*	If the output of DiracTrick still contains Dirac matrices, apply DotSimplify and use DiracTrick again	*)
			time2=AbsoluteTime[];
			FCPrint[1,"DiracSimplify: diracSimplifyEval: Applying Dotsimplify.", FCDoControl->dsVerbose];
			tmp = DotSimplify[tmp, FCI->True, Expanding -> True, FCJoinDOTs->False];
			FCPrint[1,"DiracSimplify: diracSimplifyEval: Dotsimplify done, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->dsVerbose];
			FCPrint[3,"DiracSimplify: diracSimplifyEval: After Dotsimplify: ", tmp, FCDoControl->dsVerbose];


			time2=AbsoluteTime[];
			FCPrint[1,"DiracSimplify: diracSimplifyEval: Applying DiracTrick.", FCDoControl->dsVerbose];
			tmp = DiracTrick[tmp, FCI -> True, InsideDiracTrace-> optInsideDiracTrace, FCJoinDOTs->False];
			FCPrint[1,"DiracSimplify: diracSimplifyEval: DiracTrick done, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->dsVerbose];
			FCPrint[3,"DiracSimplify: diracSimplifyEval: After DiracTrick: ", tmp, FCDoControl->dsVerbose];
		];


		(* Doing index contractions *)
		If[	optContract=!=False && !DummyIndexFreeQ[tmp,{LorentzIndex,CartesianIndex}],
			FCPrint[1, "DiracSimplify: diracSimplifyEval: Applying Contract.", FCDoControl->dsVerbose];
			tmp = Contract[tmp, Expanding->True, EpsContract-> optEpsContract, Factoring->False];
			FCPrint[1, "DiracSimplify: diracSimplifyEval: Contract done, timing: ", N[AbsoluteTime[] - time, 4] , FCDoControl->dsVerbose]
		];

		(* 	Expansion of the scalar products.	*)
		If[ optExpandScalarProduct && !FreeQ[tmp,Momentum],
			time2=AbsoluteTime[];
			FCPrint[1,"DiracSimplify: diracSimplifyEval: Expanding scalar products", FCDoControl->dsVerbose];
			tmp = ExpandScalarProduct[tmp,FCI->False];
			FCPrint[1,"DiracSimplify:diracSimplifyEvale: Done expanding the result, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->dsVerbose]
		];

		(*	Substituting the explicit values of Dirac sigma	*)
		If [ optDiracSigmaExplicit && !FreeQ[tmp,DiracSigma],
			tmp = DiracSigmaExplicit[tmp,FCI->True]
		];

		(* 	Canonical ordering of the Dirac matrices.	*)
		If[ optDiracOrder,
				time2=AbsoluteTime[];
				FCPrint[1,"DiracSimplify: diracSimplifyEval: Applying DiracOrder.", FCDoControl->dsVerbose];
				tmp = DiracOrder[tmp, FCI->True, FCJoinDOTs->OptionValue[Expanding]];
				FCPrint[1,"DiracSimplify:diracSimplifyEvale: Done applying DiracOrder, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->dsVerbose]
		];


		(*	Expansion of Dirac slashes	*)
		(*
		If[	optDiracGammaExpand,
			FCPrint[1,"DiracSimplify: diracSimplifyEval: Expanding Dirac slashes.", FCDoControl->dsVerbose];
			tmp = DiracGammaExpand[tmp,FCI->True];

		];*)


		(*	Substituting the explicit values of the chiral projectors	*)
		If[ optDiracSubstitute67 && !FreeQ2[tmp,{DiracGamma[6],DiracGamma[7]}],
			FCPrint[1,"DiracSimplify: diracSimplifyEval: Substituting the explicit values of the chiral projectors.", FCDoControl->dsVerbose];
			tmp = DiracSubstitute67[tmp]
		];


		If[	optExpanding && (optDiracGammaExpand || optDiracSubstitute67),
			time2=AbsoluteTime[];
			FCPrint[1,"DiracSimplify: diracSimplifyEval: Applying Dotsimplify.", FCDoControl->dsVerbose];
			tmp = DotSimplify[tmp, FCI->True, Expanding -> True];
			FCPrint[1,"DiracSimplify: diracSimplifyEval: Dotsimplify done, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->dsVerbose];
			FCPrint[3,"DiracSimplify: diracSimplifyEval: After Dotsimplify: ", tmp, FCDoControl->dsVerbose];
		];


		(*	Dirac equation	*)
		If[	!FreeQ[tmp,Spinor] && optDiracEquation,
			tmp = DiracEquation[tmp, FCI->True]
		];

		(* 	Covariant normalization of ubar.u or vbar.v (as in Peskin and Schroeder).
			The combinations ubar.v and vbar.u are orthogonal and hence vanish *)
		If[	!FreeQ[tmp,Spinor],
			FCPrint[2,"DiracSimplify: Applying spinor normalization on ", ex, FCDoControl->dsVerbose];

			tmp = tmp/. DOT->holdDOT //.
			{	holdDOT[Spinor[s_. Momentum[p__],m_, 1],Spinor[s_. Momentum[p__],m_, 1]] -> s 2 m,
				holdDOT[Spinor[- Momentum[p__],m_, 1],Spinor[Momentum[p__],m_, 1]] -> 0,
				holdDOT[Spinor[Momentum[p__],m_, 1],Spinor[- Momentum[p__],m_, 1]] -> 0} /.
			holdDOT -> DOT
		];

		(* Factoring	*)
		If[ optFactoring=!=False,
				time2=AbsoluteTime[];
				FCPrint[1,"DiracSimplify: diracSimplifyEval: Factoring the result.", FCDoControl->dsVerbose];
				tmp = optFactoring[tmp];
				FCPrint[1,"DiracSimplify:diracSimplifyEvale: Done factoring, timing: ", N[AbsoluteTime[] - time2, 4], FCDoControl->dsVerbose]
		];

		res = tmp;

		FCPrint[3,"DiracSimplify: diracSimplifyEval: Leaving with: ", res, FCDoControl->dsVerbose];

		res


	];

(*
diracSimplifyGEN[x_, opts:OptionsPattern[]] :=
	If[ FreeQ[x, DiracGamma],
		x,
		Block[ {diracopt,diracdt,diracndt = 0,diraccanopt,diracpdt,diracgasu,
			diracldt,diracjj = 0,diractrlabel,diracga67,diracsifac,
			diracpag,colle, dooT,time},
			(* There are several options *)





			diraccanopt  = OptionValue[DiracSimplify,{opts},DiracCanonical];
			diractrlabel = OptionValue[DiracSimplify,{opts},InsideDiracTrace];
			diracga67    = OptionValue[DiracSimplify,{opts},DiracSubstitute67];
			diracgasu    = OptionValue[DiracSimplify,{opts},DiracSimpCombine];
			diracsifac   = OptionValue[DiracSimplify,{opts},Factoring];


			time=AbsoluteTime[];
			FCPrint[1,"DiracSimplify: diracSimplifyGEN: Applying DotSimplify.", FCDoControl->dsVerbose];
			FCPrint[3,"DiracSimplify: diracSimplifyGEN: Applying DotSimplify to  ", x, FCDoControl->dsVerbose];
			diracdt = DotSimplify[x//DiracGammaExpand, Expanding -> False];

			FCPrint[1,"DiracSimplify: diracSimplifyGEN: Done applying DotSimplify, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose];


			time=AbsoluteTime[];
			FCPrint[1,"DiracSimplify: diracSimplifyGEN: Doing index contractions.", FCDoControl->dsVerbose];
			FCPrint[3,"DiracSimplify: diracSimplifyGEN: Contract indices in  ", diracdt, FCDoControl->dsVerbose];
			If[ diracgasu === True,
				diracdt = Contract[DiracGammaCombine[diracdt/.Pair->PairContract,FCI->True], Expanding -> True, Factoring -> False, EpsContract -> False],
				diracdt = Contract[diracdt, Expanding -> True, Factoring -> False, EpsContract -> False]
			(*/. DOT->dS*)
			];
			FCPrint[1,"DiracSimplify: diracSimplifyGEN: Done doing index contractions, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->dsVerbose];


			(* Commented out Sept. 9 203 by RM, in order to fix the 27/3 2003 bug
			diracdt = Expand2[ ExpandScalarProduct[diracdt//fEx], {Pair, DOT}]; *)

			If[ diractrlabel===True,
				FCPrint[2,"DiracSimplify: diracSimplifyGEN: Simplifications inside a Dirac trace.", FCDoControl->dsVerbose];
				FCPrint[3,"DiracSimplify: diracSimplifyGEN: Applying simplifications that are valid only inside a Dirac trace", FCDoControl->dsVerbose];
				diracdt=diracSimplifyInsideTrace[diracdt]
			];
			(* Change 27/3-2003 by Rolf Mertig, see above (27/3-2003)*)
			FCPrint[2,"dir2a, diracdt=", FullForm[diracdt]];
			(* diracdt = Expand2[ ExpandScalarProduct[diracdt//fEx], {Pair, DOT}]; *)

			FCPrint[2,"DiracSimplify: diracSimplifyGEN: Expanding scalar products", FCDoControl->dsVerbose];
			diracdt =
				Expand[ ExpandScalarProduct[diracdt//fEx], DOT | Pair];


			FCPrint[2,"dir3, diracdt=", FullForm[diracdt]];
			If[ FreeQ[diracdt,DOT],
				diracndt = Expand[(diracdt/.PairContract->ExpandScalarProduct)//DiracGammaExpand];
				If[ diracga67 === True,
					diracndt = Expand[diracndt//DiracSubstitute67]
				],
				FCPrint[2,"dir3 expanding "];
				(* diracdt = Expand[ diracdt ]; *)
				diracdt = Expand[ diracdt, DOT ];
				FCPrint[2,"dir3 expanding done ", Length[diracdt]];
				If[ Head[diracdt] === Plus,
					diracldt = Length[diracdt],
					If[ diracdt===0,
						diracldt = 0,
						diracldt = 1
					]
				];

				diracpdt = diracdt;

				(* TODO: Here we would need cyclicity simplifications *)
				(*If[ diractrlabel,
					(* change 2005-02-05
					diracpdt = diracpdt/.DOT->trIC/.trI->dS//. DOT -> trIC/.trI->dS; *)
					diracpdt = DiracTrick[diracpdt]
				];*)
(*
				FCPrint[1,"DiracSimplify: diracSimplifyGEN: Expanding scalar products", FCDoControl->dsVerbose];
				diracpdt = ExpandScalarProduct[diracpdt]//Expand;*)


				FCPrint[1,"DiracSimplify: diracSimplifyGEN: Subsituting chiral projectors", FCDoControl->dsVerbose];
				If[ diracga67,
					If[!FreeQ2[diracpdt,{DiracGamma[6],DiracGamma[7]}],
						diracpdt = DiracSubstitute67[diracpdt]
					];
					If[!FreeQ2[diracndt,{DiracGamma[6],DiracGamma[7]}],
						diracndt = DiracSubstitute67[diracndt]
					]
				];


				FCPrint[1,"DiracSimplify: diracSimplifyGEN: Applying DiracTrick", FCDoControl->dsVerbose];
				diracpdt = fEx[DiracGammaExpand[diracpdt]]//DiracTrick;


				If[ diractrlabel===True,
					FCPrint[2,"DiracSimplify: diracSimplifyGEN: Simplifications inside a Dirac trace.", FCDoControl->dsVerbose];
					FCPrint[3,"DiracSimplify: diracSimplifyGEN: Applying simplifications that are valid only inside a Dirac trace", FCDoControl->dsVerbose];
					diracpdt=diracSimplifyInsideTrace[diracpdt]
				];

				(*If[ diractrlabel,
					diracpdt = fEx[(diracpdt//DiracGammaExpand)//DiracTrick](*/.
									DOT->trIC/.trI->dS//.DOT->dS/.
									DOT->trIC/.trI->dS *) ,
					diracpdt = fEx[DiracGammaExpand[diracpdt]//DiracTrick]//DiracTrick
				];*)

				(*FCPrint[1,"DiracSimplify: diracSimplifyGEN: Subsituting chiral projectors", FCDoControl->dsVerbose];
				If[ diracga67,
					diracpdt = DiracSubstitute67[ diracpdt/.DOT->dr67 ],
					diracpdt = fEx[ diracpdt ]
				];*)

				FCPrint[1,"DiracSimplify: diracSimplifyGEN: Expanding scalar products and other things", FCDoControl->dsVerbose];
				diracndt = diracndt + Expand2[ExpandScalarProduct[diracpdt], DOT];

				FCPrint[1,"DiracSimplify: diracSimplifyGEN: Doing contractions", FCDoControl->dsVerbose];
				diracndt = diracndt /. PairContract->ExpandScalarProduct;

				FCPrint[1,"DiracSimplify: diracSimplifyGEN: Applying DotSimplify", FCDoControl->dsVerbose];
				diracndt = DotSimplify[diracndt, Expanding -> False]//Expand;

				If[ diraccanopt===True,
					FCPrint[1,"DiracSimplify: diracSimplifyGEN: Applying canonical ordering", FCDoControl->dsVerbose];
					diracndt = DiracOrder[ diracndt ];
					diracndt = DotSimplify[diracndt, Expanding -> False]//Expand
				];
			];

			If[ diracsifac,
				FCPrint[1,"DiracSimplify: diracSimplifyGEN: Factoring the result", FCDoControl->dsVerbose];
				diracndt = Factor2[ diracndt ]
			];

			FCPrint[1,"DiracSimplify: diracSimplifyGEN: Leaving DiracSimplify", FCDoControl->dsVerbose];

			diracndt/.spursav:> DOT
		]
	];  (* end of diracSimplify *)
*)
(*
dr67[ b___ ] :=
	dS[ b ]/;FreeQ2[{b},{DiracGamma[6],DiracGamma[7]}];

dr67[ b___,DiracGamma[6],z___ ] :=
	1/2 dS[b,z] + 1/2 dS[ b,DiracGamma[5],z];

dr67[ b___,DiracGamma[7],z___ ] :=
	1/2 dS[b,z] - 1/2 dS[ b,DiracGamma[5],z];





(* cyclic property *) (* Changed by F.Orellana, 14/1-2002.
						Dropped Kreimer scheme. According to
						Rolf it's wrong *)
trIC[y___] :=
	tris @@ cyclic[y];

cyclic[x__] :=
	RotateLeft[{x},Position[{x},First[Sort[{x}]]][[1,1]]];
cyclic[] :=
	{};

(* ************************************************************** *)
(* fr567def, frlivcdef : two special FreeQ - checking functions *)
	fr567[x__] :=
		True /; FreeQ2[FixedPoint[ReleaseHold, {x}],{DiracGamma[5],DiracGamma[6],DiracGamma[7]}];

(* Properties and special cases of traces (up to a factor 4) *)
tris[x___] :=
	tris[x] = trI[x];

trI[a_Plus] :=
	Map[tris, a];
trI[] =
	1;
trI[ DiracGamma[5] ] =
	0;
trI[ DiracGamma[6] ] =
	1/2;
trI[ DiracGamma[7] ] =
	1/2;

trI[ a:DiracGamma[_[__]].. ,DiracGamma[n_] ] :=
	0 /;(OddQ[Length[{a}]]&&(n==5 || n==6 || n==7));

trI[ a:DiracGamma[_[__],___].. ,DiracGamma[n_] ] :=
	0 /;(OddQ[Length[{a}]]&&(n==5 || n==6 || n==7)) && ($BreitMaison === False);

trI[ d:DiracGamma[__].. ] :=
	0/;(OddQ[Length[{d}]] && fr567[ d ]);

trI[ d:DiracGamma[_[__],___].. ,DiracGamma[5] ] :=
	0/;Length[{d}]<4;

trI[x_] :=
	x /; FreeQ[ {x},DiracGamma ];

trI[ DiracGamma[a_[b__],___],DiracGamma[c_[d__],___], DiracGamma[6] ] :=
	1/2 ExpandScalarProduct[ a[b],c[d] ];

trI[ DiracGamma[a_[b__],___],DiracGamma[c_[d__],___], DiracGamma[7] ] :=
	1/2 ExpandScalarProduct[ a[b],c[d] ];

trI[ x__] :=
	spursav[x]/;
	( Length[{x}] < 11 && fr567[x]) || ( Length[{x}] <  6 && (!fr567[x]));
*)
(* #################################################################### *)


(* SpinorChainEvaluatedef *)

(* #################################################################### *)
(*                             Main43                                   *)
(* #################################################################### *)



(*


		(*	Sirlin relations	*)
		If[	!FreeQ[tmp,Spinor] && optSirlinRelations,
			tmp = SirlinRelations[tmp, FCI->True]
		];



*)

diracSimplifySpinors[expr_]:=
	Block[{tmp},
		tmp = expr;

		tmp

	];


SirlinRelations[expr_, OptionsPattern[]]:=
	expr;


SpinorChainEvaluate[y_, OptionsPattern[]] :=
	y /; FreeQ[y,Spinor];

SpinorChainEvaluate[z_Plus,opts:OptionsPattern[]] :=
	Block[ {nz,useSirlin},
		useSirlin = OptionValue[DiracSimplify,{opts},SirlinRelations];
		FCPrint[3,"DiracSimplify: SpinorChainEvaluate: Entering with ", z, FCDoControl->dsVerbose];
		nz = DotSimplify[z];
		If[ Length[nz]>20,
			nz = Collect2[ nz, Spinor,Factoring -> False]
		];
		If[ Head[nz]=!=Plus,
			nz = SpinorChainEvaluate[nz,opts],
			If[ !useSirlin,
				nz = Map[ spcev0, nz ],
				If[ FreeQ[nz, DOT[Spinor[p1__], (a__ /; FreeQ[{a}, DiracGamma[_,_]]),
					Spinor[p2__]] DOT[Spinor[p3__],
					(b__ /; FreeQ[{b}, DiracGamma[_,_]]) , Spinor[p4__]]],
					nz = Map[ spcev0,nz ],
					(* added ,Spinor, Nov. 2003 , RM*)
					nz = sirlin00[ Expand[Map[ spcev0,z//sirlin0 ], Spinor] ]
				]
			]
		];
		FCPrint[3,"DiracSimplify: SpinorChainEvaluate: Leaving with ", nz, FCDoControl->dsVerbose];
		nz
	];

SpinorChainEvaluate[x_,opts:OptionsPattern[]] :=
	Block[ {nz,useSirlin},
		useSirlin = OptionValue[DiracSimplify,{opts},SirlinRelations];
		FCPrint[3,"DiracSimplify: SpinorChainEvaluate: Entering with ", x, FCDoControl->dsVerbose];
		If[ !useSirlin,
			nz = Expand[spcev0[x],
				Spinor
			],
			If[ FreeQ[x//DotSimplify,
				DOT[Spinor[p1__], (a__ /; FreeQ[{a}, DiracGamma[_,_]]),
				Spinor[p2__]] DOT[Spinor[p3__] ,
				(b__ /; FreeQ[{b}, DiracGamma[_,_]]) , Spinor[p4__]]],
				(* added ,Spinor, Nov. 2003 , RM*)
				nz = Expand[spcev0[x], Spinor],
				nz = sirlin00[ Expand[FixedPoint[spcev0, x//sirlin0, 3 ], Spinor]];
			]
		];
		FCPrint[3,"DiracSimplify: SpinorChainEvaluate: Leaving with ", FullForm[nz], FCDoControl->dsVerbose];
		nz
	]/; !Head[x]===Plus && Head[x]=!=List;
(* #################################################################### *)
(*                             Main45                                   *)
(* #################################################################### *)

(*
dIex[ a___,x_ + y_, b___] :=
	dS[a,x,b] + dS[a,y,b];

dix[y_] :=
	y/.DOT->dIex/.dIex->dS;

(* This is the tricky function which does the expansion of the dr's *)
fEx[z_] :=
	FixedPoint[ dix, z/.DOT -> dS ];

spinlin[x_Plus] :=
	spinlin/@x;
spinlin[a_] :=
	((a/.DOT->ddot)//.{
		ddot[x___,z_ b__,c___] :> z ddot[x,b,c]/;NonCommFreeQ[z]===True,
		ddot[x___,z_ ,c___]    :> z ddot[x,c]/;NonCommFreeQ[z]===True,
		ddot[x_Spinor,b___,c_Spinor,d_Spinor,e___,f_Spinor,g___]:> ddot[x,b,c] ddot[d,e,f,g]
	})/.ddot[]->1/.ddot->DOT;

spcev0[x_] :=
	spcev000[x]/.spcev000->spcev0ev;

spcev000[y_] :=
	y /; NonCommFreeQ[y] === True;
spcev000[y_Times] :=
	Select[y, FreeQ[#, Spinor]& ] spcev0ev[Select[y,!FreeQ[#, Spinor]&]];

spcev0ev[x_] :=
	ExpandScalarProduct[Contract[Expand[spinlin[x](*, Spinor*)]/.DOT->spcevs/.
	spcev->DOT, Expanding->False]](*//Expand*);

spcevs[xx___] :=
	MemSet[ spcevs[xx], FixedPoint[ spcev,{xx},4 ] ];
(*spcevsdef*)

(*spcevdef*)
spcev[y_List] :=
	spcev@@y;

spcev[a___,b_ /; FCPatternFreeQ[{b}],c___] :=
	b spcev[a,c] /; NonCommFreeQ[b] === True;

(*added to allow nested structures like phi.(gamm1.gamm2+gamma3.gamma4).phi
F.Orellana, 26/9-2002*)

spcev[a__] :=
	DOT[a] /; FreeQ[{a}, Spinor];
(**)
spcev[] =
	1;

spcev[x___,Spinor[a__],y___] :=
	Expand[ DiracOrder[ DiracEquation[fEx[DiracGammaExpand[
	DOT[x,Spinor[a],y]]](*/.dR->DOT*)]]]/; FreeQ[{x,y},Spinor];

spcev[x___,Spinor[a__],b___,Spinor[c__],y___] :=
	Block[ {spcevdi,spcevre,spcevj},
		FCPrint[2,"entering spcev with ", InputForm[DOT@@{x,Spinor[a],b,Spinor[c],y}]];
		spcevdi = diracSimplify[DOT[Spinor[a],b,Spinor[c]],    InsideDiracTrace->False,
			DiracCanonical->False, Factoring->False, DiracSimpCombine->True];
		spcevdi = Expand[ExpandScalarProduct[spcevdi]];
		spcevdi = Expand[spcevdi];
		If[ !(Head[spcevdi]===Plus),
			spcevre = spinlin[ spcevdi ];
			spcevre = DiracEquation[ spcevre ];,
			spcevre = Sum[DiracEquation[ spinlin[ spcevdi[[spcevj]] ] ],
							{spcevj,1,Length[spcevdi]}];
		];
		spcevre = DotSimplify[DOT[spcevs[x],spcevre,spcevs[y]]];
		If[ !FreeQ[spcevre, SUNT],
			spcevre = (spcevre/.DOT->dS)
		];
		spcevre = spcevre//DotSimplify;
		FCPrint[2,"exiting spcev with ",InputForm[spcevre]];
		spcevre
	] /; FreeQ[{b}, Spinor];
*)


(*
Always (also for NO SIRLIN): spcev0
Then sirlin0 and sirlin00

Simplifications:

DiracEquation (+ clever splitting), DiracOrder, DiracGammaExpand

sirlin0 -> usual sirlin
ChisholmSpinor -> try harder


*)

(* Reference of Sirlin-relations: Nuclear Physics B192 (1981) 93-99;
	Note that we take another sign in front of the Levi-Civita tensor
	in eq. (7), since we take (implicitly) \varepsilon^{0123} = 1
*)

(* #################################################################### *)
(*                             Main441                                  *)
(* #################################################################### *)

$SpinorMinimal = False;

sirlin00[x_] :=
	x/;$SpinorMinimal === False;

sirlin00[x_] :=
	MemSet[sirlin00[x],
		Block[ {te, tg5, ntg5, test},
			FCPrint[3,"sirlin001"];
			(* te = sirlin0[x]//ExpandAll; *)
			te = sirlin0[x]//Expand;
			FCPrint[3,"sirlin002"];
			If[ FreeQ2[te,{DiracGamma[6],DiracGamma[7]}]&&
				Head[te]===Plus && !FreeQ[te,DiracGamma[5]],
				tg5 = Select[te, !FreeQ[#,DiracGamma[5]]& ];
				ntg5 = te - tg5;
				(*i.e. te = tg5 + ntg5 *)
				test = Expand[tg5 + ChisholmSpinor[ntg5], Spinor];
				If[ nterms[test] < Length[te],
					te = test
				]
			];
			FCPrint[3,"exiting sirlin00"];
			te
		]
	]/; $SpinorMinimal ===  True;

ChisholmSpinor[x_, choice_:0] :=
	MemSet[ChisholmSpinor[x,choice],
		Block[ {new = x},
			FCPrint[3,"entering ChisholmSpinor "];
			new = DotSimplify[new];
			If[ choice===1,
				new = new/.{ DOT[Spinor[a__],b__ ,Spinor[c__]] DOT[Spinor[d__],e__ ,Spinor[f__]]:>
					DOT[nospinor[a],b,nospinor[c]] DOT[Spinor[d],e,Spinor[f]]}
			];

			If[ choice===2,
				new = new/.{ DOT[Spinor[a__],b__ ,Spinor[c__]] DOT[Spinor[d__],e__ ,Spinor[f__]]:>
					DOT[Spinor[a],b,Spinor[c]] DOT[nospinor[d],e,nospinor[f]]}
			];

			dsimp[Contract[dsimp[new/.{(DOT[Spinor[pe1_, m_, ql___], DiracGamma[lv_[k_]] , h___ , Spinor[pe2_, m2_, ql___]]) :>
					Block[ {indi},
						indi = Unique["alpha"];
						-1/Pair[pe1,pe2] ( DOT[Spinor[pe1, m, ql], DiracGamma[pe1], DiracGamma[lv[k]] , DiracGamma[pe2],h, Spinor[pe2, m2, ql]] -
						Pair[pe1,lv[k]] DOT[Spinor[pe1, m, ql], DiracGamma[pe2], h , Spinor[pe2, m2, ql]] -
						Pair[lv[k],pe2] DOT[Spinor[pe1, m, ql], DiracGamma[pe1] , h , Spinor[pe2, m2, ql]]-
							I Eps[pe1,lv[k],pe2,LorentzIndex[indi]] DOT[Spinor[pe1, m, ql], DiracGamma[LorentzIndex[indi]], DiracGamma[5],h, Spinor[pe2, m2, ql]]
						)
					]}/.nospinor->Spinor], EpsContract->True]
			]
		]
	];


ident3[a_,_] :=
	a;

(* #################################################################### *)
(*                             Main442                                  *)
(* #################################################################### *)
(* canonize different dummy indices *)  (*sirlin3def*)
sirlin3a[x_] :=
	((sirlin3[Expand[Contract[x](*,Spinor*)]/.
	$MU->dum$y]/.dum$y->$MU)/.  sirlin3 -> Identity)//Contract;

sirlin3[a_Plus] :=
	sirlin3 /@ a;

sirlin3[ m_. DOT[Spinor[p1__] , (ga1___) , DiracGamma[ LorentzIndex[la_] ] , (ga2___),
Spinor[p2__]] DOT[Spinor[p3__], (ga3___) , DiracGamma[ LorentzIndex[la_] ], (ga4___),
Spinor[p4__]]] :=
	Block[ {counter},
		counter = 1;
		While[!FreeQ2[{m,ga1,ga2,ga3,ga4}, {$MU[counter], dum$y[counter]}],
			counter = counter + 1
		];
		sirlin3[m DOT[Spinor[p1], ga1, DiracGamma[ LorentzIndex[$MU[counter]]],
		ga2,  Spinor[p2]] DOT[Spinor[p3] , ga3 ,  DiracGamma[ LorentzIndex[$MU[counter]]],
		ga4, Spinor[p4]]]
	]/; FreeQ[la, $MU];

sirlin3[ m_. DOT[Spinor[p1__],(ga1___), DiracGamma[ LorentzIndex[la_,di_],di_ ], (ga2___),
Spinor[p2__]] DOT[Spinor[p3__],(ga3___), DiracGamma[ LorentzIndex[la_,di_],di_ ], (ga4___),
Spinor[p4__]]] :=
	(m DOT[Spinor[p1], ga1,    DiracGamma[ LorentzIndex[$MU[1], di],di ], ga2,
	Spinor[p2]] DOT[Spinor[p3], ga3, DiracGamma[LorentzIndex[$MU[1], di], di], ga4,
	Spinor[p4]])/; FreeQ2[{ga1,ga2,ga3,ga4}, DiracGamma[_,_]];


(* #################################################################### *)
(*                             Main443                                  *)
(* #################################################################### *)

(* The Sirlin - identities are only valid in 4 dimensions and are
only needed, if Dirac matrices are around
*)
sirlin0[x_] :=
	If[ FreeQ2[x, {LorentzIndex, Momentum}],
		x,
		If[ FreeQ[x, Spinor],
			x,
			If[ !FreeQ[x, DiracGamma[_,_]],
				sirlin3[x]/.sirlin3->Identity,
				sirlin0doit[(x//sirlin2)/.sirlin2->Identity]
			]
		]
	];

$sirlintime = 242;

SetAttributes[timeconstrained, HoldAll];

If[ $OperatingSystem === "Unix",
	timeconstrained[x__] :=
		TimeConstrained[x],
	timeconstrained[x_,__] :=
		x
];

sirlin0doit[a_Plus] :=
	timeconstrained[sirlin3a[Contract[
		(Expand[Map[sirlin1, a](*, DOT*)]/.
		sirlin1->sirlin2) /.
		sirlin2 -> sirlin1/.sirlin1->sirlin2/.
		sirlin2 -> Identity,EpsContract->True]] // spcev0,
		2 $sirlintime, a];

sirlin0doit[a_] :=
	timeconstrained[(sirlin3a[sirlin1[a]/.sirlin1->sirlin2/.
	sirlin2 -> Identity] // spcev0), $sirlintime, a] /;Head[a]=!=Plus;

sirlin2[a_Plus] :=
	sirlin2/@a;


sirlin2[m_. DOT[Spinor[pa__], DiracGamma[Momentum[pj_]], DiracGamma[Momentum[pi_]], DiracGamma[LorentzIndex[mu_]], (vg5___), Spinor[pb__]] *
			DOT[Spinor[Momentum[pi_],0,qf___], DiracGamma[LorentzIndex[mu_]], (vg5___), Spinor[Momentum[pj_],0,qf___]]
	] :=
	(-sirlin2[m DOT[Spinor[pa] , DiracSlash[pi,pj], DiracMatrix[mu], vg5 , Spinor[pb]] *
				DOT[Spinor[Momentum[pi],0,qf], DiracMatrix[mu], vg5 , Spinor[Momentum[pj],0,qf]]] +

				2 m ExpandScalarProduct[Momentum[pi],Momentum[pj]] *
				DOT[Spinor[pa], DiracMatrix[mu], vg5, Spinor[pb]] *
				DOT[Spinor[Momentum[pi],0,qf], DiracMatrix[mu], vg5, Spinor[Momentum[pj],0,qf]])/;
				({vg5}==={}) || ({vg5}==={DiracGamma[5]});

sirlin22[m_. DOT[Spinor[pa__], DiracGamma[Momentum[pj_]], DiracGamma[Momentum[pi_]], DiracGamma[LorentzIndex[mu_]], (vg5___), Spinor[pb__]] *
			DOT[Spinor[Momentum[pi_],0,qf___], DiracGamma[LorentzIndex[mu_]], (vg5___), Spinor[Momentum[pj_],0,qf___]]] :=
	(-sirlin2[m DOT[Spinor[pa], DiracSlash[pi,pj], DiracMatrix[mu], vg5, Spinor[pb]] *
				DOT[Spinor[Momentum[pi],0,qf], DiracMatrix[mu], vg5, Spinor[Momentum[pj],0,qf]]] +
				2 m ExpandScalarProduct[Momentum[pi],Momentum[pj]] *
				DOT[Spinor[pa], DiracMatrix[mu] , vg5, Spinor[pb]] *
				DOT[Spinor[Momentum[pi],0,qf], DiracMatrix[mu], vg5, Spinor[Momentum[pj],0,qf]])/; ({vg5}==={}) || ({vg5}==={DiracGamma[5]});


sirlin2[m_. DOT[ Spinor[pa__], DiracGamma[Momentum[pi_]], DiracGamma[Momentum[pj_]], DiracGamma[LorentzIndex[mu_]], (vg5___), Spinor[pb__]] *
			DOT[Spinor[Momentum[pi_],0,qf___], DiracGamma[LorentzIndex[mu_]], (vg5___), Spinor[Momentum[pj_],0,qf___]]] :=
	(m ExpandScalarProduct[Momentum[pi], Momentum[pj]] *
	DOT[ Spinor[pa], DiracMatrix[$MU[1]], Spinor[pb]] DOT[ Spinor[Momentum[pi],0,qf], DiracMatrix[$MU[1]], Spinor[Momentum[pj],0,qf]] +
	m ExpandScalarProduct[Momentum[pi], Momentum[pj]] DOT[ Spinor[pa], DiracMatrix[$MU[1]], DiracGamma[5], Spinor[pb]] *
	DOT[ Spinor[Momentum[pi],0,qf], DiracMatrix[$MU[1]], DiracGamma[5], Spinor[Momentum[pj],0,qf]]) /; ({vg5}==={}) || ({vg5}==={DiracGamma[5]});


sirlin2[m_. DOT[ Spinor[p1__], (ga1___), DiracGamma[ LorentzIndex[la_] ], DiracGamma[ LorentzIndex[nu_] ], DiracGamma[6], Spinor[p2__]] *
			DOT[ Spinor[p3__], (ga2___), DiracGamma[ LorentzIndex[la_] ], DiracGamma[ LorentzIndex[nu_] ], DiracGamma[7], Spinor[p4__]]] :=
	(m 4 DOT[Spinor[p1] , ga1 , DiracGamma[6] , Spinor[p2] Spinor[p3] , ga2 , DiracGamma[7] , Spinor[p4]]);

sirlin2[m_. DOT[ Spinor[p1__], (ga1___) , DiracGamma[ LorentzIndex[la_] ], DiracGamma[ LorentzIndex[nu_] ], DiracGamma[7] , Spinor[p2__]] *
			DOT[ Spinor[p3__], (ga2___) , DiracGamma[ LorentzIndex[la_] ], DiracGamma[ LorentzIndex[nu_] ], DiracGamma[6], Spinor[p4__]]] :=
	(m 4 DOT[Spinor[p1] , ga1 , DiracGamma[7] , Spinor[p2] Spinor[p3] , ga2 , DiracGamma[6] , Spinor[p4]] );
(* #################################################################### *)
(*                             Main444                                  *)
(* #################################################################### *)


(* eq. (8) *)
sirlin2[m_. DOT[Spinor[p1__], (ga1___) , DiracGamma[ LorentzIndex[mu_] ], DiracGamma[ lv_[rho_] ], DiracGamma[ LorentzIndex[nu_] ], (ga2___) , Spinor[p2__]] *
			DOT[Spinor[p3__], (ga3___) , DiracGamma[ LorentzIndex[mu_] ], DiracGamma[ lvt_[tau_] ], DiracGamma[ LorentzIndex[nu_] ], (ga4___), Spinor[p4__]]] :=
	Block[ {ii = 1, ind, la, grho, gtau, gam5},
		While[!FreeQ[{ga1,rho,ga2,ga3,tau,ga4},
			$MU[ii]],
			ii++
		];
		la = DiracGamma[LorentzIndex[$MU[ii]]];
		grho = DiracGamma[lv[rho]];
		gtau = DiracGamma[lvt[tau]];
		gam5 = DiracGamma[5];
		Contract[
			2 m Pair[lv[rho], lvt[tau]] DOT[Spinor[p1] , ga1 , la , ga2 ,   Spinor[p2]] DOT[Spinor[p3] , ga3 , la , ga4 ,   Spinor[p4]] +
			2 m DOT[Spinor[p1] , ga1 , gtau , ga2 , Spinor[p2]] DOT[Spinor[p3] , ga3 , grho , ga4 ,   Spinor[p4]] +
			2 m Pair[lv[rho], lvt[tau]] DOT[Spinor[p1] , ga1 , la , ga2 , gam5 , Spinor[p2]] DOT[Spinor[p3] , ga3 , la , ga4 , gam5 , Spinor[p4]] -
			2 m DOT[Spinor[p1] , ga1 , gtau , ga2 , gam5 , Spinor[p2]] DOT[Spinor[p3] , ga3 , grho , ga4 , gam5 , Spinor[p4]]
		]
	];

(* eq. (12) of Sirlin *)

sirlin2[m_. DOT[Spinor[p1__], DiracGamma[LorentzIndex[mu_]], DiracGamma[lv_[rho_]], DiracGamma[LorentzIndex[sigma_]], DiracGamma[lvt_[tau_]], DiracGamma[LorentzIndex[nu_]],
				om_ , Spinor[p2__]] *
			DOT[Spinor[p3__], DiracGamma[LorentzIndex[mu_]], DiracGamma[lva_[alpha_] ], DiracGamma[LorentzIndex[sigma_]], DiracGamma[lvb_[beta_]], DiracGamma[ LorentzIndex[nu_]],
				om_ , Spinor[p4__]]] :=
	Contract[ m 16 Pair[lvt[tau],lvb[beta]] Pair[lv[rho], lva[alpha]] *
		DOT[ Spinor[p1], DiracMatrix[mu], om, Spinor[p2]] *
		DOT[ Spinor[p3], DiracMatrix[mu], om , Spinor[p4]]]/; (om===DiracGamma[6]) || (om===DiracGamma[7]);

(* eq. (13) of Sirlin *)
sirlin2[m_. DOT[Spinor[p1__], DiracGamma[LorentzIndex[mu_]], DiracGamma[lv_[rho_] ], DiracGamma[LorentzIndex[sigma_]], DiracGamma[lvt_[tau_]], DiracGamma[LorentzIndex[nu_]], om1_ , Spinor[p2__]] *
			DOT[Spinor[p3__], DiracGamma[LorentzIndex[mu_]], DiracGamma[lva_[alpha_] ], DiracGamma[LorentzIndex[sigma_]], DiracGamma[lvb_[beta_] ], DiracGamma[LorentzIndex[nu_]], om2_ , Spinor[p4__]]] :=
	(m 4 DOT[Spinor[p1], DiracMatrix[mu], DiracGamma[lv[rho]], DiracGamma[lvb[beta]], om1, Spinor[p2]] *
		DOT[Spinor[p3], DiracMatrix[mu], DiracGamma[lva[alpha]], DiracGamma[lvt[tau]], om2, Spinor[p4]]) /; ( (om1===DiracGamma[6])&& (om2===DiracGamma[7]) )|| ((om1===DiracGamma[7])&& (om2===DiracGamma[6]));


(* #################################################################### *)
(*                             Main445                                  *)
(* #################################################################### *)


(* in case if no chiral projectors are present: *)
sirlin2[m_. DOT[Spinor[p1__], DiracGamma[LorentzIndex[mu_]], DiracGamma[lv_[rho_] ], DiracGamma[LorentzIndex[sigma_]], DiracGamma[lvt_[tau_] ], DiracGamma[LorentzIndex[nu_]], Spinor[p2__]] *
			DOT[Spinor[p3__], DiracGamma[ LorentzIndex[mu_] ], DiracGamma[ lva_[alpha_] ], DiracGamma[ LorentzIndex[sigma_] ], DiracGamma[ lvb_[beta_] ], DiracGamma[ LorentzIndex[nu_] ], Spinor[p4__]]] :=
	Block[ {tmp,re},
		tmp[ome1_,ome2_] :=
			sirlin2[m DOT[Spinor[p1], DiracMatrix[mu], DiracGamma[lv[rho]], DiracMatrix[sigma], DiracGamma[lvt[tau]], DiracMatrix[nu], DiracGamma[ome1], Spinor[p2]] *
					DOT[Spinor[p3], DiracMatrix[mu], DiracGamma[lva[alpha]], DiracMatrix[sigma], DiracGamma[lvb[beta]], DiracMatrix[nu], DiracGamma[ome2], Spinor[p4]]];
		re = tmp[6,6] + tmp[6,7] + tmp[7,6] + tmp[7,7];
		re
	];

(* #################################################################### *)
(*                             Main446                                  *)
(* #################################################################### *)

(* These are the ones calculated by FeynCalc  *)

sirlin2[m_. DOT[Spinor[pi__], x1___ , DiracGamma[ LorentzIndex[mu_] ], DiracGamma[ LorentzIndex[nu_] ], x2___ , Spinor[pj__]] *
			DOT[Spinor[pk__], x3___ , DiracGamma[ vm_[a_] ], DiracGamma[ LorentzIndex[mu_]], DiracGamma[ LorentzIndex[nu_] ], x4___, Spinor[pl__]]] :=
	Contract[ m (2 DOT[Spinor[pi], x1, x2, Spinor[pj] ] DOT[Spinor[pk], x3, DiracGamma[vm[a]], x4, Spinor[pl]] +
				2 DOT[Spinor[pk], x3, DiracGamma[LorentzIndex[al$mu]], x4, Spinor[pl]] DOT[Spinor[pi], x1, DiracGamma[vm[a]], DiracGamma[LorentzIndex[al$mu]], x2, Spinor[pj]] -
				2 DOT[Spinor[pi], x1, DiracGamma[5], x2, Spinor[pj]] DOT[Spinor[pk], x3, DiracGamma[vm[a]], DiracGamma[5], x4, Spinor[pl]] +
				2 DOT[Spinor[pk], x3, DiracGamma[LorentzIndex[al$mu]] , DiracGamma[5], x4, Spinor[pl]]*
					DOT[Spinor[pi], x1, DiracGamma[vm[a]], DiracGamma[LorentzIndex[al$mu]], DiracGamma[5], x2, Spinor[pj]])
	];

sirlin2[m_. DOT[Spinor[Momentum[pi_], 0, fq___] , DiracGamma[Momentum[pk_]], Spinor[Momentum[pj_], 0, fq___]]*
			DOT[Spinor[Momentum[pl_], 0, fq___] , DiracGamma[Momentum[pj_]], Spinor[Momentum[pk_], 0, fq___]]] :=
	Contract[m (-(( DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[Momentum[pl]], Spinor[Momentum[pj], 0, fq]]*
					DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[Momentum[pi]],    Spinor[Momentum[pk], 0, fq]]*
					Pair[Momentum[pj], Momentum[pk]])/Pair[Momentum[pi], Momentum[pl]]) +

				(
				DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5] , Spinor[Momentum[pj], 0, fq]]*
				DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5] , Spinor[Momentum[pk], 0, fq]]*
					(-(Pair[Momentum[pi], Momentum[pl]]*Pair[Momentum[pj], Momentum[pk]]) +    Pair[Momentum[pi], Momentum[pk]]*
					Pair[Momentum[pj], Momentum[pl]] - Pair[Momentum[pi], Momentum[pj]]*Pair[Momentum[pk], Momentum[pl]])
				)/(2 Pair[Momentum[pi], Momentum[pl]]) +

				(
				DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], Spinor[Momentum[pj], 0, fq]]*
				DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]],    Spinor[Momentum[pk], 0, fq]]*
				(3 Pair[Momentum[pi], Momentum[pl]] Pair[Momentum[pj], Momentum[pk]] + Pair[Momentum[pi], Momentum[pk]]*
				Pair[Momentum[pj], Momentum[pl]] - Pair[Momentum[pi], Momentum[pj]]*Pair[Momentum[pk], Momentum[pl]])
				)/(2 Pair[Momentum[pi], Momentum[pl]])
				)
	];

sirlin2[m_. DOT[Spinor[Momentum[pi_], 0, fq___] , DiracGamma[Momentum[pk_]], Spinor[Momentum[pj_], 0, fq___]]*
			DOT[Spinor[Momentum[pl_], 0, fq___] , DiracGamma[Momentum[pi_]], Spinor[Momentum[pk_], 0, fq___]]] :=
	Contract[m (-(( DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[Momentum[pl]], Spinor[Momentum[pj], 0, fq]]*
					DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[Momentum[pj]], Spinor[Momentum[pk], 0, fq]]*
					Pair[Momentum[pi], Momentum[pk]])/ Pair[Momentum[pj], Momentum[pl]]) +

				(
				DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], Spinor[Momentum[pj], 0, fq]]*
				DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]], Spinor[Momentum[pk], 0, fq]]*
				(Pair[Momentum[pi], Momentum[pl]] Pair[Momentum[pj], Momentum[pk]] + 3 Pair[Momentum[pi], Momentum[pk]]*
				Pair[Momentum[pj], Momentum[pl]] - Pair[Momentum[pi], Momentum[pj]]*Pair[Momentum[pk], Momentum[pl]])
				)/(2 Pair[Momentum[pj], Momentum[pl]]) +

				(
				DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5], Spinor[Momentum[pj], 0, fq]]*
				DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5] , Spinor[Momentum[pk], 0, fq]]*
				(-(Pair[Momentum[pi], Momentum[pl]] Pair[Momentum[pj], Momentum[pk]]) +
				Pair[Momentum[pi], Momentum[pk]]*Pair[Momentum[pj], Momentum[pl]] + Pair[Momentum[pi], Momentum[pj]]*
				Pair[Momentum[pk], Momentum[pl]]))/(2*Pair[Momentum[pj], Momentum[pl]]))] /;
					First[DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[Momentum[pk]], Spinor[Momentum[pj], 0, fq]]*
					DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[Momentum[pi]] , Spinor[Momentum[pk], 0, fq]]]===
					DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[Momentum[pk]], Spinor[Momentum[pj], 0, fq]];

sirlin2[ m_. DOT[Spinor[Momentum[pi_], 0, fq___] , DiracGamma[Momentum[pk_]], DiracGamma[5], Spinor[Momentum[pj_], 0, fq___]]*
			DOT[Spinor[Momentum[pl_], 0, fq___] , DiracGamma[Momentum[pj_]], DiracGamma[5],    Spinor[Momentum[pk_], 0, fq___]]] :=
	Contract[ m(DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[Momentum[pk]], Spinor[Momentum[pj], 0, fq]]*
				DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[Momentum[pj]], Spinor[Momentum[pk], 0, fq]] -

				DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], Spinor[Momentum[pj], 0, fq]]*
				DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]], Spinor[Momentum[pk], 0, fq]] Pair[Momentum[pj], Momentum[pk]] +

				DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5], Spinor[Momentum[pj], 0, fq]]*
				DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5], Spinor[Momentum[pk], 0, fq]] Pair[Momentum[pj], Momentum[pk]])
	];

sirlin2[m_. DOT[Spinor[Momentum[pi_], 0, fq___] , DiracGamma[Momentum[pk_]], DiracGamma[5], Spinor[Momentum[pj_], 0, fq___]]*
			DOT[Spinor[Momentum[pl_], 0,fq___], DiracGamma[Momentum[pi_]], DiracGamma[5], Spinor[Momentum[pk_], 0, fq___]]] :=
	Contract[ m (-( DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[Momentum[pk]],    Spinor[Momentum[pj], 0, fq]]*
					DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[Momentum[pi]], Spinor[Momentum[pk], 0, fq]]) +

					DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], Spinor[Momentum[pj], 0, fq]]*
					DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]], Spinor[Momentum[pk], 0, fq]] Pair[Momentum[pi], Momentum[pk]] +

					DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5] , Spinor[Momentum[pj], 0, fq]]*
					DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5] , Spinor[Momentum[pk], 0, fq]] Pair[Momentum[pi], Momentum[pk]])
	];

sirlin2[m_. DOT[Spinor[Momentum[pi_], 0, fq___], DiracGamma[Momentum[pl_]], DiracGamma[5], Spinor[Momentum[pj_], 0, fq___]]*
			DOT[Spinor[Momentum[pl_], 0, fq___] , DiracGamma[Momentum[pj_]], DiracGamma[5], Spinor[Momentum[pk_], 0, fq___]]] :=
	Contract[ m (-(
		DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[Momentum[pl]], Spinor[Momentum[pj], 0, fq]]*
		DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[Momentum[pj]], Spinor[Momentum[pk], 0, fq]]) +

		DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]],    Spinor[Momentum[pj], 0, fq]]*
		DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]],    Spinor[Momentum[pk], 0, fq]] Pair[Momentum[pj], Momentum[pl]] +
		DOT[Spinor[Momentum[pi], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5] , Spinor[Momentum[pj], 0, fq]]*
		DOT[Spinor[Momentum[pl], 0, fq] , DiracGamma[LorentzIndex[la]], DiracGamma[5] , Spinor[Momentum[pk], 0, fq]]* Pair[Momentum[pj], Momentum[pl]])
	];

(* #################################################################### *)
(*                             Main447                                  *)
(* #################################################################### *)

dig[LorentzIndex[a_,___]] :=
	a;

dig[Momentum[a_,___]] :=
	a;

dig[x_] :=
	x/;(Head[x]=!=LorentzIndex)&&(Head[x]=!=Momentum);

dig[_?NumberQ] :=
	{};

getV[x_List] :=
	Select[Flatten[{x}/.DOT->List]/.DiracGamma -> dige, Head[#]===dige&]/.dige->dig;

(* Get a list of equal gamma matrices *)
schnitt[x___][y___] :=
	Intersection[
		Select[Flatten[{x}/.DOT->List],!FreeQ[#,LorentzIndex]&],
		Select[Flatten[{y}/.DOT->List],!FreeQ[#,LorentzIndex]&]
	];

(* get a list of not equal slashes and matrices *)
comp[x___][y___] :=
	Select[Complement[Flatten[Union[{x},{y}]/.DOT->List],
	schnitt[x][y] ],
	!FreeQ2[#, {LorentzIndex, Momentum}]&];

(* sirlin1def *)
(* do some ordering with sirlin1 ... *)
sirlin1[m_. DOT[Spinor[p1__], (gam1__) , Spinor[p2__]] DOT[Spinor[p3__], (gam2__) , Spinor[p4__]]] :=
	MemSet[sirlin1[m DOT[Spinor[p1],gam1,Spinor[p2]] DOT[Spinor[p3],gam2,Spinor[p4]]],
		Block[ {schnittmenge, compmenge, result,order, orderl,orderr, leftind, rightind},
			schnittmenge = schnitt[gam1][gam2];
			compmenge   = comp[gam1][gam2];
			leftind    = comp[gam1][schnittmenge];
			rightind   = comp[gam2][schnittmenge];
			FCPrint[3,"entering sirlin1"];
			(* We need at least two dummy indices for the sirlin relations *)
			If[ Length[schnittmenge] > 1,
				(* Test for eq. (12) *)
				If[ (Length[schnittmenge] === 3) && (Length[compmenge] > 3),
					orderl = Join[ Drop[leftind, {1,2}], {schnittmenge[[1]], leftind[[1]], schnittmenge[[2]], leftind[[2]], schnittmenge[[3]]}] // getV;
					orderr = Join[ Drop[rightind, {1,2}], {schnittmenge[[1]], rightind[[1]], schnittmenge[[2]], rightind[[2]], schnittmenge[[3]]}] // getV;
					result =
						Expand[m Contract[DiracOrder[ DOT[Spinor[p1],gam1,Spinor[p2]], orderl ]* DiracOrder[ DOT[Spinor[p3],gam2,Spinor[p4]], orderr ]]]//sirlin2
				];

			(* ... *)
			(* Test for eq. (8) *)
				If[ (Length[schnittmenge] === 2) && (Length[compmenge] > 1),
					order = Join[{First[schnittmenge]}, compmenge,
					{Last[schnittmenge]} ] // getV;
					result = sirlin2[ Expand[ m  DiracOrder[DOT[Spinor[p1],gam1,Spinor[p2]] DOT[Spinor[p3],gam2,Spinor[p4]], order]]//Contract]
				];
			];
			If[ !ValueQ[result],
				result = sirlin2[m DOT[Spinor[p1],gam1,Spinor[p2]] DOT[Spinor[p3],gam2,Spinor[p4]]]
			];
			FCPrint[3,"exiting sirlin1"];
			result
		]
	] /; !FreeQ[{gam1}, LorentzIndex];


(*ChisholmSpinordef*)
dsimp[x_] :=
	sirlin0[spcev0[x]];



FCPrint[1,"DiracSimplify.m loaded."];
End[]
