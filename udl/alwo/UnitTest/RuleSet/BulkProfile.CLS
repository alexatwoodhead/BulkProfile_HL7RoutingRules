/// <pre>
/// Copyright (c) Alex Woodhead 2022
/// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
/// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
/// License MIT
/// Source: https://github.com/alexatwoodhead/UnitTest_RuleSet
/// Version: 1.0
/// </pre>]]>
/// Utility to generate reports on how each file is processed for comparison with routing behaviour of another installation.
/// HL7 DocType is determined by the configuration of the service.<br/>
/// Production must already be running in order to run the routing Test
/// Run the utility with same files on different environments.
/// Then use favourite difference utility to compare CSV output files to see difference / assurance of behaviour consistency.
/// Usage
/// <example>
/// set inputDirectory="C:\temp\RuleSetHL7"
/// set fileWildCard="*.txt"
/// set outputReport="RuleReportIRIS2022.csv"
/// set serviceName="From_SystemZ"
/// set targetName="MsgRouter"
/// do ##class(alwo.UnitTest.RuleSet.BulkProfile).EvaluateRecords(inputDirectory,fileWildCard,outputReport,serviceName,targetName)
/// </example>
Class alwo.UnitTest.RuleSet.BulkProfile [ Abstract ]
{

/// Override with name of existing service on production
/// Parameter SourceBusinessServiceName = "From_SystemZ";
/// Override with name of existing business process routing engine on production
/// Parameter TargetConfigName = "MsgRouter";
Parameter SortBy = "Name";

Parameter IncludeDirs = 0;

Parameter NewLine = 10;

Parameter SendSyncDescription = "BulkProfile";

/// Main entry point.
/// Invoke this method to profile rule execution
ClassMethod EvaluateRecords(inputDirectory = "", fileWildCard = "*.hl7", outputReportPath = "", pSourceBusinessServiceName As %String = "", pTargetConfigName As %String = "") As %Status
{
	do ..Cleanup()
	set ^||WaterMark=0
	&SQL(SELECT %NOLOCK top 1 ID into :watermark FROM Ens_Rule.Log order by ID DESC)
	set:SQLCODE=0 ^||WaterMark=watermark
	
	set ret=$$$OK
	if '##class(%File).DirectoryExists(inputDirectory) {
		set errorMessage="Directory """_inputDirectory_""" not found"
		do ..LogMessage(errorMessage)
		do ..LogMessage("Exit. No work done")
		quit $$$ERROR(5001,errorMessage)			
	}
	if inputDirectory'?1(1"\",1A1":\",1"/")1.E {
		set errorMessage="Directory """_inputDirectory_""" invalid. Must be absolute path containing one subdirectory"
		do ..LogMessage(errorMessage)
		do ..LogMessage("Exit. No work done")
		quit $$$ERROR(5001,errorMessage)		
	}
	// get filesystem directory path seperator
	set seperator=$S($L(inputDirectory,"/")>1:"/",1:"\")
	// ensure trailing seperator
	set:$E(inputDirectory,*)'=seperator inputDirectory=inputDirectory_seperator
	// if outputReportPath has no directory, reuse input directory for report output location
	if $L($TR(outputReportPath,"\/"))=$L(outputReportPath) {
		// just the filename, no directory so output report to output directory
		set outputReportPath=inputDirectory_outputReportPath
	}
	if outputReportPath'?1(1"\",1A1":\",1"/")1.E {
		set errorMessage="Output Report Path """_outputReportPath_""" invalid. Must be absolute path containing one subdirectory"
		do ..LogMessage(errorMessage)
		do ..LogMessage("Exit. No work done")
		quit $$$ERROR(5001,errorMessage)
	}
	if ##class(%File).DirectoryExists(outputReportPath) {
		if $E(outputReportPath,*)'?1(1"/",1"\") {
			// Default the filename
			set outputReportPath=outputReportPath_$S($L(outputReportPath,"/")>1:"/",1:"\")_"HL7BulkRouteProfile"_$TR($ZDT($H,3)," :")_".csv"
		}
	}
	
	// Get list of input filename to process
	set rs=##class(%ResultSet).%New("%File:FileSet")
	set sortBy="Name"
	set includeDirs=0
	set tSC=rs.Execute(inputDirectory,fileWildCard,..#SortBy,..#IncludeDirs)
	for {
		quit:'rs.Next()
		set filename=rs.Data("Name")
		continue:filename?1.2"."
		continue:filename=""
		set ^||Files(filename)=""
	}
	do rs.Close()
	
	
	// Get the current production in focus
	set tSC=..GetBusinessService(pSourceBusinessServiceName,.sourceBuinessService)
	quit:$$$ISERR(tSC) tSC

	// Loop over and process files
	set filename=""
	for {
		set filename=$Order(^||Files(filename))
		quit:filename=""
		set hl7=..GetSourceMessage(filename)
		if '$IsObject(hl7) {
			set errorMessage="Unable to correlate file """_filename_""" to HL7. Skipping. Not route tested."
			do ..LogMessage(errorMessage)
			continue
		}
		do ..SendMessage(filename,hl7,sourceBuinessService,pTargetConfigName)
	}
	
	do ..WriteReport(outputReportPath)
	
	// clean up
	do ..Cleanup()
}

ClassMethod Cleanup()
{
	Kill ^||Files,^||WaterMark,^||Report
}

ClassMethod GetBusinessService(SourceBusinessServiceName As %String, Output pBusinessService As Ens.BusinessService) As %Status
{
	set tSC=##class(Ens.Director).GetProductionStatus(.prodName,.pState)
	if $$$ISERR(tSC) {
		do ..LogMessage("Error getting production status")
		do ..LogMessage("Exit. No work done")
		do $SYSTEM.Status.DisplayError(tSC)
		quit tSC
		
	}
	if $G(prodName)="" {
		set errorMessage="Error getting production status. Current Namespace must have a running production."
		do ..LogMessage(errorMessage)
		do ..LogMessage("Exit. No work done")
		quit $$$ERROR(5001,errorMessage)
	}
	do ..LogMessage("Production name "_prodName)
	
	// Get Reference to 
	if '##class(Ens.Director).IsProductionRunning() {
		set errorMessage="Production "_prodName_" not runnning. Please start it and run utility again."
		do ..LogMessage(errorMessage)
		do ..LogMessage("Exit. No work done")
		quit $$$ERROR(5001,errorMessage)
	}
	do ..LogMessage("""Config Item Name "_SourceBusinessServiceName_"""")
	
	set tSC=##class(Ens.Director).CreateBusinessService(SourceBusinessServiceName,.pBusinessService)
	if $$$ISERR(tSC) {
		set errorMessage="Problem creating Business Service reference for "_SourceBusinessServiceName_". Ensure enabled. May require poolsize 2 to run test depending on service type."
		do ..LogMessage(errorMessage)
		do ..LogMessage("Exit. No work done")
		do $SYSTEM.Status.DisplayError(tSC)
		quit $$$ERROR(5001,errorMessage)	
	}
	
	set pBusinessService.%PreserveSession=0
	quit tSC
}

ClassMethod SendMessage(filename As %String, message As EnsLib.HL7.Message = {..HL7Message}, pBusinessService As EnsLib.HL7.Service.Standard, pTargetConfigName As %String = "")
{
	// Only want the files name without the directory part
	// This allows differently named source directories to be used across Systems, to have consistent output reporting 
	set filename=##class(%File).GetFilename(filename)
	// Reuse the "Message Schema Category" setting of the Service instance 
	// to correlate the intended Message DocType
	// ie: Do what the production normally does
	//(EnsLib.HL7.Service.Standard)
	do message.PokeDocType(pBusinessService.resolveDocType(message, message.GetValueAt(1)))
	// Reinitalise Session
	Set pBusinessService.%SessionId=""
	do pBusinessService.ForceSessionId()
	
	set:pTargetConfigName="" pTargetConfigName=pBusinessService.TargetConfigNames
	// Send Message within production
	set tSC=pBusinessService.SendRequestSync(pTargetConfigName,message,.pResponse,-30,..%ClassName(0)_":Filename="_filename)
	if $$$ISOK(tSC) {
		do ..LogMessage("Message for file "_filename_" sent")
	}
	if pBusinessService.%SessionId="" {
		do ..LogMessage("SessionId not set")
		quit
	}
	do ..LogMessage("SessionId was "_pBusinessService.%SessionId)	
	
	do ..AddReportLinesForFile(filename,pBusinessService.%SessionId)
}

ClassMethod GetSourceMessage(filename) As EnsLib.HL7.Message
{
	#dim SourceMessage as EnsLib.HL7.Message
	set stream=##class(%Stream.FileCharacter).%New()
	set stream.Filename=filename
	set lines=""
	while 'stream.AtEnd
	{
		set line=$ZSTRIP(stream.ReadLine(),"<w")
		continue:line=""
		set lines=lines_($S($L(lines)=0:"",1:$C(..#NewLine)))_line
	}
	set SourceMessage=##class(EnsLib.HL7.Message).ImportFromString(lines,.tSC)
	quit:$$$ISERR(tSC) $$$NULLOREF
	// Note poke DocType to build message map is done within "SendMessage" 
	quit SourceMessage
}

/// rule#1(SYSA):when#1
/// send:To_SystemA:
ClassMethod AddReportLinesForFile(pFilename = "", sessionId = "")
{
	quit:pFilename=""
	// Watermark is to help mitigate performance challenge when large retention of RuleLogs on the system
	set watermark=+$G(^||WaterMark)
	&SQL(DECLARE ReasonReturn CURSOR FOR
		SELECT ID, ConfigName, RuleName, Reason, ReturnValue
		INTO :seq, :ConfigName, :RuleName, :Reason, :ReturnValue
		FROM Ens_Rule.Log
		WHERE ID>:watermark AND SessionId=:sessionId
		ORDER by ID ASC)
	// Orders earliest first
	&SQL(OPEN ReasonReturn)
	for {
		&SQL(FETCH ReasonReturn)
		Quit:SQLCODE'=0
		set ^||Report(pFilename,seq)=$LB(ConfigName,RuleName,Reason,ReturnValue)
	}
	&SQL(CLOSE ReasonReturn)
}

ClassMethod LogMessage(message)
{
	Write !,message
}

/// Given output file name write out the report
/// do ##class(alwo.UnitTest.RuleSet.BulkProfile).WriteReport(filename)
ClassMethod WriteReport(outfile)
{
	
	OPEN outfile:"NWS":2
	if '$T {
		do ..LogMessage("Unable to open output report file "_outfile)
		do ..LogMessage("Skipping Report export")
		quit	
	}
	try {
	USE outfile write "Filename,ConfigName,RuleName,Reason,ReturnValue"
	// Double escape string containing quote characters for Excel / convention
	set inFilename=""
	for {
		set inFilename=$O(^||Report(inFilename))
		quit:inFilename=""
		
		set seq=""
		for {
			set seq=$O(^||Report(inFilename,seq),1,data)
			quit:seq=""	
			
			// assumes list length WIULL be four
			USE outfile write !,..Esc(inFilename),",",..Esc($LG(data,1)),",",..Esc($LG(data,2)),",",..Esc($LG(data,3)),",",..Esc($LG(data,4))
		}
	}
	} catch {}
	/// Harmless if not open
	CLOSE outfile
}

/// For client CSV readers escape double quotes
/// Also when field contains commas also quote to avoid clash with field delimiter
/// <!--
/// Tested with:
/// w ##class(alwo.UnitTest.RuleSet.BulkProfile).Esc("TEST")   => TEST
/// w ##class(alwo.UnitTest.RuleSet.BulkProfile).Esc("TE,ST")  => "TE,ST"
/// w ##class(alwo.UnitTest.RuleSet.BulkProfile).Esc("TE""ST") => "TE""ST"
/// -->
ClassMethod Esc(val As %String) As %String [ CodeMode = expression ]
{
$Select($L($TR(val,""","))<$L(val):""""_$Replace(val,"""","""""")_"""",1:val)
}

}

