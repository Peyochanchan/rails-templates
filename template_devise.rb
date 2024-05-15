# frozen_string_literal: true

run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

def source_paths
  [__dir__]
end

# GEMFILE
remove_file 'Gemfile'
run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/Gemfile > Gemfile"

if yes?('Would you like to add activeadmin?[yes | no]')
  inject_into_file 'Gemfile', after: "gem 'devise'  \n" do
    <<~RUBY
      gem 'activeadmin'
      gem 'inherited_resources'
    RUBY
  end
end


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
  # DB Create
  rails_command 'db:drop db:create db:migrate'
  generate 'rspec:install'
  generate 'pundit:install' if File.readlines("Gemfile").grep(/pundit/).any?

  # Generate Pages Controller
  ########################################
  generate(:controller, 'pages', 'index', '--skip-routes')
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
  generate 'devise:install'
  generate 'devise:views'
  run "rm -rf app/views/devise"
  run "curl -L https://github.com/Peyochanchan/rails-templates/raw/main/devise_views.zip -o devise_views.zip"
  run "file devise_views.zip"
  run "unzip devise_views.zip -d app/views"
  run "rm -f devise_views.zip"
  run "rm -rf app/views/devise/.DS_Store"
  rails_command "db:migrate"

  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  generate :devise, 'User', 'first_name', 'last_name', 'nickname', 'admin:boolean'

  in_root do
    migration = Dir.glob('db/migrate/*').max_by { |f| File.mtime(f) }
    gsub_file migration, /:admin/, ':admin, default: false'
  end

  # name_of_person gem & active storage attachment
  append_to_file(
    'app/models/user.rb',
    "\n\n  has_one_attached :avatar\n  validates :nickname, uniqueness: true", after: ':recoverable, :rememberable, :validatable')

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

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Yarn
  ########################################
  run 'yarn add autoprefixer chokidar esbuild nodemon postcss postcss-cli postcss-flexbugs-fixes postcss-import postcss-nested postcss-preset-env sass sweetalert2 tailwindcss'
  run 'yarn add chokidar --dev'

  # ESBUILD CONFIG + Hot Reload
  ########################################
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
  tailwind_file_path = 'config/tailwind.config.js'
  remote_content = URI.open(tailwind_config_url).read
  create_file tailwind_file_path, remote_content, force: true

  # Manifest & Cleaning Assets
  #########################################
  append_to_file 'app/assets/config/manifest.js', '//= link tailwind.css'
  remove_file 'app/assets/stylesheets/application.css'
  # remove_file 'app/assets/builds/application.css'
  rails_command "assets:clobber"
  rails_command "assets:clean"

  # Layout / Navbar / Flashes
  ########################################
  run "rm -rf app/views/layouts/application.html.erb"
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/_flashes.html.erb > app/views/shared/_flashes.html.erb"
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/_navbar.html.erb > app/views/shared/_navbar.html.erb"
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/application.html.erb > app/views/layouts/application.html.erb"

  # Application controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  run "curl -L https://raw.githubusercontent.com/Peyochanchan/rails-templates/main/application_controller.rb > app/controllers/application_controller.rb"

  # Procfile
  ########################################
  procfile_new_content = <<~RUBY
    web: bin/rails server -p 3000
    css: yarn build:css --watch
    js: yarn start --watch
    css: bin/rails tailwindcss:watch
  RUBY

  create_file 'Procfile.dev', procfile_new_content, force: true
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
