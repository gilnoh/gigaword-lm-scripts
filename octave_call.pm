# a set of perl method that will rely on calculating 
# some log-probability calculations.  

require Exporter;
@ISA = qw(Exporter); 
@EXPORT = qw(lambda_sum); 

# all calculation will call the corresponding octave code...  


sub lambda_sum($@@)
{
    # gets lambda, two list of log probability 
    # (same length, each per token) 
   
    my $lambda = $_[0]; 
    my $left_aref = $_[1]; # log probability of P_doc, on each token
    my $right_aref = $_[2]; # log probability of P_coll, on each token

    # sanity check 
    # size left == size right
}
1; 
