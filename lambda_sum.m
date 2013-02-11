function log_prob = lambda_sum(lambda, vectorL, vectorR)
% Lamda sum on probability (number, not log prob) sequence 
% this function gets two sequence of probabilities 
% and sum them into a single log probability. 

seq_prob = vectorL * lambda + vectorR * (1 - lambda); 
log_prob = sum(log10(seq_prob));  

% any of 0 in seq_prob will result in -INF. 
% TODO: 
% For now, -INF is not removed in this function. 
% (Maybe Calling side should check this, remove any 0,0 pairs?) 
