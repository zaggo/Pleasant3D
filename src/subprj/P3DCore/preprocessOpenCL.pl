#!/usr/bin/env perl
use File::Find;
print "[v0.7] Processing $ARGV[0]\n";

@searchpath = ($ENV{INPUT_FILE_DIR});

if($0 =~ /^(.*)P3DCore\.framework(\/.*)?\/Resources/)
{
	$frameworkPath = $1."P3DCore.framework/Headers";
	push @searchpath, $frameworkPath;
	#print "add search path: $frameworkPath\n"
}

open IN, $ARGV[0] or die "Cannot read input file: $ARGV[0]: $!\n";
@inFile = <IN>;
close IN;
chomp(@inFile);

@outFiles = ();
$outFile = "";
foreach $line (@inFile)
{
	if($line =~ /\s*#include\s*("(.*)".*)/)
	{
		$line = "/* using $1 */";
		$includeFileName = $2;
		$line =~ s/\\/\\\\/g;
		$line =~ s/"/\\"/g;
		$outFile .= "\"".$line."\\n\" \\\n";
		$includeSource = generateIncludeSource($includeFileName);
		push(@outFiles, $includeSource);
	}
	else
	{
		$line =~ s/\\/\\\\/g;
		$line =~ s/"/\\"/g;
		$outFile .= "\"".$line."\\n\" \\\n";
	}
}
push(@outFiles, $outFile);

$outPath = $ENV{DERIVED_FILES_DIR}."/".$ENV{INPUT_FILE_BASE}."OpenCLSource.h";
open OUT, ">".$outPath or die "Cannot write output file $outPath: $!\n";
print OUT "const char* $ENV{INPUT_FILE_BASE}SourceCode\[\]=\{\n";
for($i=0;$i<=$#outFiles;$i++)
{
	print OUT $outFiles[$i];
	if($i==$#outFiles)
	{
		print OUT "\};\n";
	}
	else
	{
		print OUT ",\n";
	}
}

print OUT "const cl_uint $ENV{INPUT_FILE_BASE}SourceCodeCount=",($#outFiles+1),";\n";
close OUT;
print "Result written to $outPath\n";

exit(0);

sub generateIncludeSource
{
	$infileName = shift;
	$outInclude = "";
	#$infilePath = $ENV{INPUT_FILE_DIR}."/".$infileName;
    print "Doing Stuff with $infileName\n";
	$infilePath = findAbsoluteSourcePath($infileName);
	print "Generate include source from '$infilePath'\n";
	
	open INCLUDE, $infilePath or die "Cannot read input file '$infilePath': $!\n";
	@includeFile = <INCLUDE>;
	close INCLUDE;
	chomp(@includeFile);

	foreach $line (@includeFile)
	{
		$line =~ s/\\/\\\\/g;
		$line =~ s/"/\\"/g;
		$line =~ s/cl_(char|uchar|short|ushort|int|uint|long|ulong|float)(\d{1,2})?/\1\2/g;
		
		$outInclude .= "\"".$line."\\n\" \\\n";
	}
	
	return $outInclude;
}

sub findAbsoluteSourcePath
{
	$fileToFind = shift;
	#print "findAbsoluteSourcePath for $fileToFind\n";
    
	undef $fullpath;
	find({wanted=>\&check, follow=>1 }, @searchpath);
	
    # print "found: '$fullpath'\n";
	return $fullpath;
}

sub check
{
	$current = $_;
    #	print "Check $File::Find::name with current: $current\n";
	if($current eq $fileToFind)
	{
		$fullpath = $File::Find::name;
		$File::Find::prune = 1;
	}
}	