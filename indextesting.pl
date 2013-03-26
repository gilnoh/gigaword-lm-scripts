#!/usr/bin/perl

# test run on plucene 

use strict;
use feature ":5.10";

use Plucene; 
use Plucene::Document; 
use Plucene::Document::Field; 
use Plucene::Search::IndexSearcher; 
use Plucene::Analysis::SimpleAnalyzer; 
use Plucene::Analysis::Standard::StandardAnalyzer; 
use Plucene::Index::Writer; 
use Plucene::QueryParser; 


# indexing 
# "UnStored" will not store the data, but index the data. 
# "Text" will be indexed & stored. (thus retrived) 
# "UnIndexed" will be stored, but not indexed (nor tokenized). 
my $doc = Plucene::Document->new; 
$doc->add(Plucene::Document::Field->UnIndexed(id => "afp_2010_1")); 
$doc->add(Plucene::Document::Field->Text(text => "it was an airline accident")); 
#$doc->add(Plucene::Document::Field->UnStored(text => "airplane accident")); 

my $doc2 = Plucene::Document->new; 
$doc2->add(Plucene::Document::Field->UnIndexed(id => "afp_2010_2")); 
$doc2->add(Plucene::Document::Field->UnStored(text => "it is a airline strike")); 

# standard analyzer will remove some stop words (is, was) 
my $analyzer = Plucene::Analysis::SimpleAnalyzer->new();
#my $analyzer = Plucene::Analysis::Standard::StandardAnalyzer->new(); 
my $writer = Plucene::Index::Writer->new("my_index", $analyzer, 1);

$writer->add_document($doc);
$writer->add_document($doc2); 
undef $writer; # close
# die; 

# prepare query
my $parser = Plucene::QueryParser->new({
    analyzer => Plucene::Analysis::SimpleAnalyzer->new(),
#    analyzer => $analyzer, 
    default  => "text" # Default field for non-specified queries
				       });
#my $query = $parser->parse('text:"strike"');
#my $query = $parser->parse('text:"accident"');
#my $query = $parser->parse('text:"airline"'); 
my $query = $parser->parse('text:"is" text:"accident"'); 
# both document will be retrieved, "is" or "accident". (if is, is indexed, DefaultAnalyser will remove stop word is) 


# search 
my $searcher = Plucene::Search::IndexSearcher->new("my_index");

my @docs;
my $hc = Plucene::Search::HitCollector->new(collect => sub {
    my ($self, $doc, $score) = @_;
    push @docs, $searcher->doc($doc);
					    
					    });

$searcher->search_hc($query => $hc);

foreach my $doc (@docs)
{
    my Plucene::Document::Field @field = $doc->fields; 
    foreach (@field)
    {
	print "name: ", $_->name()," \tstring: ", $_->string(), "\n"; 
    }
}
