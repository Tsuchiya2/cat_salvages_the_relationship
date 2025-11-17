# Metrics controller for Prometheus monitoring
#
# Exposes application metrics in Prometheus text format for scraping.
# This endpoint should be configured in your Prometheus scrape config.
#
# @example Prometheus scrape_config
#   scrape_configs:
#     - job_name: 'rails_app'
#       static_configs:
#         - targets: ['localhost:3000']
#       metrics_path: '/metrics'
class MetricsController < ApplicationController
  skip_before_action :verify_authenticity_token

  # Export Prometheus metrics
  #
  # Returns all registered metrics in Prometheus text format (version 0.0.4).
  # Updates gauge metrics before exporting to ensure current values.
  #
  # @example Response (text/plain)
  #   # HELP webhook_requests_total Total webhook requests received
  #   # TYPE webhook_requests_total counter
  #   webhook_requests_total{status="success"} 1234
  #
  #   # HELP line_groups_total Total number of LINE groups
  #   # TYPE line_groups_total gauge
  #   line_groups_total 567
  def index
    # Update gauge metrics before exporting
    PrometheusMetrics.update_group_count(LineGroup.count)

    render plain: Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry),
           content_type: 'text/plain; version=0.0.4'
  end
end
