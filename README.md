A resque plugin for specifying the queues a worker pulls from with wildcards, negations, or dynamic look up from redis.

Authored against Resque 1.15, so it at least works with that - try running the tests if you use a different version of resque

[![Build Status](https://secure.travis-ci.org/wr0ngway/resque-dynamic-queues.png)](http://travis-ci.org/wr0ngway/resque-dynamic-queues)

Usage:

If creating a gem of your own that uses resque-dynamic-queues, you may have to add an explicit require statement at the top of your Rakefile:

    require 'resque-dynamic-queues'

Start your workers with a QUEUE that can contain '\*' for zero-or more of any character, '!' to exclude the following pattern.  Some examples help:

    QUEUE='foo' rake resque:work

Pulls jobs from the queue 'foo'

    QUEUE='*' rake resque:work

Pulls jobs from any queue

    QUEUE='*foo' rake resque:work

Pulls jobs from queues that end in foo

    QUEUE='*foo*' rake resque:work

Pulls jobs from queues whose names contain foo

    QUEUE='*foo*,!foobar' rake resque:work

Pulls jobs from queues whose names contain foo except the foobar queue

    QUEUE='*foo*,!*bar' rake resque:work

Pulls jobs from queues whose names contain foo except queues whose names end in bar

    task :custom_worker do
      ENV['QUEUE'] = "*foo*,!*bar"
      Rake::Task['resque:work'].invoke
    end

From a custom rake script


There is also a tab in the resque-web UI that allows you to define the dynamic queues  To activate it, you need to require 'resque-dynamic-queues-server' in whatever initializer you use to bring up resque-web.


Contributors:

Matt Conway ( https://github.com/wr0ngway )
Bert Goethals ( https://github.com/Bertg )
