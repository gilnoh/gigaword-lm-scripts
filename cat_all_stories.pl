#!/usr/bin/perl 

# This simple script gets a path, and cat all "*.story" in 
# the direct subdirectory of the path to the STDOUT. (1 depth only) 

use warnings;
use strict; 

die "This simple script gets a path, and cat all news file (*.story) in \nthe direct subdirectories of that path, to the STDOUT. (1 depth only)\nUsage: At least one argument needed; a directory path.\n(> perl cat_all_stories.pl ./models/document/ > collection.txt)\n" unless ($ARGV[0]); 

my $toppath = $ARGV[0]; 
opendir (my $dh, $toppath) or die "can't open dir $ARGV[0]\n"; 
#my @ls = glob("$ARGV[0]"); 

my @subdir; # will hold all subdirectories of the given path 
foreach (readdir($dh))
{
    next if ( ($_ eq "..") ); 
    my $path = $toppath . "/" . $_; 
    push @subdir, $path if (-d $path); 

}
close $dh; 
#print "$_ \n" foreach (@subdir); 
#die; 
print STDERR "$toppath has ", scalar (@subdir), " dirs (subdirs + itself) to follow. All .story files in them will be dumped.\n";

foreach (@subdir) 
{
    print STDERR "working on $_ ";
    my @ls = glob($_ . "/*.story"); 
    print STDERR scalar(@ls), " files\n"; 

    foreach (@ls)
    {
	#print $_, "\n"; 
	open FILE, "<", $_; 
	print while (<FILE>); 
	close FILE; 
    }
}
