require "spec_helper"

describe "Dynamic Queues" do

  before(:each) do
    Resque.redis.flushall
  end

  context "basic resque behavior still works" do

    it "can work on multiple queues" do
      Resque::Job.create(:high, SomeJob)
      Resque::Job.create(:critical, SomeJob)

      worker = Resque::Worker.new(:critical, :high)

      worker.process
      Resque.size(:high).should == 1
      Resque.size(:critical).should == 0

      worker.process
      Resque.size(:high).should == 0
    end

    it "can work on all queues" do
      Resque::Job.create(:high, SomeJob)
      Resque::Job.create(:critical, SomeJob)
      Resque::Job.create(:blahblah, SomeJob)

      worker = Resque::Worker.new("*")

      worker.work(0)
      Resque.size(:high).should == 0
      Resque.size(:critical).should == 0
      Resque.size(:blahblah).should == 0
    end

    it "processes * queues in alphabetical order" do
      Resque::Job.create(:high, SomeJob)
      Resque::Job.create(:critical, SomeJob)
      Resque::Job.create(:blahblah, SomeJob)

      worker = Resque::Worker.new("*")

      worker.work(0) do |job|
        Resque.redis.rpush("processed_queues", job.queue)
      end

      Resque.redis.lrange("processed_queues", 0, -1).should == %w( high critical blahblah ).sort
    end

    it "should pass lint" do
      Resque::Plugin.lint(Resque::Plugins::DynamicQueues)
    end

  end

  context "attributes" do
    it "should always have a fallback pattern" do
      Resque.get_dynamic_queues.should == {'default' => ['*']}
    end

    it "should allow setting single patterns" do
      Resque.get_dynamic_queue('foo').should == ['*']
      Resque.set_dynamic_queue('foo', ['bar'])
      Resque.get_dynamic_queue('foo').should == ['bar']
    end

    it "should allow setting multiple patterns" do
      Resque.set_dynamic_queues({'foo' => ['bar'], 'baz' => ['boo']})
      Resque.get_dynamic_queues.should == {'foo' => ['bar'], 'baz' => ['boo'], 'default' => ['*']}
    end

    it "should remove mapping when setting empty value" do
      Resque.get_dynamic_queues
      Resque.set_dynamic_queues({'foo' => ['bar'], 'baz' => ['boo']})
      Resque.get_dynamic_queues.should == {'foo' => ['bar'], 'baz' => ['boo'], 'default' => ['*']}

      Resque.set_dynamic_queues({'foo' => [], 'baz' => ['boo']})
      Resque.get_dynamic_queues.should == {'baz' => ['boo'], 'default' => ['*']}
      Resque.set_dynamic_queues({'baz' => nil})
      Resque.get_dynamic_queues.should == {'default' => ['*']}

      Resque.set_dynamic_queues({'foo' => ['bar'], 'baz' => ['boo']})
      Resque.set_dynamic_queue('foo', [])
      Resque.get_dynamic_queues.should == {'baz' => ['boo'], 'default' => ['*']}
      Resque.set_dynamic_queue('baz', nil)
      Resque.get_dynamic_queues.should == {'default' => ['*']}
    end


  end

  context "basic queue patterns" do

    before(:each) do
      Resque.watch_queue("high_x")
      Resque.watch_queue("foo")
      Resque.watch_queue("high_y")
      Resque.watch_queue("superhigh_z")
    end

    it "can specify simple queues" do
      worker = Resque::Worker.new("foo")
      worker.queues.should == ["foo"]

      worker = Resque::Worker.new("foo", "bar")
      worker.queues.should == ["foo", "bar"]
    end

    it "can specify simple wildcard" do
      worker = Resque::Worker.new("*")
      worker.queues.should == ["foo", "high_x", "high_y", "superhigh_z"]
    end

    it "can include queues with pattern"do
      worker = Resque::Worker.new("high*")
      worker.queues.should == ["high_x", "high_y"]

      worker = Resque::Worker.new("*high_z")
      worker.queues.should == ["superhigh_z"]

      worker = Resque::Worker.new("*high*")
      worker.queues.should == ["high_x", "high_y", "superhigh_z"]
    end

    it "can blacklist queues" do
      worker = Resque::Worker.new("*", "!foo")
      worker.queues.should == ["high_x", "high_y", "superhigh_z"]
    end

    it "can blacklist queues with pattern" do
      worker = Resque::Worker.new("*", "!*high*")
      worker.queues.should == ["foo"]
    end

    it "respects the order in which queue patterns are defined" do
      worker = Resque::Worker.new("h*", "f*")
      worker.queues.should == ["high_x", "high_y", "foo"]

      worker = Resque::Worker.new("*", "!f*")
      worker.queues.should == ["high_x", "high_y", "superhigh_z"]

      worker = Resque::Worker.new("*high*_z", "*", "!f*")
      worker.queues.should == ["superhigh_z", "high_x", "high_y"]
    end

    describe 'specificity' do
      it "orders by specificity" do
        worker = Resque::Worker.new("f*", "*", "high_*", "!high_x")
        worker.queues.should == [ "foo", "superhigh_z", "high_y"]
      end

      it "doesn't matter where negations appear" do
        worker = Resque::Worker.new("f*", "!*h_x", "*", "high_*")
        worker.queues.should == [ "foo", "superhigh_z", "high_y"]
      end

      it "works without dynamic queues" do
        worker = Resque::Worker.new("!*_x", "*", "high_y", "f*")
        worker.queues.should == [ "superhigh_z", "high_y", "foo"]
      end

      it "works with suffixes" do
        Resque.watch_queue("hl_a")
        Resque.watch_queue("hl_a_high")
        Resque.watch_queue("hl_a_low")
        Resque.watch_queue("hl_a_medium")
        Resque.watch_queue("b")
        Resque.watch_queue("b_low")
        Resque.watch_queue("b_high")
        Resque.watch_queue("b_medium")

        hl_worker = Resque::Worker.new("hl_*_high", "hl_*_medium", "hl_*", "hl_*_low")
        hl_worker.queues.should == [ "hl_a_high", "hl_a_medium", "hl_a", "hl_a_low"]

        worker = Resque::Worker.new("*_high", "*_medium", "*", "*_low", "!hl_*")
        worker.queues.should == ["b_high", "b_medium", "b", "foo", "high_x", "high_y", "superhigh_z", "b_low"]
      end
    end

  end
end
