run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

def source_paths
  [__dir__]
end

# Gemfile
########################################
remove_file "Gemfile"
copy_file "Gemfile"

# STYLESHEETS
########################################
run "rm -rf app/assets/stylesheets"
run "rm -rf vendor"
run "unzip ~/code/Peyochanchan/rails-templates/stylesheets.zip -d app/assets && rm -f stylesheets.zip"
run "rm -rf app/assets/__MACOSX"

gsub_file(
  'app/assets/config/manifest.js',
  '//= link_directory ../stylesheets .css',
  '//= link_directory ../stylesheets .scss'
)

gsub_file(
  "app/assets/stylesheets/application.scss",
  "@import \"font-awesome\";",
  "@import \"font-awesome.css\";"
)

inject_into_file 'config/initializers/assets.rb', before: '# Precompile additional assets.' do
  <<~RUBY
    Rails.application.config.assets.paths << Rails.root.join("node_modules")
  RUBY
end

# esbuild config
copy_file 'esbuild-dev.config.js'

# Layout
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

inject_into_file "app/views/layouts/application.html.erb", after: "<body>" do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

# README
########################################
markdown_file_content = <<~MARKDOWN
  Rails app generated with template inspired by
  [lewagon/rails-templates]
  [Le Wagon coding bootcamp](https://www.lewagon.com) team.
  Modified by Peyochanchan for Rails 7 / esbuild
MARKDOWN
file "README.md", markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

########################################
# After bundle
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command "db:drop db:create db:migrate"
  generate("simple_form:install", "--bootstrap")
  generate "annotate:install"
  generate "rspec:install"
  generate "stimulus clock"
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

  # Routes
  ########################################
  route 'root to: "pages#home"'

  # Gitignore
  ########################################
  append_file ".gitignore", <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Home Page
  ########################################
  run "rm app/views/pages/home.html.erb"
  copy_file 'home.html.erb'
  run 'mv home.html.erb app/views/pages/home.html.erb'

  run "rm app/javascript/controllers/clock_controller.js"
  copy_file 'clock_controller.js'
  run 'mv clock_controller.js app/javascript/controllers/clock_controller.js'

  copy_file 'home.scss'
  run 'mv home.scss app/assets/stylesheets/pages/home.scss'

  append_file 'app/assets/stylesheets/pages/_index.scss', "@import 'home';"

  # Yarn
  ########################################
  run "yarn add bootstrap chokidar @popperjs/core esbuild-sass-plugin"
  gsub_file(
    'package.json',
    '"build": "esbuild app/javascript/*.* --bundle --sourcemap --outdir=app/assets/builds --public-path=assets"',
    '"build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds",
     "start": "node esbuild-dev.config.js",
     "build:css": "sass ./app/assets/stylesheets/application.scss:./app/assets/builds/application.css --no-source-map --load-path=node_modules"'
  )
  run "rm -f app/assets/builds/application.js.map"

  gsub_file(
    "node_modules/bootstrap/scss/_functions.scss",
    "@return mix(rgba($foreground, 1), $background, opacity($foreground) * 100);",
    "@return mix(rgba($foreground, 1%), $background, opacity($foreground) * 100%);"
  )

  append_file "app/javascript/application.js", <<~JS
    import "bootstrap"
  JS

  # Procfile
  run "rm Procfile.dev"
  file "Procfile.dev", <<~RUBY
    web: bin/rails server -p 3000
    css: yarn build:css --watch
    js: yarn start --watch
  RUBY

  # Heroku
  ########################################
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  ########################################
  run "touch '.env'"

  # Rubocop
  ########################################
  copy_file '.rubocop.yml'

  # Git
  ########################################
  git :init
  git add: "."
  git commit: "-m 'initial commit'"

  # MESSAGE
  ########################################
  say
  say
  say "————————————————————————————————————————————————————————", :red
  say
  say "🚀 App  --#{app_name.upcase}-- successfully created! 🚀", :yellow
  say
  say "————————————————————————————————————————————————————————", :red
  say
  say "🚦             Switch to your app by running:         🚦", :yellow
  say
  say
  say "                     $ cd #{app_name}"
  say
  say "————————————————————————————————————————————————————————", :red
  say
  say "🎆                      Then run:                     🎆", :yellow
  say
  say
  say "                      $ ./bin/dev"
  say
  say "————————————————————————————————————————————————————————", :red
  say
  say "                       🛰 ENJOY 🛰"
  say
  say "————————————————————————————————————————————————————————", :red
end
