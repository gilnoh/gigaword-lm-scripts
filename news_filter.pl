# this small script helps to remove non-news articles from
# gigaword .story files.

# note that Gigalword corpus holds many amount of non-news
# text, like summaries, or correspondance, even within the
# "story" types. Summaries, list items, and one liners (news
# flash) are the most common things that are not newses. 

# this short script collects "features" for training automatic
# filter. Its main features are very simple things: average length of
# sentences, number of sentences, number of unique token types (as
# percentage of total token counts).

# this script will show you the news for 15 lines, you answer
# it is truely a news or not. Then, it will mark it with "features"
# and your decisions, and the id.

# also, it can copy the files for you to cluster results (articles and
# non articles).

use warnings;
use strict;


# config/setting
our $COPY_FILE_TOO = 1;
our $YES_COPY_DIR="./yes/";
our $NO_COPY_DIR="./no/";


unless ($ARGV[0])
{
    die "requires arguments: > perl news_filter.pl [files to be filtered / feature extracted] \n";
}

my @files = @ARGV;

foreach my $filename (@files)
  {
    die "unable to read file $filename\n" unless (-r $filename);
    # we got one file; already tokenized and sentence splitted.
    my $raw_content;
    open INFILE, "<", $filename;
    $raw_content .= $_ while (<INFILE>);
    close INFILE;
    my @temp = split /\n/, $raw_content;
    my @sentences;
    foreach (@temp) # prepare text
      {
	#remove all empty lines, so "real lines only"
	next unless (/\S/); # next if whitespce only
	next unless (/\w/); # next if there's no alphanumeric char.
        push @sentences, $_;
      }

    # now @sentences holds all real sentences.

    # ask golds
    print STDERR "\n\n";
    print STDERR "===\n";
    print STDERR $filename, "\n";
    print_stderr_header(@sentences);
    print STDERR "===\n";

    print STDERR "(y / n) >";
    my $decision = <STDIN>;

    # get features.
    my ($avg_length_sent, $num_sent, $num_unique_token, $num_token, $ratio_unique_token) = extract_features(@sentences);

    print STDERR "avg count term per sent.: $avg_length_sent\n";
    print STDERR "total count sent.: $num_sent\n";
    print STDERR "num unique token: $num_unique_token\n";
    print STDERR "total count tokens: $num_token\n";
    print STDERR "ratio (type / tokens): $ratio_unique_token\n";
    print STDERR "decision: $decision";

    print "$filename, $avg_length_sent, $num_sent, $num_unique_token, $num_token, $ratio_unique_token, $decision";

    if ($COPY_FILE_TOO)
      {
        # copy the target files
        if ($decision =~ /y|Y/)
          {
            my $target_path = $YES_COPY_DIR;
            `cp $filename $target_path`;
          }
        else
          {
            my $target_path = $NO_COPY_DIR;
            `cp $filename $target_path`;
          }
      }
  }

sub print_stderr_header
  {
    my @sentences = @_;
    for (my $i=0; ( $i < 15 && $i < scalar(@sentences)); $i++)
      {
        print STDERR $sentences[$i], "\n";
      }
  }




sub extract_features
  {
    my @sent = @_;

    my $avg_length_sent;  # 1
    my $num_sent;         # 2
    my $num_unique_token; # 3
    my $num_token;        # 4
    my $ratio_unique_token; # 5

    $num_sent = scalar (@sent); #2 done
    $num_token = 0;
    my %types;
    foreach my $line (@sent)
      {
        my @tokens = split /\s/, $line;
        $num_token += scalar (@tokens); #4 update
        foreach (@tokens)
          {
            $types{$_} = 1;
          }
      }

    $num_unique_token = scalar( keys (%types)); #3 done
    $avg_length_sent = ($num_token / $num_sent); #1 done
    $ratio_unique_token = ($num_unique_token / $num_token); #5 done

    return ($avg_length_sent, $num_sent, $num_unique_token, $num_token, $ratio_unique_token);
  }
