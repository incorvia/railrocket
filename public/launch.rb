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
    unfreeze_options
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

  def unfreeze_options
    self.options = self.options.dup
  end

  def ask_tab(tabs = 1)
    "     " * tabs
  end

  def rocket(url)
    "http://www.railrocket.me/#{url}"
  end

  def rails
    "https://raw.github.com/rails/rails/master"
  end

  def master_templates(url)
    "#{rails}/railties/lib/rails/generators/rails/app/templates/#{url}"
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
      remote_template(rocket('templates/gemfiles/gemfile'), "Gemfile")
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
      base.class.set_callback :preflight, :after, :rspec_preflight_after
      base.options["skip_test_unit"] = true
    end

    def rspec_preflight_after
      remove_file("test")
      generate("rspec:install")
      remove_file("spec/spec_helper.rb")
      remote_template(rocket('templates/rspec/spec_helper.rb'), "spec/spec_helper.rb")
    end
  end
end

# <----------------------------[ Database ]-------------------------->

class RailRocket
  module Database
    DATABASES = [:mongo, :postgres]

    def self.extended(base)
      base.class.set_callback :preflight, :before, :database_preflight_before
      base.class.set_callback :preflight, :after, :database_preflight_after
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
      remove_file("config/database.yml", silent)
    end

    def database_preflight_after
      database_config_file("config/application.rb")
      database_config_file("config/environments/development.rb", ".tt")
      database_config_file("config/environments/test.rb", ".tt")
    end

    def database_config_file(path, destination_ext = nil)
      remove_file(path, silent)
      source = master_templates("#{path}#{destination_ext if destination_ext}")
      remote_template(source, path)
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
      source = master_templates('config/databases/postgresql.yml')
      destination = 'config/database.yml'
      remote_template(source, destination)
    end
  end
end

# <------------------------------[ Mongo ]-------------------------->

class RailRocket
  module Mongo

    def self.extended(base)
      base.engines << :mongo
      base.options["skip_active_record"] = true
      base.class.set_callback :launcher, :before, :mongo_launcher_before
    end

    def mongo_launcher_before
      require 'pry'
      binding.pry
      generate('mongoid:config')
      gsub_file("spec/spec_helper.rb", /config\.use_trans/, "# config.use_trans")
    end
  end
end

# <--------------------------[ configatron ]------------------------->

class RailRocket
  module Configatron

    def self.extended(base)
      base.class.set_callback :preflight, :after, :configatron_preflight_after
    end

    def configatron_preflight_after
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
rocket.extend(RailRocket::Configatron)
rocket.extend(RailRocket::Rspec)
rocket.extend(RailRocket::Database)
rocket.extend(RailRocket::Gemfile)
rocket.extend(RailRocket::Bootstrap)

# <-----------------------------[ Launch ]--------------------------->

rocket.welcome!
rocket.preflight!
rocket.launch!
rocket.postflight!
