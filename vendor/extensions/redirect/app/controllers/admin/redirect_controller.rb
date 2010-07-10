class Admin::RedirectController < Admin::ResourceController
  model_class Redirection
  
  responses do |r|
    r.create.default { announce_success; redirect_to admin_redirect_index_path }
    r.invalid.default {  announce_validation_errors; redirect_to admin_redirect_index_path }
  end
  
  private
  
  def announce_success
    flash[:notice] = 'Redirection created successfully'
  end
  
  def announce_validation_errors
    flash[:error] = "Please check your input: " + @redirection.errors.full_messages.to_sentence
  end  

end
