# temporary sketch of the experiment, 

use warnings; 
use strict; 
use proto_condprob; 
use octave_call; 

# test call on 2009 small set 

my $text = "we can not say yet if there will be an agreement , \" said Merkel on her way into the summit .";  

#my %r = P_t($text); 
my %r = P_t_multithread($text); 
print "Done\n"; 
export_hash_to_file(\%r, "Pt_from_sketch.txt"); 
my @a = values %r;
print "Average logprob from the doc-models: ", mean(\@a), "\n"; 

sub export_hash_to_file
{
    my %h = %{$_[0]}; 
    my $filename = $_[1]; 
    open FILE, ">", $filename; 
    foreach (sort keys %r)
    {
	print FILE "$_ \t $h{$_}\n"; 
    }
    close FILE;
}
