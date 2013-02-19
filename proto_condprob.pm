# a perl module that uses srilm_call.pm & octave_call.pm 
# to calculate "common sense" as "conditional probability on LM over documents" 

use warnings; 
use strict; 
use Exporter; 
use srilm_call qw(read_debug3_p call_ngram); 
use octave_call qw(lambda_sum weighted_sum mean); 

my @ISA = qw(Exporter); 
my @EXPORT = qw(P_coll); 
my @EXPORT_OK = qw ($COLLECTION_MODEL $DOCUMENT_MODEL_PATH); 

# some constants 
our $COLLECTION_MODEL = "./output/collection.model"; 
our $DOCUMENT_MODEL_PATH = "./output/afp_eng_2009"; 
our $LAMBDA = 0.1; 

sub P_t
{
    # argument: lambda, files (as glob) to be used, collection model 
    # out: a hash? (model name, prob) 
}


my @collection_seq =(); 

# internal function that records collection probability per words 
# (model to be interpolated for each P_doc model) 
sub P_coll($)
{
    # sanity check 
    die "unable to find collection model file $COLLECTION_MODEL\n" unless (-r $COLLECTION_MODEL); 
    my $sent = $_[0]; 

    # from srilm_call.pm 
    my @out = call_ngram($COLLECTION_MODEL, "", $sent); 
    @collection_seq = read_debug3_p(@out); 

    return @collection_seq; 
}

# internal function, that assumes previous call on P_coll  
sub P_doc($) 
{
    # arg[0]: document model path 
    
    die unless (scalar @collection_seq); 
    die unless (-r $_[0]); 

    my @doc_seq = read_debug3_p(call_ngram($_[0])); 
    #print "\n", (scalar @doc_seq), "\t", (scalar @collection_seq), "\n"; 
    my $logprob = lambda_sum($LAMBDA, \@doc_seq, \@collection_seq); 
    return $logprob; 
}


1; 
