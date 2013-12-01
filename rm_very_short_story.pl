#!/usr/bin/perl 

# This simple script gets a path, scans all "*.story" in
# the direct subdirectory of the path. 
# then it deletes files with less than DOC_MIN_NUM_SENTENCES 
# sentences. 

use warnings;
use strict; 

# config
#

# ignore texts with less than N sentences. 
our $DOC_MIN_NUM_SENTENCES = 5; 

# global 
# 

# we go into 2-depth (don't change, this is not a config) 
my $USE_DEPTH2 = 1; 

#
# main code 

# we need to actually read the file (wc will report wrong number of lines, because of empty lines, etc) 
my $toppath = $ARGV[0]; 
opendir (my $dh, $toppath) or die "can't open dir $ARGV[0]\n"; 

my @subdir; # will hold all subdirectories of the given path 
foreach (readdir($dh))
{
    next if ( ($_ eq "..") ); 
    my $path = $toppath . "/" . $_; 
    push @subdir, $path if (-d $path); 

    if ( ($USE_DEPTH2) && (-d $path) ) 
    {
	# push "sub-sub dir if any" 
	unless ($_ eq ".")
	{
	    opendir (my $dsubh, $path) or die "can't open dir $path\n"; 
	    foreach (readdir($dsubh))
	    {
		next if (($_ eq "..") or ($_ eq ".")); 
		push @subdir, ($path . "/" . $_); 
	    }
	    close $dsubh; 
	}
    } # end depth 2 
}
close $dh; 
print STDERR "$toppath has ", scalar (@subdir), " dirs (itself + subdirs + sub-subdirs) to follow. All .story files will be checked, and .story files with less than $DOC_MIN_NUM_SENTENCES sentences will be deleted!\n"; 

# for all files 

my $deleted_file=0; 
my $total_file=0; 
my @length_array; 
my @survived_length_array; 
foreach (@subdir)
{
    print STDERR "working on $_ ";
    my @ls = glob($_ . "/*.story"); 
    print STDERR scalar(@ls), " files\n"; 

    foreach (@ls)
    {
	my $raw_content; 
	my $filename = $_; 
	open INFILE, "<", $filename; 
	$raw_content .= $_ while (<INFILE>); 
	close INFILE; 
	my @temp = split /\n/, $raw_content; 
	my @sentences; 
	foreach (@temp) # prepare text 
	{
	    #remove all empty lines, so "real lines only"
	    next unless (/\S/); 
	    push @sentences, $_; 
	}    

	my $num_sen = scalar @sentences; 
	push @length_array, $num_sen; 
	if ($num_sen < $DOC_MIN_NUM_SENTENCES) 
	{
	    #dcode# print STDERR "$filename: $num_sen sentences, deleted\n"; 
	    # actually call rm 
	    unlink $filename; # bye, file... 
	    $deleted_file++; 
	}
	else
	{
	    push @survived_length_array, $num_sen; 
	}
	$total_file++; 
    }
}

print STDERR "Removal of 'too short files'. Deleted $deleted_file total files that has sentences less than $DOC_MIN_NUM_SENTENCES. "; 
print STDERR " (out of $total_file files)\n"; 
print STDERR " (the average number of sentences of the documents was: ", sum(@length_array) / $total_file, ")\n"; 
print STDERR " (new average is now: ", sum(@survived_length_array) / ($total_file - $deleted_file), ")\n";  

sub sum
{
    my $sum = 0; 
    foreach (@_)
    {
	$sum += $_; 
    }
    return $sum; 
}
