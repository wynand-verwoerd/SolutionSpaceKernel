#!/usr/bin/env wolframscript
(* ::Package:: *)

workdir=If[$InputFileName=="",NotebookDirectory[],DirectoryName@$InputFileName];
Print["Working directory is ",workdir]

SetDirectory[workdir<>"\\Packages"];
Get["Configuration`"]
Get["ModelProcessing`"]
Get["Centering`"]
Get["RedundancyRemoval`"]
Get["FixedFluxes`"]
Get["RayFinding`"]
Get["FacetTesting`"]
Get["FBFsearch`"]
Get["Capping`"]
ResetDirectory[];
PackagesDirectory=workdir<>"\\Packages";

datafile=First@FileNames["*.mat"|"*.m", workdir<>"TEST"];
commandline=True; loadreset=False;  verbose=False; Species="";
(*Print["There are "<>ToString@Length@$ScriptCommandLine<>" script arguments."];*) 
If[Length[$ScriptCommandLine]>=2, 
	datafile=DataDirectory<>$ScriptCommandLine[[2]];
	(*Print[">",datafile,"<"]*)];
If[Length[$ScriptCommandLine]==3, 
	commandstring=StringReplace[$ScriptCommandLine[[3]],"'" -> "\""];
	commands=ToExpression[commandstring];
	Print["A total of "<>ToString@Length[commands]<>
	" parameter values are adjusted by the command line."];
	Print[commandstring];
];
If[!StringQ[datafile]||StringLength[datafile]==0,
	Print["The file path is empty! If you use SSKernelbatch.bat, drag an input file to it."];
	Input["Press x and <Enter> to exit"];Exit[]]
If[FileExistsQ[datafile], Print["I found the data file, allright!"],
Print["No file was found at the path "<>datafile];Input["Press x and <Enter> to exit"];Exit[]];
Print[""];

(* STAGE 1 *)
success=True;
If[StringLength[Species]<1,  Species =FileNameTake[datafile, {-2}]]; 
result= CheckAbort[LoadModel[datafile, verbose], success = False];
Heading = {"STAGE 1 COMPLETED: Loaded data for " <> Species, "from " <> FileNameTake[datafile] };
If[success,Print[Heading],Print["Load and test of the datafile has failed."];
			Input["Press x and <Enter> to exit"];Exit[]];  
Print[""];			

(* STAGE 2*)
SStype = "FacetCone";
Reductiontable = {{"Stage", " Constraints ", " Variables ", " Ray Yield "}};
{RSStime, result} = Timing[
   	result = CheckAbort[Check[DoFBA[Tolerances, True], success = False], success = False];    
   		If[StringQ[result], success = False;
     	Print["LP solution of the imported FBA model has failed. Retry Stage 2 after
 adjusting the LP tolerance, or change LP method in the datafile.  "]];
	result = CheckAbort[Check[
   		ReducedSolutionSpace[S, bounds, objectselector, maxmin, verbose],
   		 success = False],  success = False];
	If[StringQ[result], success=False; Print[result]; PrependTo[feasiblepoints,{}]]];
 Heading = {"STAGE 2 COMPLETED: Reduced Solution Space for " <> Species, 
   	"  Model " <> ModelName <> " of type " <> ToString@SStype <> 
   	"\n calculated on " <> DateString["DateShort"] <> " in " <> 
      Quiet@ToString[NumberForm[RSStime, 3]] <> " seconds."};
If[success,Print[Heading],Print["RSS reduction of the solutionspace has failed."];
		SaveResults[{}, datafile];
		Input["Press x and <Enter> to exit"];Exit[]];
Print[""];		

(* STAGE 3 *)
{Kerneltime, result} =  Timing[CheckAbort[Check[
    	KernelFinder[verbose],
    	 success = False], success = False]];
 Heading = {"STAGE 3 COMPLETED: Capped Solution Space for " <> Species, 
     " Model " <> FileBaseName[datafile] <> " of uncapped type " <> ToString@SStype <>
       "\n calculated on " <> DateString["DateShort"] <> " in " <> 
     Quiet@ToString[NumberForm[Kerneltime, 3]] <> " seconds."};
If[success,
	SSKinRSS = KernelSpace; 
    SSKinsphere = InscribedSphere;
	Print[Heading],
	
	Print["Calculation of a closed SSK has failed."];
		SaveResults[{}, datafile];
		Input["Press x and <Enter> to exit"];Exit[]];  
Print[""];		

(* STAGE 4 *)
If[SStype != "Point",
    {Shapetime, result} = Timing[CheckAbort[Check[KernelShape[maxaspect, maxthin, verbose],
    	 success = False], 	 success = False]]; 
    Heading = {"STAGE 4 COMPLETED: Shape Analysis for " <> Species, 
      " Model " <> FileBaseName[datafile] <> "  with uncapped kernel of type " <> 
      ToString@SStype <> 
       "\n calculated on " <> DateString["DateShort"] <> " in " <> 
       Quiet@ToString[NumberForm[Shapetime, 3]] <> " seconds."};,
    Shapetime = 0; 
    flatplot = Graphics@Text["Point SSK, has no shape."]];
If[success, Print[Heading],Print["Shape analysis of the closed SSK has failed."];
		SaveResults[{}, datafile];
		Input["Press x and <Enter> to exit"];Exit[]];   
Print[""];		

(* STAGE 5 *)
{Chordtime, result} = Timing[CheckAbort[Check[
    	{chordpic, cenpic} = KernelDisplay[ExportResults, verbose],
    	 success = False],  success = False]];
 Heading = {"STAGE 5 COMPLETED: Full SS Kernel Analysis for " <> Species, 
     " Model " <> FileBaseName[datafile] <> "  with uncapped kernel of type " <> 
      ToString@SStype <> "\n calculated on " <> DateString["DateShort"] <> " in " <> 
      Quiet@ToString[NumberForm[RSStime + Kerneltime + Shapetime + Chordtime, 3]] <> 
      " seconds."}; 
If[success, Print[Heading],Print["Display of chords and centering has failed."];
		SaveResults[{}, datafile];
		Input["Press x and <Enter> to exit"];Exit[]];    
Print[""];		
		
(* STAGE 6 *)
(* Only export first 8 components of exportresults; component 9
  	  is the RSS structure, not really externally useful. *)
Heading = {"Full SS Kernel Analysis for " <> Species, 
     " Model " <> FileBaseName[datafile] <> "  with uncapped kernel of type " <> 
      ToString@SStype <> "\n calculated on " <> DateString["DateShort"] <> " in " <> 
      Quiet@ToString[NumberForm[RSStime + Kerneltime + Shapetime + Chordtime, 3]] <> 
      " seconds."}; 
CheckAbort[success=Check[
   	SaveResults[If[Length@ExportResults==0,{},ExportResults[[1;;8]]], datafile],
   	 False],  success = False];

If[success, Print["Output files have been stored successfully."],
	Print["Export of output files has failed."]; 
	Input["Press x and <Enter> to exit"];Exit[]];  

Input["Press x and <Enter> to exit"]; 



