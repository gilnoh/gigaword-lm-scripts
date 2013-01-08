% reference weighted sum, that relies on 
% octave (graded underflow) small numbers 
% (No log calc when mult/sum) 

% weighted gets an input matrix with two columns 
% column 1: document_prob 
% column 2: sequence_prob within that document.

function probsum = reference_weightedsum (X) 

Y = 10 .^ X; 
nonlog = (Y(:,1)' * Y(:,2)) 
log = log10(nonlog)
probsum = log; 


end

