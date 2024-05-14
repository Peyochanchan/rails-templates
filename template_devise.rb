# frozen_string_literal: true

run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

def source_paths
  [__dir__]
end

# GEMFILE
remove_file 'Gemfile'
run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/Gemfile > Gemfile"

if yes?('Would you like to add activeadmin?[yes | no]')
  inject_into_file 'Gemfile', after: "gem 'devise'\n" do
    <<~RUBY
      gem 'activeadmin'
      gem 'inherited_resources'
    RUBY
  end
end

gsub_file(
  'app/views/layouts/application.html.erb',
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <script src="https://kit.fontawesome.com/d39b0756a2.js" crossorigin="anonymous"></script>'

)

# Flashes
########################################
file 'app/views/shared/_flashes.html.erb', <<~HTML
  <div class="flex">
    <% if notice %>
      <div class="bg-emerald-100 border border-emerald-400 text-emerald-700 py-4 px-6 rounded absolute right-4 top-4" role="alert">
        <span class="text-xl inline-block mr-4 align-middle">
          <i class="fas fa-check"></i>
        </span>
        <span class="mr-8 block sm:inline align-middle"><%= notice %></span>
        <button class="relative bg-transparent text-xl font-semibold leading-none right-0 outline-none focus:outline-none" onclick="closeAlert(event)">
          <span>×</span>
        </button>
      </div>
    <% end -%>

    <% if alert %>
      <div class="bg-red-100 border border-red-400 text-red-700 py-4 px-6 rounded absolute right-4 top-4" role="alert">
        <span class="text-xl inline-block mr-4 align-middle">
          <i class="fas fa-triangle-exclamation"></i>
        </span>
        <span class="mr-8 block sm:inline align-middle"><%= alert %></span>
        <button class="relative bg-transparent text-xl font-semibold leading-none right-0 outline-none focus:outline-none" onclick="closeAlert(event)">
          <span>×</span>

        </button>
      </div>
    <% end -%>
  </div>
  <script>
    function closeAlert(event){
      let element = event.target;
      while(element.nodeName !== "BUTTON"){
        element = element.parentNode;
      }
      element.parentNode.parentNode.removeChild(element.parentNode);
    }
  </script>
HTML

inject_into_file 'app/views/layouts/application.html.erb', after: "<body>\n" do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

inject_into_file 'app/views/layouts/application.html.erb', after: "<%= csp_meta_tag %>\n" do
  <<~HTML
    <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
  HTML
end

remove_line = <<~HTML
  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
HTML
gsub_file 'app/views/layouts/application.html.erb', remove_line, ''
# README
########################################
markdown_file_content = <<~MARKDOWN
  Rails app generated with template inspired by \n
  by Peyochanchan for Rails 7 / Esbuild / Tailwind / Devise / Pundit

MARKDOWN
file 'README.md', markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework(
      :rspec,
      fixtures: false,
      view_specs: false,
      helper_specs: false,
      routing_specs: false,
    )
  end
RUBY

source_paths
environment generators

########################################
# After bundle
########################################
after_bundle do
  # DB Create / Migrate
  ########################################
  rails_command 'db:drop db:create db:migrate'
  # Rspec
  ########################################
  generate 'rspec:install'

  # Generate Pages Controller
  ########################################
  generate(:controller, 'pages', 'index', '--skip-routes')

  generate 'pundit:install' if File.readlines("Gemfile").grep(/pundit/).any?

  # Routes
  ########################################
  route 'root to: "pages#index"'

  # Tailwind Installation
  ########################################
  run("echo yes | bin/rails tailwindcss:install")


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
  rails_command 'db:migrate'

  # Devise install + user
  ########################################
  # Install Devise
  generate 'devise:install'
  generate 'devise:views'
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
      after_action :verify_pundit_authorization, unless: :devise_controller?


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

      def verify_pundit_authorization
        if action_name == "index"
          verify_policy_scoped if params[:controller] != "pages"
        else
          verify_authorized
        end
      end
    end
  RUBY

  app_controller_content_without_pundit = <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_user!
    end
  RUBY

  if File.readlines("Gemfile").grep(/pundit/).any?
    file 'app/controllers/application_controller.rb', app_controller_content_with_pundit
  else
    file 'app/controllers/application_controller.rb', app_controller_content_without_pundit
  end

  # Assets
  ########################################

  inside 'app/assets/stylesheets' do
    empty_directory 'config'
    empty_directory 'components'
  end

  create_file 'app/assets/stylesheets/components/index.css' do
    <<~CSS
      @import "clock";
    CSS
  end

  application_tailwind_css_content = <<-CSS
  @import "tailwindcss/base";
  @import "tailwindcss/components";
  @import "tailwindcss/utilities";
  @import "components/index";

  .ror-version {
    h1 {
      color: theme('colors.green.500');
      font-family: "Roboto", sans-serif;
    }
  }
  CSS

  file 'app/assets/stylesheets/application.tailwind.css', application_tailwind_css_content, force: true

  # Home Page
  ########################################
  generate 'stimulus clock'
  run 'rm app/views/pages/index.html.erb'
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/index.html.erb > app/views/pages/index.html.erb"

  run 'rm app/javascript/controllers/clock_controller.js'
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/clock_controller.js >  app/javascript/controllers/clock_controller.js"

  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/clock.css > app/assets/stylesheets/components/clock.css"

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'
  generate('devise:views')

  # link_to = <<~HTML
  #   <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  # HTML
  # button_to = <<~HTML
  #   <div class="d-flex align-items-center">
  #     <div>Unhappy?</div>
  #     <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete, class: "btn btn-link" %>
  #   </div>
  # HTML
  # gsub_file('app/views/devise/registrations/edit.html.erb', link_to, button_to)

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Yarn
  ########################################
  run 'yarn add autoprefixer chokidar esbuild nodemon postcss postcss-cli postcss-flexbugs-fixes postcss-import postcss-nested postcss-preset-env sass sweetalert2 tailwindcss'
  run 'yarn add chokidar --dev'

  # ESBUILD CONFIG
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/esbuild-dev.config.js > esbuild-dev.config.js"
  insert_into_file 'package.json', "  \"type\": \"module\",\n", after: "\"private\": true,\n"
  gsub_file(
    'package.json',
    /"scripts": \{.*?\}/m,
    '"scripts": {
      "build": "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets",
      "start": "node esbuild-dev.config.js",
      "build:css": "tailwindcss --postcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css",
      "watch:css": "nodemon --watch ./app/assets/stylesheets/ --ext css --exec \"yarn build:css\""
    },
    "browserslist": [
      "defaults"
    ],
    "devDependencies": {
      "chokidar": "^3.6.0"
    }'
  )
  run 'rm -f app/assets/builds/application.js.map'

  create_file './postcss.config.js' do
    <<~JS
      import autoprefixer from "autoprefixer";
      import postcssImport from "postcss-import";
      import tailwindcss from "tailwindcss";
      import postcssNested from "postcss-nested";
      import postcssFlexbugsFixes from "postcss-flexbugs-fixes";
      import postcssPresetEnv from "postcss-preset-env";

      export default {
        plugins: [
          autoprefixer,
          postcssImport,
          tailwindcss,
          postcssNested,
          postcssFlexbugsFixes,
          postcssPresetEnv({
            autoprefixer: {
              flexbox: "no-2009"
            },
            stage: 3
          })
        ],
      };
    JS
  end

  tailwind_config_url = "https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/tailwind.config.js"
  local_file_path = 'config/tailwind.config.js'
  remote_content = URI.open(tailwind_config_url).read
  create_file local_file_path, remote_content, force: true

  # Manifest & Assets
  #########################################
  append_to_file 'app/assets/config/manifest.js', '//= link tailwind.css'
  remove_file 'app/assets/stylesheets/application.css'
  # remove_file 'app/assets/builds/application.css'
  rails_command "assets:clobber"
  rails_command "assets:clean"
  # Procfile
  ########################################
  run 'rm Procfile.dev'
  file 'Procfile.dev', <<~RUBY
    web: bin/rails server -p 3000
    css: yarn build:css --watch
    js: yarn start --watch
    css: bin/rails tailwindcss:watch
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
