# frozen_string_literal: true

run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

def source_paths
  [__dir__]
end

# GEMFILE
remove_file 'Gemfile'
run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/Gemfile > Gemfile"

# inject_into_file 'Gemfile', after: "gem 'simple_form', github: 'heartcombo/simple_form'\n" do
#   <<~'RUBY'
#     gem 'devise'
#   RUBY
# end

if yes?('Would you like to add pundit?[yes | no]')
  inject_into_file 'Gemfile', after: "gem 'devise'\n" do
    <<~'RUBY'
        gem 'pundit', '~> 2.3', '>= 2.3.1'
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
      gem 'activeadmin'
      gem 'inherited_resources'
    RUBY
  end
end

# NODE_MODULES
########################################
# inject_into_file 'config/initializers/assets.rb', before: '# Precompile additional assets.' do
#   <<~RUBY
#     Rails.application.config.assets.paths << Rails.root.join("node_modules")
#   RUBY
# end

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
  rails_command 'tailwindcss:install'
  generate 'annotate:install'
  generate 'rspec:install'
  generate 'stimulus clock'
  generate(:controller, 'pages', 'index', 'home', '--skip-routes', '--no-test-framework')

  generate 'pundit:install' if File.readlines("Gemfile").grep(/pundit/).any?

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
  rails_command 'db:migrate'

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

  if File.readlines("Gemfile").grep(/pundit/).any?
    file 'app/controllers/application_controller.rb', app_controller_content_with_pundit
  else
    file 'app/controllers/application_controller.rb', app_controller_content_without_pundit
  end

  # Assets
  ########################################
  rm 'app/assets/stylesheets/application.css'

  inside 'app/assets' do
    empty_directory 'images'
    empty_directory 'components'
    empty_directory 'config'
  end

  inside 'app/assets/components' do
    create_file 'alert.css', <<-CSS
      .alert {
        position: fixed;
        bottom: 16px;
        right: 16px;
        z-index: 1000;
      }
    CSS
    create_file 'avatar.css', <<-CSS
      .avatar {
        height: 50px;
        object-fit: cover;
        width: 50px;
        border-radius: 50%;
      }

      .avatar-large {
        width: 50px;
        border-radius: 50%;
      }
      .avatar-bordered {
        width: 50px;
        border-radius: 50%;
        box-shadow: 0 1px 2px rgba(0,0,0,0.2);
        border: white 1px solid;
      }
      .avatar-square {
        width: 50px;
        border-radius: 0px;
        box-shadow: 0 1px 2px rgba(0,0,0,0.2);
        border: white 1px solid;
      }
    CSS
    create_file 'index.css', <<-CSS
      @import "alert";
      @import "avatar";
      @import "navbar";
    CSS
    create_file 'navbar.css', <<-CSS
      #sign-in-nav {
        margin: 8px 0px 0px 15px;
      }

      .logo-nav {
        flex: 2;
        display: flex;
        align-items: center;
        color: $darkgreen;
        h4 {
          margin: 0;
          font-family: $logo-font;
        }
        img {
          margin-right: 12px;
          width: 45px;
        }
        @media (max-width: 650px) {
          width: 30px;
          font-size: 10px;
          img {
            margin-right: 8px;
            width: 30px;
          }
        }
      }

      .navbar-mh, .mobile-menu-mh ul {
        list-style: none;
        padding: 0;

        a {
          text-decoration: none;
          letter-spacing: 1px;
        }
      }

      .navbar-mh {
        display: none;
        justify-content: space-between;
        width: 100%;
        margin: auto;

        li {
          text-align: center;
          #logo-nav {
            flex: 2;
          }
          #lang {
            flex: 1;
          }
          #nav-sign-in {
            flex: 1;
          }
        }

        .dropdown-menu {
          top: 4% !important;
          left: 1% !important;
          box-shadow: rgba(0, 0, 0, 0.1) 0px 0px 12px;
          transform: translate3d(-12px, 42px, 0px) !important;
          min-width: 8rem !important;
          border-radius: 2px !important;
        }

        a {
          padding: 8px 16px;
          display: flex;
          justify-content: center;

          &.dropdown-item {
            display: flex;
            align-items: center;
            justify-content: center ;
            padding: 4px 8px;
            text-transform: none;
            i {
              margin-left: 8px;
            }
          }

          &.dropdown-toggle::after {
            display: none;
          }
        }

        @media (min-width: 768px) {
          display: flex;
        }
      }

      .mobile-menu-mh {
        position: relative;
        background: transparent;
        width: 100%;

        .link-nav {
          font-size: 0.7em;
        }

        .burger {
          position: fixed;
          right: 20px;
          top: 20px;
          z-index: 5;
          cursor: pointer;

          div {
            color: $whity;
            width: 36px;
            height: 7px;
            background: #FDE2BD;
            margin-bottom: 4px;
            transition: all .3s ease
          }
        }

        .mask {
          background: white;
          top: 0;
          bottom: 0;
          right: 0;
          left: 0;
          z-index: 2;
          opacity: 0;
          transition: opacity .5s ease;
        }

        ul {
          position: fixed;
          z-index: 2;
          margin: 0;
          width: 100vw;
          background: white;
          padding: 32px;
          margin-top: -80%;
          transition: margin-left .5s ease;
        }

        li {
          margin-bottom: 8px;
        }

        a {
          padding: 2px 8px;
          font-size: 1.8em;
        }

        &.show {
          display: block;

          ul {
            margin-top: 0;
          }

          .mask {
            position: fixed;
            opacity: 1;
          }

          .burger {
            div:nth-child(1) {
              opacity: 0;
            }

            div:nth-child(2) {
              transform: rotate(45deg) translateY(11px);
            }

            div:nth-child(3) {
              transform: rotate(-45deg) translateY(-11px);
            }
          }
        }

        @media (min-width: 768px) {
          display: none;
        }
      }
        a.indent {
          text-indent: 2em;
          border: none !important;
        }

        a.hidden {
          display: none;
        }
    CSS
  end

  inside 'app/assets/stylesheets' do
    empty_directory 'pages'
  end
  create_file 'app/assets/stylesheets/pages/home.css'
  create_file 'app/assets/stylesheets/pages/index.css'
  append_to_file 'app/assets/stylesheets/pages/index.css', <<-CSS
    @import "home";
  CSS
  append_to_file 'app/assets/stylesheets/application.tailwind.css', <<-CSS
    @import "components/index";
    @import "pages/index";

  CSS
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

  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/home.css > app/assets/stylesheets/pages/home.css"

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'
  generate('devise:views')

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
  run 'yarn add esbuild chokidar sass @popperjs/core autoprefixer nodemon postcss postcss-cli'
  after_bundle do
    run "yarn add chokidar --dev"
  end
  # ESBUILD CONFIG
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/esbuild-dev.config.js > esbuild-dev.config.js"
  gsub_file(
    'package.json',
    /"scripts": \{.*?\}/m,
    '"scripts": {
      "build": "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets",
      "start": "node esbuild-dev.config.js",
      "build:css:compile": "sass ./app/assets/stylesheets/application.tailwind.css:./app/assets/builds/application.css --no-source-map --load-path=node_modules",
      "build:css:prefix": "postcss ./app/assets/builds/application.css --use=autoprefixer --output=./app/assets/builds/application.css",
      "build:css": "yarn build:css:compile && yarn build:css:prefix",
      "watch:css": "nodemon --watch ./app/assets/stylesheets/ --ext css --exec \\"yarn build:css\\""
    },
    "browserslist": [
      "defaults"
    ],
    "devDependencies": {
      "chokidar": "^3.6.0"
    }'
  )
  run 'rm -f app/assets/builds/application.js.map'

  insert_into_file 'tailwind.config.js', before: "],\n  theme: {" do
    "  './app/assets/stylesheets/**/*.css',\n"
  end
  # gsub_file(
  #   'node_modules/bootstrap/scss/_functions.scss',
  #   '@return mix(rgba($foreground, 1), $background, opacity($foreground) * 100);',
  #   '@return mix(rgba($foreground, 1%), $background, opacity($foreground) * 100%);'
  # )

  # append_file 'app/javascript/application.js', <<~JS
  #   import "bootstrap"
  # JS
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
