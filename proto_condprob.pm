# a perl module that uses srilm_call.pm & octave_call.pm 
# to calculate "common sense" as "conditional probability on LM over documents" 

package proto_condprob; 

use warnings; 
use strict; 
use Exporter; 
use srilm_call qw(read_debug3_p call_ngram); 
use octave_call;

our @ISA = qw(Exporter); 
our @EXPORT = qw(P_t); 
our @EXPORT_OK = qw (P_coll P_doc $COLLECTION_MODEL $DOCUMENT_MODEL_PATH); 

# some constants 
our $COLLECTION_MODEL = "./output/collection.model"; 
our $DOCUMENT_MODELS = "./output/afp_eng_2009/*.model"; 
our $LAMBDA = 0.5; 

my @collection_seq =(); # global variable that is filled by P_coll, and used by P_doc (thus in P_t)

sub P_t($;$$$) 
{
    # argument: text, lambda, collection model path, document model path 
    # out: a hash? (model name, prob of given text produced from the model) 

    my %result; # $result{"model_id"} = log prob of $text from 'model_id' 

    # argument copy & sanity check 
    my $text = $_[0]; 
    die unless ($text); 
    if ($_[1]) { # lambda 
	die unless ($_[1] >=0 and $_[1] <= 1); 
	$LAMBDA = $_[1]; 
    }
    if ($_[2]) { # collection model (single file) 
	die unless (-r $_[2]);
	$COLLECTION_MODEL = $_[2]; 
    }
    if ($_[3]) { # document models as file glob string (e.g. "path/*.model") 
	$DOCUMENT_MODELS = $_[3]; 
    }

    # get list of all document models     
    my @document_model = glob($DOCUMENT_MODELS); 
    die unless (scalar @document_model); 

    # call P_coll() 
    print STDERR "Calculating collection model logprob (to be interpolated)";  
    my @r = P_coll($text); # return value already saved in global @collection_seq
    my $coll_logprob = lambda_sum2(1, \@r, \@r); 
    print STDERR $coll_logprob, "\n"; 

    # for each model, call P_doc()     
    # ( may be extended with multi-threads, later ) 
    print STDERR "Calculating per-document model logprobs, ", scalar(@document_model), " files\n"; 
    my $count = 0; 
    foreach (@document_model)
    {
	my $logprob = P_doc($_); 
	$result{$_} = $logprob; 
	
	print STDERR "." unless ($count++ % 100); 
    }
    
    print STDERR  "\n"; 
    return %result; 
}



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
    my $logprob = lambda_sum2($LAMBDA, \@doc_seq, \@collection_seq); 
    return $logprob; 
}


1; 
