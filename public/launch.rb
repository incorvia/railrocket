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

require 'open-uri'

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

  def preflight!
    run_callbacks :preflight do
      run('bundle install')
    end
  end

  def launch!
    run_callbacks :launcher
  end

  def postflight!
    run_callbacks :postflight
  end

  def status(engine, state)
    "Running #{state} for #{engine} engine! ......."
  end

  def ask_tab(tabs)
    "     " * tabs
  end
end

# <-----------------------------[ Git ]----------------------------->

class RailRocket
  module Git

    def self.extended(base)
      base.class.set_callback :preflight, :before, :git_preflight
    end

    def git_preflight
      if yes?("\nInitiate a new git repository? (y|n)\n")
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
      base.class.set_callback :preflight, :before, :gemfile_preflight
    end

    def gemfile_preflight
      remove_file("Gemfile")
      data = open('http://www.railrocket.me/templates/Gemfile').read
      create_file("Gemfile", data)
    end
  end
end

# <-----------------------------[ RSpec ]---------------------------->

class RailRocket
  module Rspec

    def self.extended(base)
      base.class.set_callback :launcher, :before, :rspec_launcher
    end

    def rspec_launcher
      remove_file("test")
      generate("rspec:install")
    end
  end
end

# <----------------------------[ Database ]-------------------------->

class RailRocket
  module Database

    def self.extended(base)
      base.class.set_callback :preflight, :before, :database_preflight
      base.class.set_callback :launcher, :before, :database_launcher
    end

    def database_preflight
      question = "What database would you like to use? (1)\n"
      answer1 = ask_tab(1) + "1) Mongoid\n"

      case ask(question + answer1).to_i
      when 1
        engines << :mongo
      end
      database_gemfile
    end

    def database_gemfile
      if engines.include?(:mongo)
        gsub_file "Gemfile", /gem 'sqlite3'/, "gem 'mongoid'"
      end
    end

    def database_launcher
      if engines.include?(:mongo)
        mongo_launcher
      end
    end

    def mongo_launcher
      generate('mongoid:config')

      app_requires = <<-END.strip_heredoc.chomp
        require "action_controller/railtie"
        require "action_mailer/railtie"
        require "active_resource/railtie"
        require "sprockets/railtie"
      END

      gsub_file("config/application.rb", /require 'rails\/all'/, app_requires)
      gsub_file("spec/spec_helper.rb", /config\.use_trans/, "# config.use_trans")

      comment_active_record_config([
        "config/application.rb",
        "config/environments/development.rb",
        "config/environments/test.rb",
      ])
    end

    def comment_active_record_config(files)
      files.each do |file|
        gsub_file(file, /config\.active_record/, "# config.active_record")
      end
    end
  end
end

# <---------------------------[ RailRocket ]------------------------->

rocket = RailRocket.new(self)

# <---------------------------[ Add Modules ]------------------------>

rocket.extend(RailRocket::Git)
rocket.extend(RailRocket::Gemfile)
rocket.extend(RailRocket::Rspec)
rocket.extend(RailRocket::Database)

# <-----------------------------[ Launch ]--------------------------->

rocket.preflight!
rocket.launch!
rocket.postflight!
