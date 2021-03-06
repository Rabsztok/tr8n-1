#--
# Copyright (c) 2013 Michael Berkovich, tr8nhub.com
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

class Tr8n::App::SettingsController < Tr8n::App::BaseController

  before_filter :validate_application_management

  def index
    if request.post?
      selected_application.name = params[:application][:name]
      selected_application.description = params[:application][:description]
      selected_application.url = params[:application][:url]
      selected_application.threshold = params[:application][:threshold]
      selected_application.translator_level = params[:application][:translator_level]
      selected_application.default_language = Tr8n::Language.by_locale(params["default_locale"])
      selected_application.save

      Tr8n::RequestContext.reset_container_application if selected_application.default?

      trfn("Application has been updated")
    end
  end

  def security

  end

  def logs
    @logs = Tr8n::Logs::Sync.where(:application_id=>selected_application.id).order("created_at desc").page(page).per(per_page)
  end

  def set_default_language
    redirect_back
  end

  def decorations
  end

  def select_decoration
    selected_application.decorator.select(params[:index])
    redirect_back
  end

  def decoration_modal
    @style = selected_application.decorator.css[params[:key]]

    if request.post?
      selected_application.decorator.css[params[:key]] = params[:style]
      selected_application.decorator.save
      trfn("Style has been updated")
      return redirect_to(:action => :decorations)
    end

    render :layout => false
  end

  def shortcuts
  end

  def shortcut_modal
    @shortcut = selected_application.shortcuts[params[:keys]] if params[:keys]
    @shortcut ||= {}

    @shortcut["keys"] = params[:keys]

    if request.post?
      selected_application.shortcuts.delete(params[:keys]) if params[:keys]
      selected_application.shortcuts[params[:shortcut][:keys]] = {
          "description" => params[:shortcut][:description],
          "script" => params[:shortcut][:script],
      }
      selected_application.save
      trfn("Shortcut has been updated")
      return redirect_to(:action => :shortcuts)
    end

    render :layout => false
  end

  def delete_shortcut
    selected_application.shortcuts.delete(params[:keys])
    selected_application.save
    return redirect_to(:action => :shortcuts)
  end

  def generate_secret
    selected_application.reset_secret!
    redirect_back
  end

  def features
  end

  def toggle_feature
    selected_application.toggle_feature(params[:key], params[:flag] == "true")
    render :text => {"result" => "Ok"}.to_json
  end

  def languages

  end

  def add_languages_modal
    if request.post?
      params[:locales].split(',').each do |locale|
        selected_application.add_language(Tr8n::Language.by_locale(locale))
      end
      return redirect_to(:action => :languages)
    end

    render :layout => false
  end

  def remove_language
    selected_application.remove_language(Tr8n::Language.by_locale(params[:lang]))
    render :json => {:success=>true}
  end

  def toggle_featured_language
    al = Tr8n::ApplicationLanguage.where(:application_id=>selected_application.id, :language_id => Tr8n::Language.by_locale(params[:lang]).id).first
    if al
      al.featured_index = (al.featured_index.nil? ? selected_application.featured_languages.count + 1 : nil)
      al.save
    end
    render :json => {:success=>true}
  end

  def featured_languages

  end

  def unfeature_language
    al = Tr8n::ApplicationLanguage.where(:application_id=>selected_application.id, :language_id => Tr8n::Language.by_locale(params[:lang]).id).first
    if al
      al.featured_index = nil
      al.save
    end
    redirect_back
  end

  def update_featured_languages_order
    params[:languages].each_with_index do |id, index|
      Tr8n::ApplicationLanguage.update_all({:featured_index => index+1}, {:id => id})
    end

    render :nothing => true
  end

  def delete_logo
    if selected_application.logo
      selected_application.logo.destroy
    end

    redirect_back
  end

  def upload_logo
    if selected_application.logo
      selected_application.logo.destroy
    end

    file = params[:files].first

    Tr8n::Media::Logo.create_from_file(selected_application, file.original_filename, File.read(file.tempfile))

    files = [{
        "name"=> file.original_filename
    }]

    render :json => {"files" => files}
  end

  def tokens
    @type = params[:type] || "data"
  end

  def token_modal
    @type = params[:type]
    @key = params[:key]
    @value = selected_application.tokens(@type)[@key]
    if request.post?
      selected_application.tokens(@type).delete(@key)
      selected_application.tokens(@type)[params[:new_key]] = params[:new_value]
      selected_application.save
      trfn("Token has been updated")
      return redirect_back
    end
    render :layout => false
  end

  def delete_token
    selected_application.tokens(params[:type]).delete(params[:key]) if selected_application.tokens(params[:type])
    selected_application.save
    trfn("Token has been deleted")
    redirect_back
  end

  def token_wizard
    if request.post?
      selected_application.tokens(params["token_type"])[params["token_name"]] = params["token_value"]
      selected_application.save
      return render(:json => {"status" => "Ok", "msg" => tra("Token has been registered")}.to_json)
    end

    render :layout => false
  end

  def delete_domain
    @domain = Tr8n::TranslationDomain.find_by_id(params[:id]) if params[:id]
    @domain.destroy if @domain
    trfn("Domain has been removed")
    redirect_back
  end

  def domain_modal
    @domain = Tr8n::TranslationDomain.find_by_id(params[:id]) if params[:id]
    @domain ||= Tr8n::TranslationDomain.new
    if request.post?
      d = Tr8n::TranslationDomain.find_by_name(params[:domain][:name])
      if d and d != @domain
        trfe("Domain with this name has already been configured")
        return redirect_back
      end

      @domain.name = params[:domain][:name]
      @domain.description = params[:domain][:description]
      @domain.application = selected_application
      @domain.save
      return redirect_back
    end
    render :layout => false
  end

  def delete
    if selected_application.default?
      trfe("{application} cannot be deleted", :application => selected_application.name)
      return redirect_back
    end

    selected_application.destroy
    session[:tr8n_selected_app_id] = tr8n_current_translator.applications.first.id
    trfn("{application} has been deleted", :application => selected_application.name)
    redirect_to(:action => :index)
  end

end
