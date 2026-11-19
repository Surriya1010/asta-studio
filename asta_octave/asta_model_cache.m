function value = asta_model_cache(action, key, value)
  % Bounded exact-value LRU; model objects retain their original realization.
  persistent keys values hits misses;
  if isempty(hits), keys={}; values={}; hits=0; misses=0; end
  switch action
    case 'clear', keys={}; values={}; hits=0; misses=0; value=[];
    case 'info', value=struct('hits',hits,'misses',misses,'entries',numel(keys),'capacity',12);
    case 'get'
      value=[];
      for j=1:numel(keys)
        if isequal(keys{j},key)
          value=values{j}; keys=[keys(j) keys(1:j-1) keys(j+1:end)];
          values=[values(j) values(1:j-1) values(j+1:end)]; hits=hits+1; return;
        end
      end
      misses=misses+1;
    case 'put'
      keys=[{key} keys]; values=[{value} values];
      keys=keys(1:min(12,numel(keys))); values=values(1:min(12,numel(values)));
    otherwise, error('ASTA:cache','Unknown cache action.');
  end
end
