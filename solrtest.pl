# testing SOLR connection. 

use warnings; 
use strict; 

use WebService::Solr; 
use WebService::Solr::Document; 
use WebService::Solr::Query; 

# filled by BEGIN,  here doc 
my $article1; 
my $article2; 

my $id1 = 'AFP_ENG_20090501.0004.story'; 
my $id2 = 'AFP_ENG_20090501.0005.story'; 

# let's assume local host 
my $url = "http://localhost:9911/solr"; 

my $solr = WebService::Solr->new($url);

# prepare a few docs 
my $field1 = WebService::Solr::Field->new( id => $id1 );
my $field2 = WebService::Solr::Field->new( article => $article1 ); 

my $doc1 = WebService::Solr::Document->new($field1, $field2);

my $field3 = WebService::Solr::Field->new( id => $id2 ); 
my $field4 = WebService::Solr::Field->new( article => $article2 ); 

my $doc2 = WebService::Solr::Document->new($field3, $field4);  

my @docs; 
push @docs, $doc1;
push @docs, $doc2; 
 
$solr->add(\@docs); 
#$solr->add( $doc2 );

# my $response = $solr->search( $query );
# for my $doc ( $response->docs ) {
#     print $doc->value_for( $id );
#     print $doc->value_for( $name ); 
# }

#my $query = WebService::Solr::Query->new ( {-default => 'driver bus'} ); 
# --> this will search a "phrase"
# the following will search with "ORs"
my $query = WebService::Solr::Query->new ( { -default => ['driver', 'bus', 'stone'] }); 
my $query_options =  {rows => "10000"}; # maximum number of returns 

my $response = $solr->search ( $query, $query_options ); 
for my $doc ( $response->docs ) {
    print $doc->value_for( 'id' ), "\t";
    print $doc->value_for( 'article' ), "\n"; 
}


END {

#    $solr->delete_by_id($id1); 
#    $solr->delete_by_id($id2); 
}


BEGIN {

$article1 = <<'END1'; 
 racing : rachel alexandra notches crushing kentucky oaks victory rachel alexandra romped to a spectacular 20 1/4-length victory in the 500,000-dollar kentucky oaks on friday in a scintillating curtain-raiser to saturday 's kentucky derby . 

the filly 's performance no doubt left many derby contenders thankful that her connections had n't elected to run her in the first jewel in us flat racing 's triple crown , preferring to race her against other females rather than take on the country 's top colts in the kentucky derby . 

with jockey calvin borel aboard , rachel alexandra stalked gabby 's golden gal along the backstretch . 
when asked , she cruised effortlessy to the front and pulled away . 

she notched her fifth straight victory , with stone legacy second , and flying spur third . 

" she 's unbelievable , one of the best fillies i 've ever been on in my life , " borel said . 
" i 've never been on a horse like this . " 

the eve of the derby at churchill downs was marred by the death of stormalory , a three-year-old colt that was euthanized after breaking down during the 150,000 - dollar american turf stakes . 

stormalory , trained by bill mott and owned by sheikh mohammed of dubai , broke slowly under jockey julien leparoux in the 1 1/16-mile race before going down just before the far turn with an injury to his left front leg . 

sheikh mohammed has two horses entered in saturday 's kentucky derby - regal ransom and desert party . 

i want revenge , trained by jeff mullins and ridden by 19-year-old jockey joe talamo was the early favorite for the 1 1/4-mile run for the roses . 

pioneerof the nile , trained by bob baffert , and dunkirk were tabbed the co- second choice at 4-1 . 

the sentimental favorite is general quarters , a 20,000-dollar claimer owned and trained by 75-year-old former high scool principal tom mccarthy . 

" how cool would it be if he won ? " even baffert wondered . 

mccarthy was n't among those fretting over forecasts of rain , predicting his bluegrass stakes-winner would have no problem with a sloppy track . 

" he gallops over the mud almost like he does over the dry , " mccarthy said . 
" once he gets moving , he 's like a big train . 
he 's hard to stop . " 

only six horses in the full field of 20 have run on an off-track . 

among those who have n't are i want revenge , pioneerof the nile , and dunkirk .

END1


$article2 = <<'END2'; 
south korea reports first confirmed case of swine flu

south korea saturday reported its first confirmed case of swine flu , according to yonhap news agency . 

a 51-year-old nun , who has been quarantined since tuesday after returning from mexico , has the disease , an official at the health ministry told yonhap . 
she had been the nation 's first " probable " case of the new flu virus . 

" we confirmed the first probable patient was infected with the virus , " the official said on condition of anonymity . 

the nun was among three probable flu patients reported this week , yonhap said . 

the two others -- a 44-year-old woman and 57-year-old bus driver -- did not travel to affected countries , raising concerns the disease has passed from person to person in the country . 

the bus driver 's results were negative but tests are ongoing for the 44-year-old woman , who lived with the nun who was confirmed to be infected with type-a influenza , the official said , according to yonhap . 

among others . 


END2

}
