class MissionControl::Jobs::BulkDiscardsController < MissionControl::Jobs::ApplicationController
  include MissionControl::Jobs::FailedJobsBulkOperations

  def create
    jobs_to_discard_count = jobs_to_discard.count
    jobs_to_discard.discard_all

    redirect_to application_jobs_url(@application, :failed), notice: "Discarded #{jobs_to_discard_count} jobs"
  end

  private
    def jobs_to_discard
      if active_filters?
        bulk_limited_filtered_failed_jobs
      else
        # we don't want to apply any limit since "discarding all" without parameters can be optimized in the adapter as a much faster operation
        ActiveJob.jobs.failed
      end
    end
end
