require "test_helper"

class ActiveJob::QueueAdapters::ResqueAdapterTest < ActiveSupport::TestCase
  include ResqueHelper

  test "create a new adapter with the default resque redis instance" do
    assert_no_changes -> { Resque.redis } do
      ActiveJob::QueueAdapters::ResqueAdapter.new
    end
  end

  test "execute a block of code activating a different redis instance" do
    old_redis = create_resque_redis "old_redis"
    new_redis = create_resque_redis "new_redis"

    adapter = ActiveJob::QueueAdapters::ResqueAdapter.new(new_redis)
    Resque.redis = old_redis

    assert_equal old_redis, current_resque_redis

    adapter.activating do
      @invoked = true
      assert_equal new_redis, current_resque_redis
    end

    assert @invoked
    assert_equal old_redis, current_resque_redis
  end

  test "activating different redis connections is thread-safe" do
    redis_1 = create_resque_redis("redis_1")
    adapter_1 = ActiveJob::QueueAdapters::ResqueAdapter.new(redis_1)
    redis_2 = create_resque_redis("redis_2")
    adapter_2 = ActiveJob::QueueAdapters::ResqueAdapter.new(redis_2)

    { redis_1 => adapter_1, redis_2 => adapter_2 }.flat_map do |redis, adapter|
      20.times.collect do
        Thread.new do
          adapter.activating do
            sleep_to_force_race_condition
            assert_equal redis, current_resque_redis
          end
        end
      end
    end.each(&:join)
  end

  test "use different resque adapters via active job" do
    redis_1 = create_resque_redis("redis_1")
    adapter_1 = ActiveJob::QueueAdapters::ResqueAdapter.new(redis_1)
    redis_2 = create_resque_redis("redis_2")
    adapter_2 = ActiveJob::QueueAdapters::ResqueAdapter.new(redis_2)

    with_active_job_adapter(adapter_1) do
      adapter_1.activating do
        5.times { DummyJob.perform_later }
      end
    end

    with_active_job_adapter(adapter_2) do
      adapter_2.activating do
        10.times { DummyJob.perform_later }
      end
    end

    with_active_job_adapter(adapter_1) do
      adapter_1.activating do
        assert_equal 5, ActiveJob.jobs.pending.count
      end
    end

    with_active_job_adapter(adapter_2) do
      adapter_2.activating do
        assert_equal 10, ActiveJob.jobs.pending.count
      end
    end
  end

  private
    def with_active_job_adapter(adapter, &block)
      previous_adapter = ActiveJob::Base.current_queue_adapter
      ActiveJob::Base.current_queue_adapter = adapter
      yield
    ensure
      ActiveJob::Base.current_queue_adapter = previous_adapter
    end
end
