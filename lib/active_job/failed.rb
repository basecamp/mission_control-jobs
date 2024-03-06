module ActiveJob::Failed
  extend ActiveSupport::Concern

  included do
    attr_accessor :last_execution_error, :failed_at
  end
end
