#/usr/bin/perl 

use strict; 
use warnings; 

use File::Slurp; 

use Plucene; 
use Plucene::Document; 
use Plucene::Document::Field; 
use Plucene::Search::IndexSearcher; 
use Plucene::Analysis::SimpleAnalyzer; 
use Plucene::Analysis::Standard::StandardAnalyzer; 
use Plucene::Index::Writer; 
use Plucene::QueryParser; 

# This small script will generate Plucene index for all 
# .story files in (direct) subdirs of /models/document 
# The generated index will be reside (on /models_index dir)

# What it does is similar to perstory_runner.pl;  
# perstory_runner runs SRILM to generate ngram model per 
# news article. This script runs internally Plucene and 
# make Plucene index. 

# configurable constants 

#
# get path 
die "Usage: At least one argument needed; a dir path.\n> perl indexing.pl \"./models/document\"\nThis small script will generate Plucene index for all .story files in (up to 2nd-depth) subdirs of the argument. The index will be stored in ./models_index\n" unless ($ARGV[0]); 

my $toppath = $ARGV[0]; 
opendir (my $dh, $toppath) or die "can't open dir $ARGV[0]\n"; 

#
# read subdirs 
my @subdir; # will hold all subdirectories of the given path 
foreach (readdir($dh))
{
    next if ( ($_ eq "..") ); 
    my $path = $toppath . "/" . $_; 
    push @subdir, $path if (-d $path); 

    # push sub-sub dir, if any 
    if (-d $path)
    {
	unless ($_ eq ".")
	{
	    opendir (my $dsubh, $path) or die "can't open dir $path\n"; 
	    foreach (readdir($dsubh))
	    {
		next if ( ($_ eq "..") or ($_ eq ".")); 
		push @subdir, ($path . "/" . $_); 
	    }
	    close $dsubh; 
	}
    } # end sub-sub
}
close $dh; 
print STDERR "$toppath has ", scalar (@subdir), " dirs (subdirs + itself) to follow. All .story files will be indexed.\n";

#
# prepare analyzer and indexer 
# my $analyzer = Plucene::Analysis::SimpleAnalyzer->new();
my $analyzer = Plucene::Analysis::Standard::StandardAnalyzer->new(); 
my $writer = Plucene::Index::Writer->new("models_index", $analyzer, 1);

#
# for each files, index them 
my $file_count=0; 
foreach my $d (@subdir) 
{
    print STDERR "working on $d "; 
    # glob the files in the dir. 
    my @ls = glob($d . "/*.story"); 
    print STDERR scalar(@ls), " files\n"; 

    # for each file, index them. 
    foreach (@ls)
    {
	my $inputfile = $_; 
	my $text = read_file($inputfile); 

	# prepare a Plucene doc. 
	my $doc = Plucene::Document->new; 
	$doc->add(Plucene::Document::Field->UnIndexed(id => $inputfile)); 
	#$doc->add(Plucene::Document::Field->Text(text => $text)); 
	$doc->add(Plucene::Document::Field->UnStored(text => $text)); 

	# add to index. 
	$writer->add_document($doc);
    
	$file_count++; 
	print STDERR "." unless ($file_count % 100); 
    }
    print STDERR "\n"; 
}
print STDERR "In total, processed and indexed $file_count .story files, and have ", $writer->doc_count(), " indexed docs\n"; 

$writer->optimize(); 
undef $writer; # close the indexer writer 

