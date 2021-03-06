class ApplicationController < ActionController::Base
  protect_from_forgery

  SINGLE_USER_MODE_CONF_KEY = 'system.single_user_mode'

  def admin_authorization
    return false unless authenticate
    user = User.find(session[:user_id], :include => ['roles'])
    unless user.admin?
      flash[:notice] = 'You are not authorized to view the page you requested'
      redirect_to :controller => 'main', :action => 'login' unless user.admin?
      return false
    end
    return true
  end

  def authorization_by_roles(allowed_roles)
    return false unless authenticate
    user = User.find(session[:user_id])
    unless user.roles.detect { |role| allowed_roles.member?(role.name) }
      flash[:notice] = 'You are not authorized to view the page you requested'
      redirect_to :controller => 'main', :action => 'login'
      return false
    end
  end

  protected

  def authenticate
    unless session[:user_id]
      flash[:notice] = 'You need to login'
      if GraderConfiguration[SINGLE_USER_MODE_CONF_KEY]
        flash[:notice] = 'You need to login but you cannot log in at this time'
      end
      redirect_to :controller => 'main', :action => 'login'
      return false
    end

    # check if run in single user mode
    if GraderConfiguration[SINGLE_USER_MODE_CONF_KEY]
      user = User.find(session[:user_id])
      if user==nil or (not user.admin?)
        flash[:notice] = 'You cannot log in at this time'
        redirect_to :controller => 'main', :action => 'login'
        return false
      end
      return true
    end

    if GraderConfiguration.multicontests? 
      user = User.find(session[:user_id])
      return true if user.admin?
      begin
        if user.contest_stat(true).forced_logout
          flash[:notice] = 'You have been automatically logged out.'
          redirect_to :controller => 'main', :action => 'index'
        end
      rescue
      end
    end
    return true
  end

  def authorization
    return false unless authenticate
    user = User.find(session[:user_id])
    unless user.roles.detect { |role|
	role.rights.detect{ |right|
	  right.controller == self.class.controller_name and
          (right.action == 'all' or right.action == action_name)
	}
      }
      flash[:notice] = 'You are not authorized to view the page you requested'
      #request.env['HTTP_REFERER'] ? (redirect_to :back) : (redirect_to :controller => 'login')
      redirect_to :controller => 'main', :action => 'login'
      return false
    end
  end

  def verify_time_limit
    return true if session[:user_id]==nil
    user = User.find(session[:user_id], :include => :site)
    return true if user==nil or user.site == nil
    if user.contest_finished?
      flash[:notice] = 'Error: the contest you are participating is over.'
      redirect_to :back
      return false
    end
    return true
  end

end
