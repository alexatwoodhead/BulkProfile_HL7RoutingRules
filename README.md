# BulkProfile_HL7RoutingRules
IRIS Integration utility to report difference in Routing HL7 behaviour between Systems and versions.

Implementation consists of the single class: alwo.UnitTest.RuleSet.BulkProfile

## Requirement
* Facilitate bulk profiling of HL7 message routing on existing production WITHOUT having to swap existing Services for FileService equivalents.
* Avoid manually writing UnitTests
* Apply current production message schema behavior

## How it works
On System A
* Read a directory containing HL7 files
* Individually play them through an existing HL7 production
* Output a CSV file for routing events

On System B
* Read a directory containing same HL7 files
* Individually play them through an existing HL7 production
* Output a CSV file for routing events

Using faviorite comprison tool:
* Compare the two CSV files

![Comparison of Report files](/images/CompareCSV.png "Comparison of Report files")

## Install
IPM (ZPM) : install alwo-unittest-ruleset-bulkprofile

## How to run utility

```objectscript
set inputDirectory="C:\temp\RuleSetHL7"
set fileWildCard="*.txt"
set outputReport="RuleReportIRIS2022.csv"
set serviceName="From_SystemZ"
set targetName="MsgRouter"
do ##class(alwo.UnitTest.RuleSet.BulkProfile).EvaluateRecords(inputDirectory,fileWildCard,outputReport,serviceName,targetName)

```
Argument "fileWildCard"
 - A pattern to match HL7 file names to be processed.
 - For example if files have a "*.hl7" suffix. Use "*.hl7" instead.

Argument "serviceName" (Required)
 - This is the configuration name in the current production for the Service you want to send all HL7 messages from.

Argument "targetName" - (Optional)
 - This is the first target of the service.
 - If not specified will just use the TargetConfigName defined in the current production settings. 

By default CSV reports will be created in same directory as source HL7 input files. Specify an absolute path if you want in a different location.

## Tested on releases
* IRIS 4 Health - RedHat 2018.1.2
* IRIS 4 Health - RedHat 2022.1
* IRIS 4 Health - Windows 2022.1

## DOCKER Support
* running on intersystemsdc/irishealth-community:latest
* using the actual version of IPM
### Prerequisites   
Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and [Docker desktop](https://www.docker.com/products/docker-desktop) installed.    
### Installation    
Clone/git pull the repo into any local directory
```
$ git clone https://github.com/alexatwoodhead/BulkProfile_HL7RoutingRules.git 
```
Open the terminal in this directory and run:
```
$ docker-compose up -d
```
Command line access from docker console
```
$ docker-compose exec iris iris session iris
USER>
```
or using **WebTerminal**
```
http://localhost:42773/terminal/
```  
Access to files must of course be adjusted to Linux/Unix style. 
