# this simple script sketches how to call P(h|t) from 
# the RTE3 data. 

use warnings; 
use strict; 


# simple test 
my ($t_aref, $h_aref, $d_aref) = read_rte_data("./testdata/English_dev.xml"); 
for(my $i=0; $i < scalar(@$t_aref); $i++)
{
    print "id: ", ($i+1), "\t", $d_aref->[$i] ,"\n"; 
    print "T: ", $t_aref->[$i]; 
    print "H: ", $h_aref->[$i]; 
}


# call splitta for tokenization ... 
sub call_splitta 
{


}


# reading EOP RTE file. 
sub read_rte_data
{
    # not generic but, good for current data 
    my $filename = shift; 
    open FILE, "<", $filename or die "unable to read $filename"; 
    
    my @t;
    my @h; 
    my @gold; 
  
    while (<FILE>)
    {
	next unless ($_ =~ /<pair id=.+ entailment="(.+?)"/); 
	# now a pair: get next two lines 
	{
	    my $gold_decision = $1; 
	    my $tline = <FILE>; 
	    my $hline = <FILE>; 
	    # remove head / tail tags 
	    $tline =~ s/^\s+<t>//; 
	    $tline =~ s/<\/t>$//; 

	    $hline =~ s/^\s+<h>//; 
	    $hline =~ s/<\/h>$//; 

	    # dcode 
	    #print $tline, "\n"; 
	    #print $hline, "\n"; 
	    #die; 
	    push @t, $tline; 
	    push @h, $hline; 
	    push @gold, $gold_decision; 
	}
    }    
    die "Eh, need to be called within an array context" unless defined wantarray; 
    return (\@t, \@h, \@gold); 
}
