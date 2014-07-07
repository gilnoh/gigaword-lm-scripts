# The main module of this project. 
# a perl module that uses srilm_call.pm & octave_call.pm
# to calculate "conditional probability on LM over documents"
# this module is a restructured version of proto_condprob.pm 
# (hopefully final for the paper) 

# CONSIDER in the long term
# a. more modularity? 
# Conditional Probability part and "SOLR", "GigaWord" (or document 
# model stroing) specific parts are actually mixed up somewhat. 
# Maybe in future versions we should clearly separate them. 
# b. real "index-for-LM". 

package condprob;

use forks; # process based thread for Perl, which is actually faster. 
#use threads; 
#use threads::shared;
use warnings;
use strict;
use Exporter;
use srilm_call; # qw(read_debug3_p call_ngram);
use octave_call;
use Carp;
use DB_File; # for caching P_coll
use List::Util qw(sum); 

use WebService::Solr;
use WebService::Solr::Document;
use WebService::Solr::Query;

our @ISA = qw(Exporter);
our @EXPORT = qw(condprob_h_given_t P_t_joint P_t_index $APPROXIMATE_WITH_TOP_N_HITS call_splitta calc_ppl); 
our @EXPORT_OK = qw(set_num_thread P_coll P_doc solr_query get_path_from_docid $COLLECTION_MODEL $DEBUG $DOCUMENT_INDEX_DIR $NOHIT_L0_FILL $SOLR_URL export_hash_to_file $TEMP_DIR get_document_count wordPMI word_condprob $total_doc_count log10 mean_allword_pmi product_best_word_condprob idf_word mean_best_wordPMI $USE_CACHE_ON_SPLITTA $USE_CACHE_ON_COLL_MODEL KL_divergence); 

###
### Configurable values. Mostly Okay with the default!
###

# Model directories
# see making_models.txt about collection model, document models and index. 
our $COLLECTION_MODEL = "./models/collection/collection.model"; 
our $DOCUMENT_MODELS_DIR = "./models/document";
our $DOCUMENT_INDEX_DIR = "./models_index";

# SOLR search engine URL: default local host 9911
# see making_models.txt for how to index documents in SOLR. 
# see solr-4.3.0/gigaword_indexing dir for actual port setting. 
our $SOLR_URL = "http://localhost:9911/solr"; 

# Per-document model interpolate parameter Lambda. (for each n-gram: lambda * doc_prob + (1-lambda) * collection_prob). 0 < lambda < 1 
# (No need to export. Always a parameter of relevant methods) 
my $LAMBDA = 0.5;

# number of concurrent processes to be used for per-document model ngram count. 
our $NUM_THREAD = 4;

# Number Top-N hits documents that will be used to calculate approximation document-wise weighted sum of P(text) and P(text|context). If 0, all documents will be used (no approximation). If this number is given (N), only those top N hit document models will be used as approximation of P_t.
our $APPROXIMATE_WITH_TOP_N_HITS = 1000;

# How you will treat the "non-hit" members? Two options we have
# fill by "drop" (0 P_{Di}), or fill by L0 (lambda as 0)
# if the following values is set as 1, it will use L0 fill.
# otherwise it will use Drop fill.
# our $NOHIT_L0_FILL = 0;;

# Debug Level. 
# 0: no addtional file output. 
# 1: P_t_h_multithread will output intermediate result hash as files. 
# 2: the hash output will be sorted (higher value first). 
# Debug output is useful to check which document was given high weights for 
# P(text | context) 
our $DEBUG=2;

# ends equalizer (for stability of doc-based models) 
# equalizes difference between "collection model" and "document model" 
# by equalizing (minimizing) effect of non-content endings. 
# (only the last . </s> ) 
# our $EQUALIZE_ENDS = 0; # not really needed. 

# Temporary output dir 
# mainly for splitta, text splitter. 
our $TEMP_DIR = "./temp";

# Collection model cache: "big" LM takes long time to query  
# This will cache collection model 
our $USE_CACHE_ON_COLL_MODEL = 1;  
our $USE_CACHE_ON_SPLITTA = 1; 

###
### end of configurable values 
###

### GLOBALS
my @collection_seq =(); # global variable that is filled by P_coll, and used by P_doc (thus in P_t)
my @all_model =(); # global variable that is filled in P_t_index. This array keeps the full list of .model files for this run. (Filled once, used for long). 
my $all_model_top_path; # Associated value to @all_models. (@all_models does not keep full path, just to save memory. this variable keeps the path prefix.) 

# berkely db for LM-collectino model cacheing 
my %COLL_MODEL_CACHE; 

# TODO: unsafe for multiple-writing access!
# move tie to actual access location with lock. 
if ($USE_CACHE_ON_COLL_MODEL)
{
    tie %COLL_MODEL_CACHE, "DB_File", "cache_coll_model.db"; 
}

# berkely db for splitta tokenizer result cacheing 
my %SPLITTA_RESULT_CACHE; 
our $SPLITTA_CACHE_FILE = "cache_splitta_result.db"; 

# if ($USE_CACHE_ON_SPLITTA)
# {
#     tie %SPLITTA_RESULT_CACHE, "DB_File", "cache_splitta_result.db"; 
# }


### 
### Utility methods 
###

# a utility that call splitta for tokenization ... 
# note that this method permits only single instance. 
# input: one string 
# output: one string, tokenzied and sentence splitted. 
#         (one sentence per line) 

# TODO: can't run by multiple instances. (fixed file name) 
sub call_splitta 
{
    print STDERR "tokenization ..."; 
    my $s = shift; 

    if ($USE_CACHE_ON_SPLITTA)
    {

        #my %SPLITTA_RESULT_CACHE; 
        tie %SPLITTA_RESULT_CACHE, "DB_File", $SPLITTA_CACHE_FILE;

        # first check cache 
        if (defined $SPLITTA_RESULT_CACHE{$s})
        {
            print STDERR "(cache hit)\n"; 
            my $result = $SPLITTA_RESULT_CACHE{$s}; 
            untie %SPLITTA_RESULT_CACHE; 
            return $result; 
        }
        # there is no cache for this. 
        untie %SPLITTA_RESULT_CACHE; 
    }


    # write a temp file
    my $file = $TEMP_DIR . "/splitta_input.txt"; 
    open OUTFILE, ">", $file; 
    print OUTFILE $s; 
    close OUTFILE; 
    
    # my $splitted_output = "$temp_dir" . $file_basename . ".splitted"; 
    `python ./splitta/sbd.py -m ./splitta/model_nb -t -o $TEMP_DIR/splitted.txt $file 2> /dev/null`;
    print STDERR " done\n"; 

    open INFILE, "<", $TEMP_DIR . "/splitted.txt"; 
    my $splitted=""; 
    while(<INFILE>)
    {
	# NOTE: this process must be the same as training data generated
	# in gigaword_split_file.pl 

	# fixing tokenization error of Splitta (the end of sentence) 
	# case 1) Period (\w.$) at the end  -> (\w .$) 
	s/\.$/ \. /; 
	# case 2) Period space quote (\w. " $) at the end. -> (\w . " $) 
	s/\. " $/ \. " /;

	$splitted .= $_; 
    }
    close INFILE; 

    my $result = lc($splitted); 
    if ($USE_CACHE_ON_SPLITTA)
    {
        tie %SPLITTA_RESULT_CACHE, "DB_File", $SPLITTA_CACHE_FILE; 
        $SPLITTA_RESULT_CACHE{$s} = $result; 
        untie %SPLITTA_RESULT_CACHE; 
    }
    return $result; 
}

# set number of threads/processes to be used for per-document run. 
sub set_num_thread
{
    $NUM_THREAD = $_[0];
}

# internal helper sub that is used by P_t_index
# gets a list of model files, call P_d on each of them.
sub P_d_runner
{
    my %r;
    my $count = 0;
    foreach (@_)
    {
        $r{$_} =  P_doc($_);
        print STDERR "." unless ($count++ % 100);
    }
    return %r;
}

# (deprecated) 
# sub P_t
# {
#     # argument: $text, $lambda, $collection_model_file, $document_model_dir
#     # out: a hash where a key is model name, and the associated
#     #      value is the value of P_model($text)

#     my %result; # $result{"model_id"} = log prob of $text from 'model_id'

#     # argument copy & sanity check
#     my $text = $_[0];
#     die unless ($text);
#     if ($_[1]) { # lambda
#         die unless ($_[1] >=0 and $_[1] <= 1);
#         $LAMBDA = $_[1];
#     }
#     if ($_[2]) { # collection model (single file)
#         die unless (-r $_[2]);
#         $COLLECTION_MODEL = $_[2];
#     }
#     if ($_[3]) { # document models as file glob string (e.g. "path/*.model")
#         $DOCUMENT_MODELS_DIR = $_[3];
#     }

#     # get list of all document models
#     my @subdir = get_subdirs($DOCUMENT_MODELS_DIR);
#     print STDERR "$DOCUMENT_MODELS_DIR has ", scalar (@subdir), " dirs (subdirs + itself) to follow;\n";

#     my @document_model;
#     foreach my $d (@subdir)
#     {
#         print STDERR "$d: ";
#         my @ls = glob($d . "/*.model");
#         print STDERR scalar(@ls), " model files\n";
#         push @document_model, @ls;
#     }

#     die "unable to find document models at $DOCUMENT_MODELS_DIR" unless (scalar @document_model);

#     # call P_coll()
#     print STDERR "Calculating collection model logprob (to be interpolated)";
#     my @r = P_coll($text); # return value already saved in global @collection_seq
#     my $coll_logprob = lambda_sum2(1, \@r, \@r);
#     print STDERR $coll_logprob, "\n";

#     # for each model, call P_doc()
#     print STDERR "Calculating per-document model logprobs on, ", scalar(@document_model), " files\n";
#     my $count = 0;
#     foreach (@document_model)
#     {
#         my $logprob = P_doc($_);
#         $result{$_} = $logprob;

#         print STDERR "." unless ($count++ % 100);
#     }

#     print STDERR  "\n";
#     return %result;
# }

# internal function that records collection probability per words
# (model to be interpolated for each P_doc model, used within P_t)
sub P_coll
{
    # sanity check
    die "unable to find collection model file $COLLECTION_MODEL\n" unless (-r $COLLECTION_MODEL);
    my $sent = $_[0];

    # if in cache. 
    if ($USE_CACHE_ON_COLL_MODEL)
    {
        if (defined $COLL_MODEL_CACHE{$sent})
        {
            # d out
            print STDERR "(result found in cache)\n"; 
            my $val = $COLL_MODEL_CACHE{$sent};  
            my @arr = split ("\n", $val); 
            @collection_seq = @arr; 

            # need to do this, since P_doc relies on this 
            # (ugly code, I know, but)
            make_ngram_input_file($sent); 

            return @collection_seq; 
        }
    }

    # from srilm_call.pm
    my @out = call_ngram($COLLECTION_MODEL, "", $sent);
    @collection_seq = read_debug3_p(@out);

    if ($USE_CACHE_ON_COLL_MODEL)
    {
        # store it in the cache. 
        my $val = join("\n", @collection_seq); 
        $COLL_MODEL_CACHE{$sent} = $val; 
    }
    return @collection_seq;
}

# internal function, that assumes previous call on P_coll
# (P_coll must be called before calling P_doc) 
sub P_doc
{
    # arg[0]: document model path
    die "Calling P_doc requires previos call of P_coll" unless (scalar @collection_seq);
    die "Unable to open path $_[0]" unless (-r $_[0]);

    my @doc_seq = read_debug3_p(call_ngram($_[0]));
    #print "\n", (scalar @doc_seq), "\t", (scalar @collection_seq), "\n";
    # if ($EQUALIZE_ENDS == 1)
    # { # </s> last item is always the end sentence </s>. 
    #     $doc_seq[-1] = $collection_seq[-1]; 
    # }
    # elsif ($EQUALIZE_ENDS == 2)
    # { # . -> </s> 
    #     $doc_seq[-1] = $collection_seq[-1]; 
    #     $doc_seq[-2] = $collection_seq[-2]; 
    # }

    my $logprob = lambda_sum2($LAMBDA, \@doc_seq, \@collection_seq);
    return $logprob;
}

# a utility function that outputs a hash into a file. 
# (used for outputting per-document weights and probabilities)
sub export_hash_to_file
{
    # does nothing if DEBUG flag is not set. 
    return unless ($DEBUG);
    my %h = %{$_[0]};
    my $filename = $_[1];
    open FILE, ">", $filename;

    if ($DEBUG == 1 )
    {
        foreach (sort keys %h)
        {
            print FILE "$_ \t $h{$_}\n";
        }
    }
    else #elsif ($DEBUG == 2)
    {
        foreach (sort {$h{$b} <=> $h{$a}} keys %h)
        {
            print FILE "$_ \t $h{$_}\n";
        }
    }
    close FILE;
}

# internal utility method that returns all subdirs upto 
# certain depth. 
# used by P_t
sub get_subdirs
{
    # get_subdir("./somepath") will return all its subdirs,
    # (up to depth 2), including top dir itself.

    my $toppath = $_[0];
    opendir (my $dh, $toppath) or croak "can't open dir $_[0]";
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
    return @subdir;
}


# internal method that enables perl code to access SOLR query 
# result. 
# usage:  sole_query($text_str)
# argument: (already tokenized) one string; used as a set of words to query. 
# returns: all document ids where the document has the word(s). 
#          as ($aref_doc_ids);
sub solr_query
{
    my $query_str = $_[0];

    # prepare query terms
    $query_str =~ s/\"//g;
    $query_str =~ s/\'//g; # cases like "Amy's" can't happen, if it is properly tokenized. And all target documents are already tokenized. So.
    # $query_str =~ s/ and //g; # for special relation terms for Plucene::SEARCH::QUERY.
    # $query_str =~ s/ or //g;
    # $query_str =~ s/ not //g;
    # $query_str =~ s/ phrase //g;
    $query_str =~ s/,//g;
    $query_str =~ s/\n/ /g;

    my @term_list = split(/\s+/, $query_str);

    # prepare solr, and the query
    my $solr = WebService::Solr->new($SOLR_URL);
    my $query = WebService::Solr::Query->new ( { -default => [@term_list] });
    my $query_options =  {rows => "$APPROXIMATE_WITH_TOP_N_HITS"}; # maximum number of returns

    # sending query, if the port is not accessible, it will raise carp die
    my $response = $solr->search ( $query, $query_options );


    my @result_id;
    for my $doc ( $response->docs ) {
        # the response docs are already sorted with relevancy.
        push @result_id, $doc->value_for('id');
    }

    return \@result_id;
}

# gets one log prob, returns perplexity of that.
# For example, calc_ppl(-19.55, 6, 1) means
# logprob was -19.55, non OOV number of words were 6, and one sentence.
# it will return per-word PPL value of this logprob. 
sub calc_ppl {
    my $logprob = shift;
    my $count_non_oov_words = shift;
    my $count_sentences = shift;
    print STDERR "($logprob, $count_non_oov_words, $count_sentences)\n";
    # ppl = 10^(-logprob/(words - OOVs + sentences))
    # ppl1 = 10^(-logprob/(words - OOVs))
    my $ppl = 10 ** (- $logprob / ($count_non_oov_words + $count_sentences));
    return $ppl;
}

# returns number of sentences within the (one) input string. 
sub count_sentence {
    # count sentence of input.
    my $text = shift;

    # (as count of \n + 1?)
    # - clear ending whitespaces including newline 
    $text =~ s/\s+$//; 
    # - count number of \n. 
    my $count = $text =~ tr/\n//; 
    return ($count + 1);
}

# utility method that gets log10 
sub log10 {
    my $n = shift;
    return log($n)/log(10);
}

# utility method that counts number of 0s in an array 
sub count_non_zero_element
{
    my $count = 0;
    foreach (@_)
    {
        $count ++ unless ($_ == 0);
    }
    return $count;
}

# utility method that gets full path, from docid 
# note that SOLR index only stores (unique) docid, not full path. 
# thus this method is needed to track actual model (or document) from 
# SOLR search hits. 

sub get_path_from_docid
{
    # note that : our $DOCUMENT_MODELS_DIR = "./models/document";
    my $id = shift;
    die "invalid doc id: %id" unless ($id);

    $id =~ /(.+?)_(.+?)_(\d\d\d\d)(\d\d)(\d\d)\./;
    my $agency = $1;
    my $lang = $2;
    my $year = $3;
    my $month = $4;
    my $date = $5;

    die "something wrong with the id: $id" unless ($date);

    my $path = "/" . (lc ($agency)) . "_" . (lc ($lang)) . "_" . $year . $month . "/" . $date . "/";
    $path = $DOCUMENT_MODELS_DIR . $path . $id;
    return $path;
}


###
### Main access methods 
### 

## SOLR based P_t_index() 
## Gets one text, returns per-document probability over the documents. 
sub P_t_index
{
    # argument: text, lambda, collection model path, document model glob
    # out: a hash (model name, prob of given text produced from the model)

    my %result; # $result{"model_id"} = log prob of $text from 'model_id'

    # argument copy & sanity check
    my $text = $_[0];
    die unless ($text);
    if ($_[1]) { # lambda
        die unless ($_[1] >=0 and $_[1] <= 1);
        $LAMBDA = $_[1];
    }
    if ($_[2]) { # collection model (single file)
        die "unable to open collection model file" unless (-r $_[2]);
        $COLLECTION_MODEL = $_[2];
    }
    if ($_[3]) { # document model path
        die "document model path does not exist" unless (-e $_[3]);
        $DOCUMENT_MODELS_DIR = $_[3];
    }

    my $hits_aref = solr_query($text);
    print STDERR "Search hits returned.\n";

    # sanity check
    my $hit_size = scalar (@{$hits_aref});
    unless ($hit_size)
    {
	warn "$text resulted no hits in SOLR index\n";
	warn "Probably non-text. Passing this one\n";
	return undef;
    } 
    #my $total_doc_size; #deprecated. remove when all code ready.

    # prepare list of models
    my @document_model;

    if ( $APPROXIMATE_WITH_TOP_N_HITS > 0 )
    {   # use top N only.
        my $n = 0;
        foreach (@{$hits_aref}) # hits_aref is already sorted with search hit score, top first.
        {
            my $docid = $_;
            my $doc_full_path = get_path_from_docid($docid);
            push @document_model, ($doc_full_path . ".model");
            $n++;
            last if ($n >= $APPROXIMATE_WITH_TOP_N_HITS);
        }
    }
    else
    {   # use all of them.
        foreach (@{$hits_aref})
        {
            my $docid = $_;
            my $doc_full_path = get_path_from_docid($docid);
            push @document_model, ($doc_full_path . ".model");
        }
    }

    undef $hits_aref; # not really needed but.

    # call P_coll()
    print STDERR "Calculating collection model logprob (to be interpolated)";
    my @r = P_coll($text); # return value already saved in global @collection_seq
    my $coll_logprob = lambda_sum2(1, \@r, \@r);
    print STDERR $coll_logprob, "\t";
    print STDERR "Perplexity is ", calc_ppl($coll_logprob, count_non_zero_element(@collection_seq) - count_sentence($text), count_sentence($text)), "\n";

    # for each model, call P_doc()
    print STDERR "Calculating per-document model logprobs from ", scalar(@document_model), " files \n";

    # generate the threads, and run them with 1/number_thread array parts.
    my @thread;
    my $n = int ((scalar (@document_model)) / ($NUM_THREAD+0.0));
    my $start = 0;
    my $end = $n-1;

    for (my $i=0; $i < $NUM_THREAD; $i++)
    {
        # dcode
        #print STDERR "$start - $end\n";
        #print STDERR "$document_model[$start] - $document_model[$end]\n";

        ($thread[$i]) = threads->create(\&P_d_runner, @document_model[$start .. $end]); # () needed: array context. see http://perldoc.perl.org/threads.html#THREAD-CONTEXT

        # update start-end for the next array
        $start += $n;
        $end = $start + $n - 1;
        $end = ((scalar @document_model) -1) if (($i+1) == $NUM_THREAD -1); # last part special case
    }

    # wait for threads to end.
    my %parts;
    for (my $i=0; $i < $NUM_THREAD; $i++)
    {
        my %r = $thread[$i]->join();
        #print $r[0], "\t", $r[1], "\n";
        %parts = (%parts, %r);
    }
    # sum up the results from the thread
    %result = %parts;

    # for debug code
    my $max_prob = P_doc($document_model[0]);
    my $cut_prob = 0;
    #if ($APPROXIMATE_WITH_TOP_N_HITS < (scalar @document_model))
    my $last = $APPROXIMATE_WITH_TOP_N_HITS -1;
    $last = ($hit_size - 1) if ($last > ($hit_size - 1));
    $cut_prob = P_doc($document_model[$last]);

    # now, fill in the prob of "no-hit" document models
    # first, calculate the minimum no-hit prob.
    my %final_result;
    my $min_prob;

    # if ($NOHIT_L0_FILL)
    # {
    #    $min_prob = $coll_logprob;
    # }
    # else
    {
       my @t;
       push @t, 0 foreach (@r);
       $min_prob = lambda_sum2($LAMBDA, \@t, \@r);
    }

    # get all docmodel list
    print STDERR "\nCalculating per-doc prob for hits done. Filling in default_prob for no-hits document models\n";
    print STDERR "(fillvalue is: $min_prob)\t (1stprob was: $max_prob)\t (cutpoint has: $cut_prob)\n";
    if ($max_prob < $cut_prob)
    {
        print STDERR "(1stprob < cutprob: Okay, but might mean cut was a bit pre-mature)\n";
    }

    if ( ((scalar @all_model) == 0) or ($all_model_top_path ne $DOCUMENT_MODELS_DIR)) # cached value not exist, or different
    {
        @all_model = ();
        my @subdir = get_subdirs($DOCUMENT_MODELS_DIR);
        print STDERR "$DOCUMENT_MODELS_DIR has ", scalar (@subdir), " dirs (subdirs + itself) to follow;\n";
        foreach my $d (@subdir)
        {
            #print STDERR "$d: ";
            my @ls = glob($d . "/*.model");
            #print STDERR scalar(@ls), " model files\n";

            # converting file name into standard form.
            # so it is compatible with the file name in Index.
            foreach (@ls)
            {
                s/\/\.\//\//g;  # /./ -> /
            }
            push @all_model, @ls;
        }
        $all_model_top_path = $DOCUMENT_MODELS_DIR;
    }

    #print "$_ \n" foreach (@document_model);
    #print "===***===\n"
    #print "$_ \n" foreach (@all_model);
    foreach (@all_model)
    {
        if ($result{$_})
        {
            $final_result{$_} = $result{$_} if ($result{$_});
        }
        else
        {
            $final_result{$_} = $min_prob;
        }
    }
    # sanity check
    foreach (keys %result)
    {
        unless ($final_result{$_} == $result{$_}) #(exists $final_result{$_})
        {
            die "Internal sanity check failure: model result found by index-fetching not found in the final result. File name match failure? Bad code? (Blame Gil for this.)\n"
        }
    }

    # Debug CODE
    # cutpoint average & all average
    if (0) #($DEBUG)
    {
        my @ca = values %result;
        print "average logprob from the cut point ", scalar (@ca), " doc-models:", mean(\@ca), "\n";
        my @aa = values %final_result;
        print "average logprob from the all ", scalar(@aa)," (approximated, min-fill) doc-models:", mean(\@aa), "\n";
    }

    # done. return the result.
    print STDERR "Per model probability now completed\n";
    return \%final_result;
}

# # The main work method (NOTE: deprecated) 
# # (SOLR-based approximated) P(text | context). 
# # gets text, context, and returns the conditional probability of P(text | context).  
# sub P_h_t_index
# {
#     # argument: hypothesis, text, lambda, collection model path, document model top path
#     # output (return):
#     # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ).

#     # argument check
#     my @args = @_;
#     my $hypothesis = shift @args;
#     my $text = shift @args;
#     die "Something wrong, either hypothesis or text is missing\n" unless ($hypothesis and $text);

#     # calculate P(t) for each document model
#     print STDERR $text, "\n";
#     my $text_per_doc_href = P_t_index($text, @args); # remaining @args will be checked there
#     # check null result 
#     unless ($text_per_doc_href)
#     {
# 	return undef; # unable to process. probably non-words. (e.g. "..."). 
#     }
#     # calculate P(t) overall
#     my $P_t;
#     my $nonOOV_len_t = count_non_zero_element (@collection_seq) - count_sentence($text);

#     print STDERR "P(t) is : ";
#     {
#         my @t = values %{$text_per_doc_href};
#         $P_t = mean(\@t); # (on uniform P(d) )
#     }
#     my $P_pw_t = $P_t / $nonOOV_len_t;
#     print STDERR "$P_t, length $nonOOV_len_t, normalized P_pw(t) is: $P_pw_t,";
#     print STDERR "Perplexity is ", calc_ppl($P_t, $nonOOV_len_t, count_sentence($text)), "\n";
#     # dcode
#     export_hash_to_file($text_per_doc_href, "Pt_per_doc.txt");

#     # calculate P(h) for each model
#     print STDERR $hypothesis, "\n";
#     my $hypo_per_doc_href = P_t_index($hypothesis, @args);
#     # check null result 
#     unless ($hypo_per_doc_href)
#     {
# 	return undef; # unable to process. probably non-words. (e.g. "..."). 
#     }

#     # calculate P(h) overall
#     my $P_h;
#     my $nonOOV_len_h = count_non_zero_element(@collection_seq) - count_sentence($hypothesis);

#     print STDERR "P(h) is : ";
#     {
#         my @h = values %{$hypo_per_doc_href};
#         $P_h = mean(\@h); # (on uniform P(d) )
#     }
#     my $P_pw_h = $P_h / $nonOOV_len_h;
#     print STDERR "$P_h, length $nonOOV_len_h, normalized P_pw(h) is: $P_pw_h\n";
#     print STDERR "Perplexity is ", calc_ppl($P_h, $nonOOV_len_h, count_sentence($hypothesis)), "\n";
#     # dcode
#     export_hash_to_file($hypo_per_doc_href, "Ph_per_doc.txt");

#     # calculate P(h|t,d) for each model
#     # note this %weighted is *non-normalized weight* (for evidence)
#     # and not the final prob.

#     if ($DEBUG)
#     {
#         print STDERR "calculating weighted contribution (evidence) for each doc\n";
#     }

#     my %weighted;
#     my @text;
#     my @hypo;
#     {
#         foreach (keys %{$text_per_doc_href})
#         {
#             if ($DEBUG) # do only when debug flag is up
#             {
#                 $weighted{$_} = $text_per_doc_href->{$_} + $hypo_per_doc_href->{$_};
#             }
#             push @text, $text_per_doc_href->{$_};
#             push @hypo, $hypo_per_doc_href->{$_};
#         }
#     }
#     if ($DEBUG) # do only when debug flag is up.
#     {
#         # dcode
#         export_hash_to_file(\%weighted, "PtPh_per_doc.txt");
#     }

#     # calculate P(h|t) overall (that is, P(h|t,d))
#     # WARNING: we made sure in the previous step, @text and @hypo sorted on the same
#     # list of files. That means that $text[$n] and $hypo[$n] came from the same doc.
#     # This must be guaranteeded!
#     print STDERR "Calculating the weighted sum\n";
#     my $P_h_given_t = weighted_sum(\@text, \@hypo);
#     #print @text, @hypo;     #dcode
#     my $P_pw_h_given_t = $P_h_given_t / $nonOOV_len_h;
#     print STDERR "P(h|t) is (logprob):  $P_h_given_t \t P_pw(h|t) is $P_pw_h_given_t\n";
#     print STDERR "Perplexity is ", calc_ppl($P_h_given_t, $nonOOV_len_h, count_sentence($hypothesis)), "\n"; 
#     # calculate P(h|t) / P(h), as supporting measure.
#     my $gain = ($P_h_given_t - $P_h);

#     print STDERR "Calculating the weighted sum for P(t|t)\n";
#     my $P_t_given_t = weighted_sum(\@text, \@text);
#     my $P_pw_t_given_t = $P_t_given_t / $nonOOV_len_t;

#     my $per_word_minus = (10 ** $P_pw_h_given_t) - (10 ** $P_pw_h);
#     my $bb_value = 10 ** ($P_pw_h_given_t - $P_pw_t_given_t);
# #    print STDERR "P(t|t) is: $P_t_given_t, \t P_pw(t|t) is: $P_pw_t_given_t\n";
#     print STDERR "===\n";
#     print STDERR "1] P_pw(h|t) / P_pw(t|t) (BB) is: ", $bb_value, "\n";
#     print STDERR "2] log (P(h|t) / P(h)) (PMI) is: ", $gain, "\n";
#     print STDERR "3] P_pw(h|t) (per word P(h|t)) is: ", $P_pw_h_given_t, "\n";
#     print STDERR "4] P_pw(h|t) - P_pw(h) (MINUS) is : ", $per_word_minus, "\n";
#     print STDERR "(all calculated from ", scalar(@text), " doc_models, by approx with $APPROXIMATE_WITH_TOP_N_HITS top hits)\n";
#     print STDERR "===\n";

#     # ( P(h|t) / P(h) as non-log, P(h|t) as log, P(h) as log, P(t) as log, evidences of un-normalized contributions as the hash reference ).

#     #return ($gain, $P_h_given_t, $P_h, $P_t, {%weighted});

#     # returning
#     # BB, PMI, P_pw_h_given_t, P_pw(h|t) - P_pw(h), len_t, len_h, evidences_hash_ref
#     return ($bb_value, $gain, $P_pw_h_given_t, $per_word_minus, $nonOOV_len_t, $nonOOV_len_h, $P_h_given_t, $P_t, $P_h, {%weighted});
#     #return ($bb_value, $gain, $P_pw_h_given_t, ((10**$P_h_given_t) - (10**$P_h)), $nonOOV_len_t, $nonOOV_len_h, $P_h_given_t, $P_t, $P_h, {%weighted});
# }


# "streamlined", the main work method. 
# (SOLR-based approximated) P(text | context). 
# gets text, context, and returns the conditional probability of P(text | context). 
# This method is the *latest* one. 

# argument: hypothesis, text, lambda, collection model path, document model top path, [optional] instance_id
# (instance_id is needed to be run with multiple instances. -- used to create SRILM input file) 

# output (returns in one array):
# P_collection(h), P_model(h), P_model(h|t), count_nonOOV_words, count_sentence,
# P_collection(t), P_model(t), count_nonOOV_words (t), count_sentence (t)
# KL_divergence(h||t), KL_divergence(t||h) 

sub condprob_h_given_t
{
    # argument check
    my @args = @_;
    my $instance_id = $args[5]; 

    my $hypothesis = shift @args;
    my $text = shift @args;
    die "Something wrong, either hypothesis or text is missing\n" unless ($hypothesis and $text);

    if ($instance_id)
    {
	#$__global_instance_id = $instance_id; # maybe not really needed.
	set_ngram_input_file("./models/ngram_input.txt." . $instance_id); 
    }

    # calculate P(t) for each document model
    print STDERR $text, "\n";
    my $text_per_doc_href = P_t_index($text, @args); # remaining @args will be checked there
    unless ($text_per_doc_href)
    {
	return undef; # unable to process. probably non-words. (e.g. "..."). 
    }

    my $P_t_coll = lambda_sum2(1, \@collection_seq, \@collection_seq);

    # calculate P(t) overall
    my $P_t;
    my $nonOOV_len_t = count_non_zero_element (@collection_seq) - count_sentence($text);

    # too short, or all OOV exception case 
    unless ($nonOOV_len_t)
    {
	return undef; #unable to process. probably all OOV case.
    }

    print STDERR "P(t) is : ";
    {
        my @t = values %{$text_per_doc_href};
        $P_t = mean(\@t); # (on uniform P(d) )
    }
    my $P_pw_t = $P_t / $nonOOV_len_t;
    print STDERR "$P_t, length $nonOOV_len_t, normalized P_pw(t) is: $P_pw_t,";
    print STDERR "Perplexity is ", calc_ppl($P_t, $nonOOV_len_t, count_sentence($text)), "\n";
    # dcode
    export_hash_to_file($text_per_doc_href, "Pt_per_doc.txt");

    # calculate P(h) for each model
    print STDERR $hypothesis, "\n";
    my $hypo_per_doc_href = P_t_index($hypothesis, @args);
    unless ($hypo_per_doc_href)
    {
	return undef; # unable to process. probably non-words. (e.g. "..."). 
    }

    # calculate P(h) overall
    my $P_h;
    my $nonOOV_len_h = count_non_zero_element(@collection_seq) - count_sentence($hypothesis);
    unless ($nonOOV_len_h)
    {
	return undef; # unable to process, probably all OOV case. 
    }

    my $P_h_coll = lambda_sum2(1, \@collection_seq, \@collection_seq); 

    print STDERR "P(h) is : ";
    {
        my @h = values %{$hypo_per_doc_href};
        $P_h = mean(\@h); # (on uniform P(d) )
    }
    my $P_pw_h = $P_h / $nonOOV_len_h;

    print STDERR "$P_h, length $nonOOV_len_h, normalized P_pw(h) is: $P_pw_h\n";
    print STDERR "Perplexity is ", calc_ppl($P_h, $nonOOV_len_h, count_sentence($hypothesis)), "\n";
    # dcode
    export_hash_to_file($hypo_per_doc_href, "Ph_per_doc.txt");

    # calculate P(h|t,d) for each model
    # note this %weighted is *non-normalized weight* (for evidence)
    # and not the final prob.

    if ($DEBUG)
    {
        print STDERR "calculating weighted contribution (evidence) for each doc\n";
    }

    my %weighted;
    my @text;
    my @hypo;
    {
        foreach (keys %{$text_per_doc_href})
        {
            if ($DEBUG) # do only when debug flag is up
            {
                $weighted{$_} = $text_per_doc_href->{$_} + $hypo_per_doc_href->{$_};
            }
            push @text, $text_per_doc_href->{$_};
            push @hypo, $hypo_per_doc_href->{$_};
        }
    }
    if ($DEBUG) # do only when debug flag is up.
    {
        # dcode
        export_hash_to_file(\%weighted, "PtPh_per_doc.txt");
    }

    # calculate P(h|t) overall (that is, P(h|t,d))
    # WARNING: we made sure in the previous step, @text and @hypo sorted on the same
    # list of files. That means that $text[$n] and $hypo[$n] came from the same doc.
    # This must be guaranteeded!
    print STDERR "Calculating the weighted sum\n";
    my $P_h_given_t = weighted_sum(\@text, \@hypo);
    my $KLD_h_t = KL_divergence(\@text, \@hypo); 
    my $KLD_t_h = KL_divergence(\@hypo, \@text); 
    #print @text, @hypo;     #dcode
    my $P_pw_h_given_t = $P_h_given_t / $nonOOV_len_h;
    my $count_h_sent = count_sentence($hypothesis); 
    my $count_t_sent = count_sentence($text); 
    print STDERR "P(h|t) is (logprob):  $P_h_given_t \t P_pw(h|t) is $P_pw_h_given_t\n";
    print STDERR "Perplexity is ", calc_ppl($P_h_given_t, $nonOOV_len_h, $count_h_sent), "\n"; 

    # collection prob, model prob (Without context), model prob with cond, wcount, scount 
    print STDERR "$P_h_coll, $P_h, $P_h_given_t, $nonOOV_len_h, $count_h_sent\n"; 
    print STDERR "$KLD_h_t, $KLD_t_h\n"; 

# return in this order: 
# P_collection(h), P_model(h), P_model(h|t), count_nonOOV_words, count_sentence,
# P_collection(t), P_model(t), count_nonOOV_words (t), count_sentence (t), 
# KLD(h||t), KLD(t||h), 


    return ($P_h_coll, $P_h, $P_h_given_t, $nonOOV_len_h, $count_h_sent, 
            $P_t_coll, $P_t, $nonOOV_len_t, $count_t_sent, $KLD_h_t, $KLD_t_h); 
}


# this meethod 
sub P_t_joint
{
   my $text = $_[0];
   print STDERR $text, "\n";
   my $text_per_doc_href = P_t_index(@_);
   unless ($text_per_doc_href)
   {
      return undef;
   }

    my $P_t;
    my $nonOOV_len_t = count_non_zero_element (@collection_seq) - count_sentence($text);

    # too short, or all OOV exception case 
    unless ($nonOOV_len_t)
    {
	return undef; #unable to process. probably all OOV case.
    }

    print STDERR "P(t) is : ";
    {
        my @t = values %{$text_per_doc_href};
        $P_t = mean(\@t); # (on uniform P(d) )
    }
    my $P_pw_t = $P_t / $nonOOV_len_t;
    my $count_t_sent = count_sentence($text); 
    print STDERR "$P_t, length $nonOOV_len_t, normalized P_pw(t) is: $P_pw_t,";
    print STDERR "Perplexity is ", calc_ppl($P_t, $nonOOV_len_t, $count_t_sent), "\n";
    # dcode
    export_hash_to_file($text_per_doc_href, "Pt_per_doc.txt");
    my $P_t_coll = lambda_sum2(1, \@collection_seq, \@collection_seq);

    return ($P_t_coll, $P_t, $nonOOV_len_t, $count_t_sent);
}

our $total_doc_count = 0; 

sub set_total_doc_count
{
    my $solr = WebService::Solr->new($SOLR_URL);
    my $query = WebService::Solr::Query->new ( {-default => \'*'} ); #'})
    my $response = $solr->search ( $query );
    
    my $count_string = $response->content->{response}->{numFound}; 
    $total_doc_count = ($count_string + 0); 
    print STDERR "total doc count (of SOLR collection): $total_doc_count\n"; 
}


# word-level pmi
# PMI (word1, word2) 
# returns PMI value from SOLR indexed corpus 
# log (   (count(w1,w2) / N)  /  count(w1)/N * count(w2)/N  )

sub wordPMI
{
    # set total_doc_count, if not set yet. (N of equation) 
    if ($total_doc_count == 0)
    {
        set_total_doc_count(); 
    }
 
    my $word1 = $_[0]; 
    my $word2 = $_[1]; 
    die ("condprob::wordPMI: needs two words; word1 was \'$word1\', word2 was \'$word2\'") unless (defined($word2)); 

    my $result; 

    # log ((count(w1,w2) / N)  /  count(w1)/N * count(w2)/N  )
    my $joint = get_document_count($word1, $word2) / $total_doc_count; 
    my $p1 = get_document_count($word1) / $total_doc_count; 
    my $p2 = get_document_count($word2) / $total_doc_count; 
    # exceptional case. 
    if ( ($p1 == 0) or ($p2 ==0) or ($joint == 0))
    {
        # no such word; (one or more OOV) we treat PMI of such case as 0. 
        return 0; 
    }
    my $val = $joint / ($p1 * $p2); 

    # # count(w1,w2) * N  /  count(w1) count(w2)
    # my $joint_count = get_document_count($word1, $word2);
    # my $count1 = get_document_count($word1); 
    # my $count2 = get_document_count($word2); 
    
    # my $val = ($joint_count * $total_doc_count) / ($count1 * $count2);
    return log10($val); 
}

# utility for word-PMI
# throws query, get document count. 
# queries are thrown as "AND"
# works only up to two terms 
sub get_document_count
{
    my @term_list = @_;

    die "can't do more than two terms" if ((scalar @term_list) > 2);
    die "can't work with no terms" if ((scalar @term_list) == 0); 
    # prepare solr, and the query
    my $solr = WebService::Solr->new($SOLR_URL);
    my $query; 
    #my $query = WebService::Solr::Query->new ( {-default => [@term_list]} ); 
    #$query = WebService::Solr::Query->new ( {-default => \'gold AND silver'} ); 
    if ((scalar @term_list) == 1)
    {
        $query = WebService::Solr::Query->new ( {-default => $term_list[0] } );
    }
    else
    {
        $query = WebService::Solr::Query->new ( {-default => $term_list[0], article=>$term_list[1] } );
    }

    # hmm. let's don't limit this. 
    #my $query_options =  {rows => "$APPROXIMATE_WITH_TOP_N_HITS"}; # maximum number of returns

    # sending query, if the port is not accessible, it will raise carp die
    my $response = $solr->search ( $query );

    my $count_string = $response->content->{response}->{numFound}; 
    my $doc_count = ($count_string + 0); 

    return $doc_count; 
}

# word level conditional probability 
# P(word1 | word2) where 
#  word_condprob(word1, word2) 

sub word_condprob
{
    my $word1 = $_[0]; 
    my $word2 = $_[1]; 

    my $count_both = get_document_count($word1, $word2); 
    my $count_word2 = get_document_count($word2); 
    my $count_word1 = get_document_count($word1); 
 
    if (($count_word2 == 0) or ($count_both == 0) or ($count_word1 == 0))
    {
        return 0; 
    }

    # sanity check 
    die ("integrity failure: $count_both, $count_word2, word1: $word1, word2: $word2") if ($count_both > $count_word2); 
    return ($count_both / $count_word2); 
}

##
## gets two sentences (N and M words) 
## calculates all_word to all_word PMI
## and then normalizes it with N * M
sub mean_allword_pmi
{
    my $sent1 = $_[0];  
    my $sent2 = $_[1]; 

    # get all words T
    # get all words H 
    my @sent1_words = split /\s+/, $sent1; 
    my @sent2_words = split /\s+/, $sent2; 
    
    # loop it, store each value 
    my @all_pmis; 
    foreach my $word1 (@sent1_words)
    {
        # skip if this is not a valid word (stopword, OOV) 
        next unless(get_document_count($word1)); 

        foreach my $word2 (@sent2_words)
        {
            # calc pmi and push 
            my $pmi = wordPMI($word1, $word2); 
            if ($pmi != 0)
            {
                # PMI as 0 (integer 0) means exceptional case, such as 
                # stop words, OOV, etc.  
                # we exclude 0 from the mean. 
                push @all_pmis, $pmi; 
                # dcode
                # print STDERR "$word1 -- $word2 : $pmi\n";             
            }
        }
        print STDERR "."; #progress dot 
    }
    print STDERR "\n"; 
    # sum and mean 
    my $sum = sum(@all_pmis); 
    my $average = $sum / scalar(@all_pmis); 

    return $average; 
}

## gets two sentences s1 & s2. 
## for each word in s2, gets best P(w2|w1) with a word from s1. 
## product best P(w2|w1) 
# TODO consider, (maybe?) 
#   adding idf-weighted sum (like that of PMI) as 3rd want-array return value
#   (by using something like @weight_each_h_word) 

sub product_best_word_condprob
{
    my $sentT = $_[0];  
    my $sentH = $_[1]; 

    # get all words T
    # get all words H 
    my @sentT_words = split /\s+/, $sentT; 
    my @sentH_words = split /\s+/, $sentH; 

    my %exist_in_t;
    $exist_in_t{$_} = 1 foreach (@sentT_words);
#    my %exist_in_h; 
#    $exist_in_h{$_} = 1 foreach (@sentH_words); 

    # for each H word, loop all T word 
    # store best value for each H word 
    my @best_val_each_H_word; 
    foreach my $word_H (@sentH_words)
    {
        my $best_prob = 0;  # non logprob. simply, 0~1 prob. 
        # skip if $word_H is OOV or stopword 
        unless(get_document_count($word_H))
        {
            push @best_val_each_H_word, 0; 
            next; 
        }

        if($exist_in_t{$word_H})
        {
            # the exact word exist in T. 
            # no need to proceed. assing 1 
            push @best_val_each_H_word, 1; 
            next; 
        }

        foreach my $word_T (@sentT_words)
        {
            # P(word1 | word2) where 
            my $prob = word_condprob($word_H,  $word_T); 
            if ($prob > $best_prob)
            {
                $best_prob = $prob; #update when better. 
                #dcode 
                print STDERR "update best prob for $word_H; with $word_T, $prob\n"; 
            }
        }
        push @best_val_each_H_word, $best_prob; 
    }

    # sanity check 
    die "sanity failure\n" if ((scalar (@best_val_each_H_word)) != (scalar (@sentH_words))); 

    # product, and normalize (by sent length) 
    my $final_logprob = 0; 
    my $count_effective_words =0; 
    foreach my $val (@best_val_each_H_word)
    {
        #dcode 
        print STDERR "$val,"; 
        # we silently ignore 0 prob. (OOV, or stopword) 
        next if ($val == 0); 

        $count_effective_words ++; 
        # log, and sum. (thus product) 
        my $logprob = log10($val); 
        #dcode
        #print STDERR "$logprob,"; 
        $final_logprob += $logprob; 
    }
    # normalize and return. 
    #dcode 
    print STDERR "\n"; 
    print STDERR "final log prob: $final_logprob / $count_effective_words\n"; 
    my $norm_final_logprob = $final_logprob / $count_effective_words; 
    if (wantarray())
    {
        return ($norm_final_logprob, $final_logprob); 
    }
    return $norm_final_logprob; 
    
}

##
##
sub idf_word($)
{
    if ($total_doc_count == 0)
    {
        set_total_doc_count(); 
    }

    my $word = $_[0]; 
    die "no term" unless(defined($word)); 
    
    my $c = get_document_count($word); 
    return log10( $total_doc_count / $c); 

}

##
## weighted mean best word pmi 
## This sub only does one direction. For bi-direction, call it twice 
## with reversed (e.g. (s1,s2), then (s2,s1) and took average) 
sub mean_best_wordPMI
{
    my $sentT = $_[0];  
    my $sentH = $_[1]; 

    # get all words T
    # get all words H 
    my @sentT_words = split /\s+/, $sentT; 
    my @sentH_words = split /\s+/, $sentH; 

    # for each H word, loop all T word 
    # store best value for each H word 
    my @best_val_each_H_word; 
    my @weight_each_H_word; 
    foreach my $word_H (@sentH_words)
    {
        my $best_pmi = 0;  # (independent) 
        # skip if $word_H is OOV or stopword 
        unless(get_document_count($word_H))
        {
            push @best_val_each_H_word, 0; 
            push @weight_each_H_word, 0; 
            next; 
        }

        foreach my $word_T (@sentT_words)
        {
            # PMI(word1;word2)
            my $pmi = wordPMI($word_H, $word_T); 
            if ($pmi > $best_pmi)
            {
                $best_pmi = $pmi; #update when better. 
                #dcode 
                print STDERR "update best PMI for $word_H; with $word_T, $pmi\n"; 
            }
        }
        push @best_val_each_H_word, $best_pmi; 
        my $weight = idf_word($word_H); 
        print STDERR "\tIDF weight of $word_H -- $weight\n"; 
        push @weight_each_H_word, $weight; 
        
    }

    # weighted average 
    die "something wrong!" unless (scalar(@weight_each_H_word) == scalar(@best_val_each_H_word)); #sanity check. 

    my $val_sum = 0; 
    my $weight_sum = 0; 
    for(my $i=0; $i < scalar(@weight_each_H_word); $i++)
    {
        $val_sum += ($best_val_each_H_word[$i]) * ($weight_each_H_word[$i]); 
        $weight_sum += $weight_each_H_word[$i]; 
        print STDERR "$best_val_each_H_word[$i]($weight_each_H_word[$i]) "; 
    }
    print STDERR "\n"; 

    my $weighted_mean = $val_sum / $weight_sum; 
    my $mean = ($val_sum / (scalar @weight_each_H_word)); 
    if (wantarray())
    {
        return ($mean, $weighted_mean); 
    }
    return $mean; 
}

# this sub calculates KL-divergence. 
# the sub is designed to be called within condprob_h_given_t()
#  
# INPUT: Two "log-probability (log10)" distributions; ($distribution_1, $distribution_2)
#        Two distributions as two array-references. 
#        (the two arrays (@{$_[0]} and @{$_[1]}) hold the same 
#         number of events, and each cell holds the probability for that event. ) 
#
# OUTPUT: D_{KL}(d-1 || d-2) 
#         (KL divergence of distribution-2 from distribution-1) 
# 
# KL divergence: 
#   "Kullback–Leibler divergence of Q from P, denoted DKL(P||Q), 
#    is a measure of the information lost when Q is used to approximate P." 
#    ( a measure of information loss, when Q is used to approximate P. )
#    ( how far Q is from P? ) 
# 
# Caclulated as the followings: 
# Let's call 
#   $distribution1->[i] as P(i) and $distribution2->[i] as Q(i). 
# then 
#    D_{kl} = sum_{i} ( ln (P(i) / Q(i))  P(i) )
# 
# Note that two conditions for KL_d should be always 
# satisfied. 
#  -a) Q(i) is never 0, or if Q(i)=0 then P(i) is also need to be 0. 
#      (which is generally true for all CLM models) 
#  -b) It must satisfy: sum_i(P(i)) = 1 and sum_i(Q(i)) = 1.  
#      
# Note that b) must be satisfied.  
# which means; 
#  $distribution_1 and $distribution_2 thus must be a proper P(d_i | text). 
#  (not that of P_doc_{i}(text)). 
# This code forces b) by normalize; assuming that the code is called 
# with P_doc{i} (text) on all i where i is each doc. 
# where ---  P(d_i | text) = P(text | d_i) / sum_alli( P(text | d_i) )

sub KL_divergence
{
    print STDERR "KLD calc ...\n"; 

    my @dist1 = @{$_[0]}; 
    my @dist2 = @{$_[1]}; 

    # integrity check 
    die "Sorry; KL_divergence can't be defined unless the event spaces are equal" unless (scalar (@dist1) == scalar(@dist2)); 

    # normalize (b, of above comment) 
    my $sum_logprob_dist1 = logprob_sumall(@dist1); 
    my $sum_logprob_dist2 = logprob_sumall(@dist2); 
    for (my $j=0; $j < scalar(@dist1); $j++)
    {
        $dist1[$j] = $dist1[$j] - $sum_logprob_dist1; 
        $dist2[$j] = $dist2[$j] - $sum_logprob_dist2; 
    }

    my $sum = 0; 
    for (my $i=0; $i < scalar (@dist1); $i++)
    {
        my $P_i_log = $dist1[$i]; # $distribution1->[i] 
        my $Q_i_log = $dist2[$i]; # $distribution2->[i] 

        # we convert it back to "normal probability (non log)" 
        # since the prob is P(d_i) and not that small... 
        # (also, sum on log-prob is expansive). 
        
        my $P_i = 10 ** ($P_i_log); 
        my $Q_i = 10 ** ($Q_i_log); 

        # log() here is ln; natural log 
        my $w = log($P_i) - log($Q_i); 
        my $val = $w * $P_i; 
        
        $sum += $val;         
    }
    return $sum; 
}




## Last 1; 
1;

__END__

=head1 NAME

(proto) condprob - a conditional probability calculation tools for SRILM Language Models.

=head1 SYNOPSIS

    use condprob qw(:DEFAULT $NUM_THREAD);

=head1 DESCRIPTION

well, some discription.


