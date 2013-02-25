# temporary sketch of the experiment, 

use warnings; 
use strict; 
use proto_condprob qw(:DEFAULT set_num_thread); 
use octave_call; 

# test call on 2009 small set 

#my $text = "we can not say yet if there will be an agreement , \" said Merkel on her way into the summit .";  
#my $hypothesis = "we can not say yet if there will be an agreement , \" said Merkel on her way into the summit .";  
#my $hypothesis = "an agreement may be reached in the summit . "; 

my $text = "there was an airplane accident";  # (1.43) 
#my $text = "there was a car accident"; # (1.24) 
#my $text = "everyone died"; # (24.0) 
my $hypothesis = "everyone died"; 

# what would be average of H(t|t)? : not sure. 24 (2 words) 316 (20+ words), related to the length? 
# train something according to gain, T length, H length, 



# my %r = P_t($text); 
# my %r = P_t_multithread($text); 
# print "Done\n"; 
# export_hash_to_file(\%r, "Pt_from_sketch.txt"); 
# my @a = values %r;
# print "Average logprob from the doc-models: ", mean(\@a), "\n"; 

##
P_h_t_multithread($hypothesis, $text); 

sub export_hash_to_file
{
    my %h = %{$_[0]}; 
    my $filename = $_[1]; 
    open FILE, ">", $filename; 
    foreach (sort keys %h)
    {
	print FILE "$_ \t $h{$_}\n"; 
    }
    close FILE;
}
