# <---------------[ Copyright (c) 2012 Kevin Incorvia ]--------------->
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

# <-----------------------[ RailRocket Class ]----------------------->

class RailRocket
  include ActiveSupport::Callbacks

  attr_accessor :generator, :engines

  def initialize(generator)
    @generator = generator
    @engines = []
  end

  def method_missing(method_name, *args, &block)
    if generator.respond_to?(method_name)
      generator.send(method_name, *args, &block)
    else
      super
    end
  end

  define_callbacks :preflight, :launcher, :postflight

  def welcome!
    puts open(rocket('welcome.rb')).read
  end

  def preflight!
    run_callbacks :preflight
  end

  def launch!
    run_callbacks :launcher
  end

  def postflight!
    run_callbacks :postflight
  end

  def remote_template(source, destination)
    render = open(source).read
    data = ERB.new(render, nil, '-').result(binding)
    data.gsub!(/REMOVE\n/,'')
    create_file(destination, data, silent)
  end

  def ask_tab(tabs = 1)
    "     " * tabs
  end

  def rocket(url)
    "http://www.railrocket.me/#{url}"
  end

  def silent
    { verbose: false }
  end
end

# <-----------------------------[ Git ]----------------------------->

class RailRocket
  module Git

    def self.extended(base)
      base.class.set_callback :preflight, :before, :git_preflight_before
      base.class.set_callback :postflight, :after, :git_postflight_after
    end

    def git_preflight_before
      if yes?("\nInitialize a new git repository? (y|n)\n\n")
        engines << :git
      end
    end

    def git_postflight_after
      if engines.include?(:git)
        git :init
        run('git add .')
        run('git commit -m "initial commit"')
      end
    end
  end
end

# <----------------------------[ Gemfile ]--------------------------->

class RailRocket
  module Gemfile

    def self.extended(base)
      base.class.set_callback :preflight, :after, :gemfile_preflight_after
    end

    def gemfile_preflight_after
      remove_file("Gemfile", silent)
      remote_template(rocket('templates/gemfiles/default.tt'), "Gemfile")
      puts "\n#{'=' * 17} Running Bundle Install #{'=' * 17}\n\n"
      run('bundle install', silent)
      remove_file("public/index.html", silent)
    end
  end
end

# <-----------------------------[ RSpec ]---------------------------->

class RailRocket
  module Rspec

    def self.extended(base)
      base.class.set_callback :launcher, :before, :rspec_launcher_before
    end

    def rspec_launcher_before
      remove_file("test")
      generate("rspec:install")
    end
  end
end

# <----------------------------[ Database ]-------------------------->

class RailRocket
  module Database
    DATABASES = [:mongo, :postgres]

    def self.extended(base)
      base.class.set_callback :preflight, :before, :database_preflight_before
    end

    def database_preflight_before
      question = "\nWhat database would you like to use? (1|2)\n\n"
      answer1 = ask_tab + "1) Mongoid\n"
      answer2 = ask_tab + "2) Postgres\n\n"

      case ask(question + answer1 + answer2).to_i
      when 1
        self.extend(RailRocket::Mongo)
      when 2
        self.extend(RailRocket::Postgres)
      end
      remove_file("config/database.yml")
    end

    DATABASES.each do |db|
      define_method "#{db}?" do
        self.engines.include?(db)
      end
    end
  end
end

# <----------------------------[ Postgres ]-------------------------->

class RailRocket
  module Postgres

    def self.extended(base)
      base.engines << :postgres
      base.class.set_callback :launcher, :before, :postgres_launcher_before
    end

    def postgres_launcher_before
      source = rocket('templates/database/postgres/database.yml.tt')
      destination = 'config/database.yml'
      app_name = self.app_path
      remote_template(source, destination)
    end
  end
end

# <------------------------------[ Mongo ]-------------------------->

class RailRocket
  module Mongo

    def self.extended(base)
      base.engines << :mongo
      base.mongo_gemfile
      base.class.set_callback :launcher, :before, :mongo_launcher_before
    end

    def mongo_gemfile
      gsub_file("Gemfile", /gem 'sqlite3'/, "gem 'mongoid'", silent)
    end

    def mongo_launcher_before
      generate('mongoid:config')

      app_requires = <<-END.strip_heredoc.chomp
        require "action_controller/railtie"
        require "action_mailer/railtie"
        require "active_resource/railtie"
        require "sprockets/railtie"
      END

      gsub_file("config/application.rb", /require 'rails\/all'/, app_requires)
      gsub_file("spec/spec_helper.rb", /config\.use_trans/, "# config.use_trans")

      mongo_active_record_config([
        "config/application.rb",
        "config/environments/development.rb",
        "config/environments/test.rb",
      ])
    end

    def mongo_active_record_config(files)
      files.each do |file|
        gsub_file(file, /config\.active_record/, "# config.active_record")
      end
    end
  end
end

# <--------------------------[ configatron ]------------------------->

class RailRocket
  module Configatron

    def self.extended(base)
      base.class.set_callback :launcher, :before, :configatron_launcher_before
    end

    def configatron_launcher_before
      generate("configatron:install")
    end
  end
end

# <----------------------------[ bootstrap ]------------------------->

class RailRocket
  module Bootstrap

    def self.extended(base)
      base.class.set_callback :preflight, :before, :bootstrap_preflight_before
    end

    def bootstrap_preflight_before
      if yes?("\nWould you like to install bootsrap-sass? (y|n)\n\n")
        engines << :bootstrap
      end
    end

    define_method "bootstrap?" do
      engines.include?(:bootstrap)
    end
  end
end

# <---------------------------[ RailRocket ]------------------------->

rocket = RailRocket.new(self)

# <---------------------------[ Add Modules ]------------------------>

rocket.extend(RailRocket::Git)
rocket.extend(RailRocket::Gemfile)
rocket.extend(RailRocket::Rspec)
rocket.extend(RailRocket::Configatron)
rocket.extend(RailRocket::Database)
rocket.extend(RailRocket::Bootstrap)

# <-----------------------------[ Launch ]--------------------------->

rocket.welcome!
rocket.preflight!
rocket.launch!
rocket.postflight!
