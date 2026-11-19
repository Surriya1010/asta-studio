function varargout = asta(varargin)
  % ASTA Octave replacement. asta() opens menus; asta('project') creates data.
  % Call help asta_project / asta_controller / asta_plot for scripting.
  if nargin == 0
    f = asta_gui();
    if nargout > 0, varargout{1} = f; end
  else
    switch lower(varargin{1})
      case 'project', varargout{1} = asta_project(varargin{2:end});
      case 'models', varargout{1} = asta_models(varargin{2:end});
      case 'statistics', varargout{1} = asta_statistics(varargin{2:end});
      case 'load', varargout{1} = asta_load(varargin{2:end});
      case 'save', asta_save(varargin{2:end});
      case 'plot', varargout{1} = asta_plot(varargin{2:end});
      otherwise, error('ASTA:action','Unknown action. Use help asta.');
    end
  end
end
