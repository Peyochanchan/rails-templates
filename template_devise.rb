# frozen_string_literal: true

run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

def source_paths
  [__dir__]
end

# GEMFILE
remove_file 'Gemfile'
run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/Gemfile > Gemfile"

inject_into_file 'Gemfile', after: "gem 'simple_form', github: 'heartcombo/simple_form'\n" do
  <<~'RUBY'
    gem 'devise'
  RUBY
end

if yes?('Would you like to add pundit?[yes | no]')
  inject_into_file 'Gemfile', after: "gem 'devise'\n" do
    <<~'RUBY'
        gem "pundit"
    RUBY
  end
  inject_into_file 'Gemfile', after: "gem 'warden-rspec-rails'\n" do
    <<~'RUBY'
        gem 'pundit-matchers', '~> 1.7.0'
    RUBY
  end
end

if yes?('Would you like to add activeadmin?[yes | no]')
  inject_into_file 'Gemfile', after: "gem 'devise'\n" do
    <<~'RUBY'
      gem 'activeadmin', github: 'activeadmin/activeadmin', branch: 'master'
      gem 'inherited_resources', github: 'activeadmin/inherited_resources'
    RUBY
  end
end

# STYLESHEETS
########################################
run 'rm -rf app/assets/stylesheets'
run 'rm -rf vendor'
run "curl -L https://github.com/lewagon/rails-stylesheets/archive/master.zip > stylesheets.zip"
run "unzip stylesheets.zip -d app/assets && rm -f stylesheets.zip && rm -f app/assets/rails-stylesheets-master/README.md"
run "mv app/assets/rails-stylesheets-master app/assets/stylesheets"

gsub_file(
  'app/assets/config/manifest.js',
  '//= link_directory ../stylesheets .css',
  '//= link_directory ../stylesheets .scss'
)

gsub_file(
  'app/assets/stylesheets/application.scss',
  '@import "font-awesome";',
  '@import "font-awesome.css";'
)

# NODE_MODULES
########################################
inject_into_file 'config/initializers/assets.rb', before: '# Precompile additional assets.' do
  <<~RUBY
    Rails.application.config.assets.paths << Rails.root.join("node_modules")
  RUBY
end

# LAYOUT
########################################

gsub_file(
  'app/views/layouts/application.html.erb',
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

# Flashes
########################################
file 'app/views/shared/_flashes.html.erb', <<~HTML
  <% if notice %>
    <div class="alert alert-info alert-dismissible fade show m-1" role="alert">
      <%= notice %>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
      </button>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert alert-warning alert-dismissible fade show m-1" role="alert">
      <%= alert %>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
      </button>
    </div>
  <% end %>
HTML

inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

# README
########################################
markdown_file_content = <<~MARKDOWN
  Rails app generated with template inspired by \n
  [lewagon/rails-templates] \n
  [Le Wagon coding bootcamp](https://www.lewagon.com) team.\n
  Modified by Peyochanchan for Rails 7 / esbuild

MARKDOWN
file 'README.md', markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

source_paths
environment generators

########################################
# After bundle
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'
  generate('simple_form:install', '--bootstrap')
  generate 'annotate:install'
  generate 'rspec:install'
  generate 'stimulus clock'
  generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')
  if File.read("Gemfile") =~ /^\s*gem ['"]pundit['"]/
    generate 'pundit:install'
  end
  # Routes
  ########################################
  route 'root to: "pages#home"'

  # Gitignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # ACTIVE STORAGE
  ########################################
  rails_command 'active_storage:install'

  environment 'config.active_storage.service = :cloudinary',
              env: 'development'

  # Devise install + user
  ########################################
  # Install Devise
  generate 'devise:install'

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  # Create Devise User
  generate :devise, 'User', 'first_name', 'last_name', 'nickname', 'admin:boolean'

  # set admin boolean to false by default
  in_root do
    migration = Dir.glob('db/migrate/*').max_by { |f| File.mtime(f) }
    gsub_file migration, /:admin/, ':admin, default: false'
  end

  # name_of_person gem & active storage attachment
  append_to_file(
    'app/models/user.rb',
    "\n\n  has_one_attached :avatar\n  validates :nickname, uniqueness: true", after: ':recoverable, :rememberable, :validatable')

  # Application controller
  ########################################
  run 'rm app/controllers/application_controller.rb'

  app_controller_content_with_pundit = <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_user!, if: :devise_controller?
      before_action :configure_permitted_parameters, if: :devise_controller?
      include Pundit::Authorization

      after_action :verify_authorized, except: :index, unless: :skip_pundit?
      after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?


      def configure_permitted_parameters
        devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name nickname avatar password password_confirmation])
        devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name nickname avatar password password_confirmation current_password])
      end

      private

      # Uncomment when you *really understand* Pundit!
      # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
      # def user_not_authorized
      #   flash[:alert] = "You are not authorized to perform this action."
      #   redirect_to(root_path)
      # end

      def skip_pundit?
        devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
      end
    end
  RUBY

  app_controller_content_without_pundit = <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_user!
    end
  RUBY

  if File.read("Gemfile") =~ /^\s*gem ['"]pundit['"]/
    file 'app/controllers/application_controller.rb', app_controller_content_with_pundit
  else
    file 'app/controllers/application_controller.rb', app_controller_content_without_pundit
  end

  # Pages Controller
  ########################################
  inject_into_file 'app/controllers/pages_controller.rb',
                   "  skip_before_action :authenticate_user!, only: :home \n\n",
                   after: "class PagesController < ApplicationController\n"

  # Home Page
  ########################################
  run 'rm app/views/pages/home.html.erb'
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/home.html.erb > app/views/pages/home.html.erb"

  run 'rm app/javascript/controllers/clock_controller.js'
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/clock_controller.js >  app/javascript/controllers/clock_controller.js"


  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/home.scss > app/assets/stylesheets/pages/_home.scss"

  append_file 'app/assets/stylesheets/pages/_index.scss', "@import 'home';"

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'
  generate('devise:views')
  gsub_file(
    'app/views/devise/registrations/new.html.erb',
    "<%= simple_form_for(resource, as: resource_name, url: registration_path(resource_name)) do |f| %>",
    "<%= simple_form_for(resource, as: resource_name, url: registration_path(resource_name), data: { turbo: :false }) do |f| %>"
  )
  gsub_file(
    "app/views/devise/sessions/new.html.erb",
    "<%= simple_form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>",
    "<%= simple_form_for(resource, as: resource_name, url: session_path(resource_name), data: { turbo: :false }) do |f| %>"
  )
  link_to = <<~HTML
    <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  HTML
  button_to = <<~HTML
    <div class="d-flex align-items-center">
      <div>Unhappy?</div>
      <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete, class: "btn btn-link" %>
    </div>
  HTML
  gsub_file('app/views/devise/registrations/edit.html.erb', link_to, button_to)

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Yarn
  ########################################
  run 'yarn add bootstrap chokidar @popperjs/core esbuild-sass-plugin esbuild@0.15.14'

  # ESBUILD CONFIG
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/esbuild-dev.config.js > esbuild-dev.config.js"
  gsub_file(
    'package.json',
    '"build": "esbuild app/javascript/*.* --bundle --sourcemap --outdir=app/assets/builds --public-path=assets"',
    '"build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds",
    "start": "node esbuild-dev.config.js",
    "build:css": "sass ./app/assets/stylesheets/application.scss:./app/assets/builds/application.css --no-source-map --load-path=node_modules"'
  )
  run 'rm -f app/assets/builds/application.js.map'

  gsub_file(
    'node_modules/bootstrap/scss/_functions.scss',
    '@return mix(rgba($foreground, 1), $background, opacity($foreground) * 100);',
    '@return mix(rgba($foreground, 1%), $background, opacity($foreground) * 100%);'
  )

  append_file 'app/javascript/application.js', <<~JS
    import "bootstrap"
  JS

  # PROCFILE
  run 'rm Procfile.dev'
  file 'Procfile.dev',
    <<~RUBY
      web: bin/rails server -p 3000
      css: yarn build:css --watch
      js: yarn start --watch
    RUBY

  # HEROKU
  ########################################
  run 'bundle lock --add-platform x86_64-linux'

  # DOTENV
  ########################################
  run "touch '.env'"

  # RUBOCOP
  ########################################
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/.rubocop.yml > .rubocop.yml"

  # Git
  ########################################
  git :init
  git add: '.'
  git commit: '-m "initial commit"'

  # MESSAGE
  ########################################
  say
  say
  say '————————————————————————————————————————————————————————', :red
  say
  say "🚀 App  --#{app_name.upcase}-- successfully created! 🚀", :yellow
  say
  say '————————————————————————————————————————————————————————', :red
  say
  say '🚦             Switch to your app by running:         🚦', :yellow
  say
  say
  say "                     $ cd #{app_name}"
  say
  say '————————————————————————————————————————————————————————', :red
  say
  say '🎆                      Then run:                     🎆', :yellow
  say
  say
  say '                      $ ./bin/dev'
  say
  say '————————————————————————————————————————————————————————', :red
  say
  say '                       🛰 ENJOY 🛰'
  say
  say '————————————————————————————————————————————————————————', :red
end
