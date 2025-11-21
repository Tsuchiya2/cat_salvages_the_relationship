# frozen_string_literal: true

module Line
  # Content sampling service with caching
  #
  # Provides efficient random sampling of Content records with
  # caching to prevent N+1 queries in batch operations.
  #
  # @example Single sample
  #   sampler = Line::ContentSampler.new
  #   content = sampler.sample(:free)
  #
  # @example Batch preloading
  #   sampler = Line::ContentSampler.new
  #   sampler.preload_all
  #   100.times { sampler.sample(:free) }  # No additional queries
  class ContentSampler
    # Cache duration for preloaded content
    CACHE_DURATION = 5.minutes

    # Initialize content sampler
    def initialize
      @cache = {}
    end

    # Get random content for category
    #
    # Returns cached content if available, otherwise queries database.
    #
    # @param category [Symbol] Content category (:contact, :free, :text)
    # @return [Content] Random content record
    def sample(category)
      refresh_cache(category) unless cache_valid?(category)
      @cache[category][:content].sample
    end

    # Preload all content categories
    #
    # Loads all categories into cache with single query per category.
    # Use before batch operations to avoid N+1 queries.
    #
    # @return [void]
    def preload_all
      Content.categories.each_key do |category|
        refresh_cache(category.to_sym)
      end
    end

    # Get cached content array for testing
    #
    # @param category [Symbol] Content category
    # @return [Array<Content>] Cached content array
    def cached_content(category)
      @cache[category]&.dig(:content)
    end

    # Check if specified category has at least one entry
    #
    # @param category [Symbol] Content category
    # @return [Boolean] true when content exists
    def available?(category)
      refresh_cache(category) unless cache_valid?(category)
      @cache[category][:content].present?
    end

    private

    # Check if cache is still valid
    #
    # @param category [Symbol] Content category
    # @return [Boolean] true if cache exists and not expired
    def cache_valid?(category)
      return false unless @cache[category]

      @cache[category][:expires_at] > Time.current
    end

    # Refresh cache for category
    #
    # @param category [Symbol] Content category
    # @return [void]
    def refresh_cache(category)
      content_array = Content.send(category).to_a
      @cache[category] = {
        content: content_array,
        expires_at: CACHE_DURATION.from_now
      }
    end
  end
end
