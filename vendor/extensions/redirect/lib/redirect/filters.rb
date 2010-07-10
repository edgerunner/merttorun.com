module Redirect::Filters
  def redirect_if_listed
    redirection = Redirection.find_by_from_path request.path
    if redirection
      redirect_to redirection.to_path, :status => redirection.temporary ? 301 : 302 
    end
  end
end