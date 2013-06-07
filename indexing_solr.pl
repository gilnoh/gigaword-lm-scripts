#/usr/bin/perl 

# this script will index gigaword story files, with SOLR 

use strict; 
use warnings; 

use WebService::Solr; 
use WebService::Solr::Document; 
use WebService::Solr::Query; 

use File::Slurp; 
use File::Basename; 

## Config; solr url. (as it is defined in
## /solr-4.3.0/gigaword_indexing )
my $SOLR_URL = "http://localhost:9911/solr"; 

#
## check args

die "Usage: At least one argument needed; a dir path.\n> perl
indexing_solr.pl \"./models/document\"\nThis small script will index
the documents with SOLR, all .story files in (up to 2nd-depth) subdirs of the argument. The index will be stored in ./models_index\n" unless ($ARGV[0]); 

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
# Indexing, call solr->add for each document. 
my $solr = WebService::Solr->new($SOLR_URL);

# for each files, index them 
my $file_count=0; 
foreach my $d (@subdir) 
{
    print STDERR "indexing $d "; 
    # glob the files in the dir. 
    my @ls = glob($d . "/*.story"); 
    print STDERR scalar(@ls), " files\n"; 

    # for each file, index them. 
    my @docs; 
    foreach (@ls)
    {
	my $inputfile = $_; 
	my $text = read_file($inputfile); 
	
	# get file name from path 
	my $filename = basename($inputfile); 

	# prepare a doc 
	my $field1 = WebService::Solr::Field->new( id => $filename );
	my $field2 = WebService::Solr::Field->new( article => $text ); 
	my $doc = WebService::Solr::Document->new($field1, $field2);
	push @docs, $doc;  
	$file_count++; 

	# unless ($file_count % 100) 
	# {
	#     print STDERR "."; 
	# }
    }
    $solr->add(\@docs); 
    @docs = (); 
    #print STDERR "\n"; 
}

# optimize! 
print STDERR "optimization requested ..."; 
print STDERR " DONE" if ($solr->optimize()); 
print STDERR "\n"; 
print STDERR "indexed $file_count files\n"; 
