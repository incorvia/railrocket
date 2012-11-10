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

  def welcome!
    puts open(rocket('welcome.rb')).read
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

# <---------------------------[ application ]-------------------------->

class RailRocket
  module Application

    def application_launch
      application_config_file("config/application.rb")
      application_config_file("config/environments/development.rb", ".tt")
      application_config_file("config/environments/test.rb", ".tt")
    end

    def application_config_file(path, destination_ext = nil)
      remove_file(path, silent)
      source = master_templates("#{path}#{destination_ext if destination_ext}")
      remote_template(source, path)
    end
  end
end

# <----------------------------[ bootstrap ]------------------------->

class RailRocket
  module Bootstrap

    def bootstrap_preflight
      if yes?("\nWould you like to install bootsrap-sass? (y|n)\n\n")
        engines << :bootstrap
      end
    end

    define_method "bootstrap?" do
      engines.include?(:bootstrap)
    end
  end
end

# <--------------------------[ configatron ]------------------------->

class RailRocket
  module Configatron

    def configatron_launch
      generate("configatron:install")
    end
  end
end

# <----------------------------[ database ]-------------------------->

class RailRocket
  module Database
    DATABASES = [:mongo, :postgres]

    def database_preflight
      question = "\nWhat database would you like to use? (1|2)\n\n"
      answer1 = ask_tab + "1) Mongoid\n"
      answer2 = ask_tab + "2) Postgres\n\n"

      case ask(question + answer1 + answer2).to_i
      when 1
        self.extend(RailRocket::Mongo)
        engines << :mongo
        options["skip_active_record"] = true
      when 2
        self.extend(RailRocket::Postgres)
        engines << :postgres
      end
      remove_file("config/database.yml", silent)
    end

    DATABASES.each do |db|
      define_method "#{db}?" do
        self.engines.include?(db)
      end
    end
  end
end

# <----------------------------[ gemfile ]--------------------------->

class RailRocket
  module Gemfile

    def gemfile_launch
      remove_file("Gemfile", silent)
      remote_template(rocket('templates/gemfiles/gemfile'), "Gemfile")
      puts "\n#{'=' * 17} Running Bundle Install #{'=' * 17}\n\n"
      run('bundle install', silent)
      remove_file("public/index.html", silent)
    end
  end
end

# <-----------------------------[ git ]----------------------------->

class RailRocket
  module Git

    def git_preflight
      if yes?("\nInitialize a new git repository? (y|n)\n\n")
        engines << :git
      end
    end

    def git_launch
      if engines.include?(:git)
        git :init
        run('git add .')
        run('git commit -m "initial commit"')
      end
    end
  end
end

# <------------------------------[ mongo ]-------------------------->

class RailRocket
  module Mongo

    def mongo_launch
      generate('mongoid:config')
    end
  end
end

# <----------------------------[ postgres ]-------------------------->

class RailRocket
  module Postgres

    def postgres_launch
      source = master_templates('config/databases/postgresql.yml')
      destination = 'config/database.yml'
      remote_template(source, destination)
    end
  end
end

# <-----------------------------[ rspec ]---------------------------->

class RailRocket
  module Rspec

    def self.extended(base)
      base.options["skip_test_unit"] = true
    end

    def rspec_launch
      remove_file("test")
      generate("rspec:install")
      remove_file("spec/spec_helper.rb")
      remote_template(rocket('templates/rspec/spec_helper.rb'), "spec/spec_helper.rb")
      gsub_file("spec/spec_helper.rb", /config\.use_trans/, "# config.use_trans") if mongo?
    end
  end
end

# <---------------------------[ railrocket ]------------------------->

rocket = RailRocket.new(self)

# <---------------------------[ rocket fuel ]------------------------>

rocket.extend(RailRocket::Git)
rocket.extend(RailRocket::Gemfile)
rocket.extend(RailRocket::Rspec)
rocket.extend(RailRocket::Database)
rocket.extend(RailRocket::Configatron)
rocket.extend(RailRocket::Application)
rocket.extend(RailRocket::Bootstrap)

# <-----------------------------[ preflight ]------------------------>

rocket.welcome!
rocket.git_preflight
rocket.database_preflight
rocket.bootstrap_preflight

# <-------------------------------[ launch ]------------------------->

rocket.gemfile_launch
rocket.mongo_launch       if rocket.mongo?
rocket.postgres_launch    if rocket.postgres?
rocket.rspec_launch
rocket.configatron_launch
rocket.application_launch
rocket.git_launch
