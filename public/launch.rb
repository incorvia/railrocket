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
require 'pry'

# <-----------------------[ RailRocket Class ]----------------------->

class RailRocket
  include ActiveSupport::Callbacks

  attr_accessor :generator, :rocket

  def initialize(generator)
    @generator = generator
    @rocket = {}
    @rocket[:engines] = []
    @rocket[:launchers] = []
  end

  def method_missing(method_name, *args, &block)
    if generator.respond_to?(method_name)
      generator.send(method_name, *args, &block)
    else
      super
    end
  end

  def launch!
    rocket[:engines].each do |engine|
      run_callbacks "#{engine}_launcher" do
        launcher(engine)
      end
    end
  end

  def launcher(engine)
    "Starting #{engine} engine! ......."
  end
end

# <---------------------------[ Engine ]--------------------------->

class RailRocket
  module Engine
    include ActiveSupport::Inflector

    def self.extended(klass)
      klass.define_singleton_method :extended do |base|
        engine = klass.name.demodulize.downcase.to_sym
        base.rocket[:engines] << engine
        base.class.define_callbacks "#{engine}_launcher"
        base.class.set_callback "#{engine}_launcher", :before, "#{engine}_preflight"
        base.class.set_callback "#{engine}_launcher", :after, "#{engine}_takeoff"
      end
    end
  end
end

# <-----------------------------[ Git ]----------------------------->

class RailRocket
  module Git
    extend RailRocket::Engine

    def git_preflight
      if yes?("\nInitiate a new git repository? (y|n)\n")
        rocket[:launchers] << :git
      end
    end

    def git_takeoff
      git :init
    end
  end
end

# <----------------------------[ Gemfile ]--------------------------->

class RailRocket
  module Gemfile
    extend RailRocket::Engine

    def gemfile_preflight
    end

    def gemfile_takeoff
      remove_file("Gemfile")
      data = open('http://www.railrocket.me/templates/Gemfile').read
      create_file("Gemfile", data)
    end
  end
end

# <------------------------[ Run RailRocket ]------------------------->

rocket = RailRocket.new(self)

rocket.extend(RailRocket::Git)
rocket.extend(RailRocket::Gemfile)

rocket.launch!
